import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/call_transcript.dart';
import '../models/fraud_models.dart';
import '../models/scam_event.dart';
import '../models/ws_message.dart';
import '../models/stats_record.dart';
import '../services/fcm_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../di/service_locator.dart';


enum CallDecisionType { fraudBlocked, safeTransfer }

enum UiNoticeType {
  detectionStarted,
  detectionEnded,
  scamDecision,
  callAccepted,
  callDeclined,
  callEnded,
  error,
}

class UiNotice {
  final UiNoticeType type;
  final String message;
  UiNotice({required this.type, required this.message});
}

class IncomingCall {
  final String callerId;
  final String targetUsername;
  final DateTime expiresAt;
  final bool llmOnly;

  IncomingCall({
    required this.callerId,
    required this.targetUsername,
    required this.expiresAt,
    required this.llmOnly,
  });

  int get remainingSeconds {
    final s = expiresAt.difference(DateTime.now()).inSeconds;
    if (s < 0) return 0;
    if (s > 3600) return 3600;
    return s;
  }

  bool get expired => DateTime.now().isAfter(expiresAt);
}

class CallDecision {
  final CallDecisionType type;
  final DateTime time;
  CallDecision({required this.type, required this.time});
}

/// FCM 逐字稿訊息（可 mutate，用於 update/delete）
class _FcmMsg {
  final String id;
  String content;
  final String role;
  final DateTime receivedAt;

  _FcmMsg({
    required this.id,
    required this.content,
    required this.role,
    required this.receivedAt,
  });
}

