import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/call_transcript.dart';
import '../models/fraud_models.dart';
import '../models/stats_record.dart';
import '../services/fcm_service.dart';
import '../services/debug_logger.dart';
import '../services/api_service.dart';
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
  // FCM subscription
  StreamSubscription<Map<String, dynamic>>? _fcmSub;

  // ── FCM-driven call state ──
  String? _conversationId;
  String? get conversationId => _conversationId;

  String? _callerPhone;
  String? get callerPhone => _callerPhone;

  String? _callerName;
  String? get callerName => _callerName;

  final List<_FcmMsg> _fcmMsgs = [];
  List<TranscriptEntry> get fcmTranscript => _fcmMsgs.map((m) => TranscriptEntry(
        speaker:
            m.role == 'user' ? TranscriptSpeaker.caller : TranscriptSpeaker.ai,
        text: m.content,
        time: m.receivedAt,
      )).toList();

  IncomingCall? _incoming;
  IncomingCall? get incoming => _incoming;

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
    DebugLogger.I.log('[CallProvider] _onFcmEvent received: type=$type');

    switch (type) {
      case 'incoming_call':
        final detail = _parseField(data['detail']);
        _fcmMsgs.clear();
        _conversationId = detail['conversation_id'] as String? ??
            data['conversation_id'] as String?;
        _callerPhone = detail['phone_number'] as String? ??
            data['phone_number'] as String?;
        DebugLogger.I.log('[CallProvider] incoming_call set: conversationId=$_conversationId, phone=$_callerPhone, hasActiveCall=$hasActiveCall');
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

        // Use backend created_at timestamp if available
        DateTime receivedAt = DateTime.now();
        final createdAt = msg['created_at'] as String?;
        if (createdAt != null) {
          try {
            receivedAt = DateTime.parse(createdAt);
          } catch (_) {}
        }

        // Check if message already exists (avoid duplication)
        if (!_fcmMsgs.any((m) => m.id == id)) {
          _fcmMsgs.add(_FcmMsg(
            id: id,
            content: msg['content'] as String? ?? '',
            role: msg['role'] as String? ?? 'user',
            receivedAt: receivedAt,
          ));
          // Sort by timestamp to maintain chronological order
          _fcmMsgs.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
        }
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


  @override
  void dispose() {
    _callTicker?.cancel();
    _windowTimer?.cancel();
    _fcmSub?.cancel();
    _decisionCtrl.close();
    _noticeCtrl.close();
    super.dispose();
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
    _incoming = null;
    notifyListeners();
  }

  Future<void> declineCall({String reason = 'busy'}) async {
    if (_incoming == null) return;
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
    _callerName = null;
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

  /// End call locally WITHOUT sending hangup API (for remote hangup events)
  void endCallFromRemote() {
    DebugLogger.I.log('[CallProvider] Ending call due to remote hangup');
    _endCall();
    _clearFcmCall();
    notifyListeners();
  }

  /// Load conversation history from API, deduplicating by message ID
  /// If duplicate found, replace with API version (authoritative)
  /// Sorts by timestamp to ensure correct ordering
  void loadConversationHistory(List<dynamic> messages) {
    for (final msg in messages) {
      if (msg is Map<String, dynamic>) {
        final id = msg['id']?.toString() ?? '';
        final content = msg['content'] as String? ?? '';
        final role = msg['role'] as String? ?? 'user';
        final createdAt = msg['created_at'] as String?;

        if (id.isEmpty || content.isEmpty) {
          continue;
        }

        DateTime receivedAt = DateTime.now();
        if (createdAt != null) {
          try {
            receivedAt = DateTime.parse(createdAt);
          } catch (_) {}
        }

        // Check if message already exists
        final existingIndex = _fcmMsgs.indexWhere((m) => m.id == id);
        if (existingIndex >= 0) {
          // Replace with API version (authoritative)
          _fcmMsgs[existingIndex] = _FcmMsg(
            id: id,
            content: content,
            role: role,
            receivedAt: receivedAt,
          );
        } else {
          // Add new message
          _fcmMsgs.add(_FcmMsg(
            id: id,
            content: content,
            role: role,
            receivedAt: receivedAt,
          ));
        }
      }
    }
    // Sort by timestamp to ensure chronological order
    _fcmMsgs.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    notifyListeners();
  }

  Future<void> syncCallStatusOnResume() async {
    try {
      final apiService = sl<ApiService>();
      final response = await apiService.dio.get('/api/fraud/active-call');
      final data = response.data as Map<String, dynamic>;
      final hasActiveCall = data['has_active_call'] as bool? ?? false;

      DebugLogger.I.log('[CallProvider] syncCallStatusOnResume: hasActiveCall=$hasActiveCall, _conversationId=$_conversationId');

      if (!hasActiveCall && _conversationId != null) {
        // We thought there was a call, but backend says no active call
        // Call ended while app was paused - end the call
        DebugLogger.I.log('[CallProvider] Call ended while app was paused, clearing state');
        _endCall();
        _clearFcmCall();
        notifyListeners();
      } else if (hasActiveCall && _conversationId == null) {
        // Backend has an active call but CallProvider doesn't know about it
        // This happens when app was paused and call came in
        final activeConvId = data['conversation_id'] as String?;
        if (activeConvId?.isNotEmpty == true) {
          DebugLogger.I.log('[CallProvider] Found active call from backend: $activeConvId');
          _conversationId = activeConvId;
          _callerPhone = data['phone_number'] as String?;
          _callerName = data['caller_name'] as String?;

          // Parse call start time if available
          final callStartTimeStr = data['call_start_time'] as String?;
          if (callStartTimeStr?.isNotEmpty == true) {
            try {
              _callStartAt = DateTime.parse(callStartTimeStr!);
            } catch (_) {
              _callStartAt = DateTime.now();
            }
          } else {
            _callStartAt = DateTime.now();
          }

          // Sync fraud score
          final currentScore = data['current_score'] as int? ?? 0;
          _scamProbability = currentScore / 100.0;

          notifyListeners();
        }
      } else if (hasActiveCall && _conversationId != null) {
        // Still in a call - verify it's the same conversation
        final activeConvId = data['conversation_id'] as String?;
        if (activeConvId != _conversationId) {
          // Different conversation - unlikely but handle it
          DebugLogger.I.log('[CallProvider] Conversation changed while paused: $_conversationId -> $activeConvId');
          _conversationId = activeConvId;
          notifyListeners();
        }
      }
    } catch (e) {
      DebugLogger.I.log('[CallProvider] Error syncing call status on resume: $e');
    }
  }


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