class CallProvider extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();

  // FCM subscription
  StreamSubscription<Map<String, dynamic>>? _fcmSub;

  // ── FCM-driven call state ──
  String? _conversationId;
  String? get conversationId => _conversationId;

  String? _callerPhone;
  String? get callerPhone => _callerPhone;

  final List<_FcmMsg> _fcmMsgs = [];
  List<TranscriptEntry> get fcmTranscript => _fcmMsgs.map((m) => TranscriptEntry(
        speaker:
            m.role == 'user' ? TranscriptSpeaker.caller : TranscriptSpeaker.ai,
        text: m.content,
        time: m.receivedAt,
      )).toList();

  // ── WebSocket state (kept for MonitorPage debug) ──
  StreamSubscription<ScamEvent>? _eventSub;
  StreamSubscription<WsMessage>? _msgSub;

  bool _monitoring = false;
  bool get monitoring => _monitoring;
  bool get connected => _ws.connected;

  IncomingCall? _incoming;
  IncomingCall? get incoming => _incoming;

  ScamEvent? _latest;
  ScamEvent? get latest => _latest;
  final List<ScamEvent> _history = [];
  List<ScamEvent> get history => List.unmodifiable(_history);

  WsMessage? _lastMsg;
  WsMessage? get lastMsg => _lastMsg;

  String? connectionId;
  String? clientUuid;

  static const int fraudThreshold = 2;
  static const Duration decisionWindow = Duration(minutes: 3);

  Timer? _windowTimer;
  int _maxStage = 0;

  final _decisionCtrl = StreamController<CallDecision>.broadcast();
  Stream<CallDecision> get decisions => _decisionCtrl.stream;

  final _noticeCtrl = StreamController<UiNotice>.broadcast();
  Stream<UiNotice> get notices => _noticeCtrl.stream;

  // ── Call timer ──
  String? _currentCallId;
  DateTime? _callStartAt;
  Timer? _callTicker;

  bool get inCall => _currentCallId != null;
  bool get hasActiveCall => inCall || _conversationId != null;
  String? get callId => _currentCallId;
  DateTime? get callStartAt => _callStartAt;

  Duration get callDuration => _callStartAt == null
      ? DateTime.now().difference(DateTime.now())
      : DateTime.now().difference(_callStartAt!);

  // ── FCM risk state ──
  double _scamProbability = 0.0;
  double get scamProbability => _scamProbability;

  SsciData? _ssciData;
  SsciData? get ssciData => _ssciData;

  bool _isFraudAlert = false;
  bool get isFraudAlert => _isFraudAlert;

  bool _isSafeToAnswer = false;
  bool get isSafeToAnswer => _isSafeToAnswer;

  // ── Audio streaming ──
  bool _streaming = false;
  bool get streaming => _streaming;

  double _uplinkKbps = 0.0;
  double get uplinkKbps => _uplinkKbps;

  double _jitterMs = 0.0;
  double get jitterMs => _jitterMs;

  int _txBytesWindow = 0;
  Timer? _txMeterTimer;
  DateTime? _lastSendAt;

  bool _micMuted = false;
  double _playbackVolume = 1.0;
  bool get micMuted => _micMuted;
  double get playbackVolume => _playbackVolume;

  void toggleMicMute() {
    _micMuted = !_micMuted;
    notifyListeners();
  }

  Future<void> setPlaybackVolume(double v) async {
    _playbackVolume = v.clamp(0.0, 1.0);
    await AudioService.I.setPlayerVolume(_playbackVolume);
    notifyListeners();
  }

  Stream<Uint8List> get audioFrames => _ws.audioFrames;

  Future<void> sendAudio(Uint8List bytes) async {
    if (_micMuted) return;
    await _ws.sendAudio(bytes);
  }

  // 統計
  final List<StatsRecord> _stats = [];
  List<StatsRecord> get stats => List.unmodifiable(_stats);

  CallProvider() {
    _fcmSub = FcmService.I.events.listen(_onFcmEvent);
  }

  // ── FCM event handler ──

  Map<String, dynamic> _parseField(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        return jsonDecode(value) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  void _onFcmEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'incoming_call':
        final detail = _parseField(data['detail']);
        _fcmMsgs.clear();
        _conversationId = detail['conversation_id'] as String? ??
            data['conversation_id'] as String?;
        _callerPhone = detail['phone_number'] as String? ??
            data['phone_number'] as String?;
        _callStartAt = DateTime.now();
        _callTicker?.cancel();
        _callTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          notifyListeners();
        });
        notifyListeners();

      case 'call_new_message':
        final convId = data['conversation_id'] as String? ?? '';
        if (_conversationId == null || convId != _conversationId) return;
        final msg = _parseField(data['message']);
        final id = msg['id'] as String? ?? '';
        if (id.isEmpty) return;
        _fcmMsgs.add(_FcmMsg(
          id: id,
          content: msg['content'] as String? ?? '',
          role: msg['role'] as String? ?? 'user',
          receivedAt: DateTime.now(),
        ));
        notifyListeners();

      case 'call_update_message':
        final msg = _parseField(data['message']);
        final id = msg['id'] as String? ?? '';
        final idx = _fcmMsgs.indexWhere((m) => m.id == id);
        if (idx >= 0) {
          _fcmMsgs[idx].content = msg['content'] as String? ?? _fcmMsgs[idx].content;
          notifyListeners();
        }

      case 'call_delete_message':
        final msg = _parseField(data['message']);
        final id = msg['id'] as String? ?? '';
        _fcmMsgs.removeWhere((m) => m.id == id);
        notifyListeners();

      case 'ssci_update':
        final convId = data['conversation_id'] as String? ?? '';
        if (_conversationId != null && convId != _conversationId) return;
        final ssciMap = _parseField(data['ssci']);
        _scamProbability = (ssciMap['scam_probability'] as num?)?.toDouble() ?? _scamProbability;
        _ssciData = SsciData(
          available: true,
          updated: true,
          rawInferenceCount: 0,
          triggerCount: (ssciMap['trigger_index'] as num?)?.toInt() ?? 0,
          confidence: (ssciMap['confidence'] as num?)?.toDouble(),
          evidence: (ssciMap['evidence'] as num?)?.toDouble(),
          agreement: (ssciMap['agreement'] as num?)?.toDouble(),
          stability: (ssciMap['stability'] as num?)?.toDouble(),
        );
        notifyListeners();

      case 'fraud_alert':
        final convId = data['conversation_id'] as String? ?? '';
        if (_conversationId != null && convId != _conversationId) return;
        _isFraudAlert = true;
        final prob = (data['scam_probability'] as num?)?.toDouble();
        if (prob != null) _scamProbability = prob;
        final ssciMap = _parseField(data['ssci']);
        if (ssciMap.isNotEmpty) {
          _ssciData = SsciData(
            available: true,
            updated: true,
            rawInferenceCount: 0,
            triggerCount: (ssciMap['trigger_index'] as num?)?.toInt() ?? 0,
            confidence: (ssciMap['confidence'] as num?)?.toDouble(),
            evidence: (ssciMap['evidence'] as num?)?.toDouble(),
            agreement: (ssciMap['agreement'] as num?)?.toDouble(),
            stability: (ssciMap['stability'] as num?)?.toDouble(),
          );
        }
        notifyListeners();

      case 'safe_to_answer':
        final convId = data['conversation_id'] as String? ?? '';
        if (_conversationId != null && convId != _conversationId) return;
        _isSafeToAnswer = true;
        final prob = (data['scam_probability'] as num?)?.toDouble();
        if (prob != null) _scamProbability = prob;
        final ssciMap = _parseField(data['ssci']);
        if (ssciMap.isNotEmpty) {
          _ssciData = SsciData(
            available: true,
            updated: true,
            rawInferenceCount: 0,
            triggerCount: (ssciMap['trigger_index'] as num?)?.toInt() ?? 0,
            confidence: (ssciMap['confidence'] as num?)?.toDouble(),
            evidence: (ssciMap['evidence'] as num?)?.toDouble(),
            agreement: (ssciMap['agreement'] as num?)?.toDouble(),
            stability: (ssciMap['stability'] as num?)?.toDouble(),
          );
        }
        notifyListeners();
    }
  }

  // ── WebSocket monitoring (kept for MonitorPage) ──

  Future<void> startMonitoring({
    required String token,
    required String uuid,
    String? callToken,
  }) async {
    if (_monitoring) return;
    _monitoring = true;
    notifyListeners();

    await _ws.connect(token: token, uuid: uuid, callToken: callToken);

    _eventSub = _ws.events.listen(_onEvent);
    _msgSub = _ws.messages.listen(_onMessage);
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;

    await _eventSub?.cancel();
    await _msgSub?.cancel();
    _eventSub = null;
    _msgSub = null;

    _resetWindow();

    await _ws.disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _callTicker?.cancel();
    _windowTimer?.cancel();
    _eventSub?.cancel();
    _msgSub?.cancel();
    _fcmSub?.cancel();
    _decisionCtrl.close();
    _noticeCtrl.close();
    _ws.dispose();
    _txMeterTimer?.cancel();
    super.dispose();
  }

  void clearHistory() {
    _history.clear();
    _latest = null;
    notifyListeners();
  }

  void addFeedback(String decision) {
    if (_latest == null) return;
    _stats.insert(
        0, StatsRecord.fromEvent(event: _latest!, decision: decision));
    notifyListeners();
  }

  void removeStatAt(int index) {
    if (index < 0 || index >= _stats.length) return;
    _stats.removeAt(index);
    notifyListeners();
  }

  void clearStats() {
    _stats.clear();
    notifyListeners();
  }

  void _notify(UiNoticeType t, String msg) {
    _noticeCtrl.add(UiNotice(type: t, message: msg));
  }

  void _onMessage(WsMessage m) {
    _lastMsg = m;

    if (m.type == WsType.connectionSuccess) {
      connectionId = m.connectionId ?? connectionId;
      clientUuid = m.clientUuid ?? clientUuid;
      notifyListeners();
    }

    if (m.type == WsType.incomingCallRequest) {
      final int seconds = ((m.timeoutSeconds ?? 30).clamp(5, 120));
      _incoming = IncomingCall(
        callerId: m.callerId ?? '',
        targetUsername: m.targetUsername ?? '',
        expiresAt: DateTime.now().add(Duration(seconds: seconds)),
        llmOnly: m.llmOnly ?? false,
      );
      notifyListeners();
    }

    if (m.type == WsType.detectionStarted) {
      _startWindowIfNeeded();
      _notify(UiNoticeType.detectionStarted, 'Monitoring has started');
      unawaited(startMicStream());
    }
    if (m.type == WsType.detectionEnded) {
      _finalizeWindow();
      _notify(UiNoticeType.detectionEnded, 'Monitoring has ended');
      unawaited(stopMicStream());
    }

    if (m.type == WsType.scamDecision) {
      final stage = m.stage;
      final fc = m.fraudCount;
      String msg = 'Receive final decision';
      if (stage != null) {
        msg = stage >= 2
            ? 'Final decision: High risk (stage $stage)'
            : 'Final decision: Low risk (stage $stage)';
      } else if (fc != null) {
        msg = 'Final decision: cumulative hits of $fc key indicators';
      }
      _notify(UiNoticeType.scamDecision, msg);
    }

    if (m.type == WsType.callAccepted) {
      _startCall(m.callId ?? m.callerId);
      _notify(UiNoticeType.callAccepted, 'The other party has accepted the call');
    }
    if (m.type == WsType.callDeclined) {
      _incoming = null;
      notifyListeners();
      _notify(UiNoticeType.callDeclined, 'The other party has rejected the call');
    }
    if (m.type == WsType.callEnded) {
      _endCall();
      _notify(UiNoticeType.callEnded, 'The call has ended');
    }

    if (m.type == WsType.error) {
      _notify(UiNoticeType.error, m.errorMessage ?? 'WebSocket error');
    }
  }

  void _onEvent(ScamEvent e) {
    _latest = e;
    _history.insert(0, e);
    notifyListeners();

    _startWindowIfNeeded();

    final s = e.stage ?? 0;
    if (s > _maxStage) _maxStage = s;

    if (_maxStage >= fraudThreshold) {
      _finalizeWindow(forceFraud: true);
    }
  }

  void _startWindowIfNeeded() {
    if (_windowTimer != null) return;
    _maxStage = 0;
    _windowTimer = Timer(decisionWindow, _finalizeWindow);
  }

  Future<void> _finalizeWindow({bool forceFraud = false}) async {
    _windowTimer?.cancel();
    _windowTimer = null;

    final isFraud = forceFraud || _maxStage >= fraudThreshold;
    final type =
        isFraud ? CallDecisionType.fraudBlocked : CallDecisionType.safeTransfer;

    _decisionCtrl.add(CallDecision(type: type, time: DateTime.now()));
    _resetWindow();
  }

  Future<void> acceptCall() async {
    if (_incoming == null) return;
    await _ws.sendMessage({
      'type': 'accept_call',
      'caller_id': _incoming!.callerId,
      'target_username': _incoming!.targetUsername,
    });
    _incoming = null;
    notifyListeners();
  }

  Future<void> declineCall({String reason = 'busy'}) async {
    if (_incoming == null) return;
    await _ws.sendMessage({
      'type': 'decline_call',
      'caller_id': _incoming!.callerId,
      'target_username': _incoming!.targetUsername,
      'reason': reason,
    });
    _incoming = null;
    notifyListeners();
  }

  void _startCall(String? callId) {
    if (callId == null || callId.isEmpty) return;
    _incoming = null;
    _currentCallId = callId;
    _callStartAt = DateTime.now();
    _callTicker?.cancel();
    _callTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void _endCall() {
    _callTicker?.cancel();
    _callTicker = null;
    _currentCallId = null;
    _callStartAt = null;
    notifyListeners();
  }

  void _clearFcmCall() {
    _conversationId = null;
    _callerPhone = null;
    _fcmMsgs.clear();
    _scamProbability = 0.0;
    _ssciData = null;
    _isFraudAlert = false;
    _isSafeToAnswer = false;
  }

  Future<void> hangup() async {
    if (_currentCallId != null) {
      try {
        await sl<ApiService>().hangup(callId: _currentCallId!);
      } catch (_) {}
    } else if (_conversationId != null) {
      await sl<ApiService>().callEnd();
    }
    _endCall();
    _clearFcmCall();
    notifyListeners();
  }

  // ── Mic streaming ──

  Future<void> startMicStream() async {
    if (_streaming) return;

    final status = await Permission.microphone.request();

    if (status.isGranted) {
      _txBytesWindow = 0;
      _uplinkKbps = 0.0;
      _jitterMs = 0.0;
      _lastSendAt = null;

      _txMeterTimer?.cancel();
      _txMeterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _uplinkKbps = (_txBytesWindow * 8) / 1000.0;
        _txBytesWindow = 0;
        notifyListeners();
      });

      await AudioService.I.startStreaming((chunk) {
        if (!_micMuted) {
          _ws.sendAudio(chunk);
        }
        _onBytesSent(chunk.length);
      });

      _streaming = true;
      notifyListeners();
      return;
    }

    if (status.isPermanentlyDenied) {
      _notify(UiNoticeType.error,
          'Microphone permission is permanently denied. Please enable it in Settings.');
      openAppSettings();
    } else {
      _notify(UiNoticeType.error, 'Microphone permission denied.');
    }
  }

  Future<void> stopMicStream() async {
    if (!_streaming) return;
    await AudioService.I.stopStreaming();
    _txMeterTimer?.cancel();
    _txMeterTimer = null;
    _streaming = false;
    notifyListeners();
  }

  void _onBytesSent(int n) {
    _txBytesWindow += n;
    final now = DateTime.now();
    if (_lastSendAt != null) {
      final delta = now.difference(_lastSendAt!).inMilliseconds.toDouble();
      _jitterMs = _jitterMs == 0.0 ? delta : (0.8 * _jitterMs + 0.2 * delta);
    }
    _lastSendAt = now;
  }

  void wsSend(String data) => _ws.send(data);

  void clearIncoming() {
    _incoming = null;
    notifyListeners();
  }

  void _resetWindow() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _maxStage = 0;
  }
}
