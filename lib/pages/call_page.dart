import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../di/service_locator.dart';
import '../models/call_transcript.dart';
import '../models/conversation_models.dart';
import '../providers/call_provider.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/debug_logger.dart';
import 'call_summary_page.dart';
import 'conversations_page.dart';

// ── Risk color helpers ────────────────────────────────────────────────────────

Color _riskBg(int score) {
  if (score < 40) return const Color(0xFF1A3A2A);
  if (score < 60) return const Color(0xFF3A2E0A);
  if (score < 80) return const Color(0xFF3A1E0A);
  return const Color(0xFF3A0A0A);
}

Color _riskFg(int score) {
  if (score < 40) return const Color(0xFF66BB6A);
  if (score < 60) return const Color(0xFFFFCA28);
  if (score < 80) return const Color(0xFFFF7043);
  return const Color(0xFFEF5350);
}

String _riskLabel(int score) {
  if (score < 40) return 'Safe';
  if (score < 60) return 'Caution';
  if (score < 80) return 'Warning';
  return 'Danger';
}

// ── Call mode ─────────────────────────────────────────────────────────────────

enum CallMode { incoming, outgoing }

// ── Page ──────────────────────────────────────────────────────────────────────

class CallPage extends StatefulWidget {
  final CallMode mode;
  final String? contactName;   // shown in header (outgoing: contact name)
  final String? callerNumber;  // phone number shown under label

  const CallPage({
    super.key,
    this.mode = CallMode.incoming,
    this.contactName,
    this.callerNumber,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  static bool get _isMock => ApiConfig.mockCallUi;
  bool get _isOutgoing => widget.mode == CallMode.outgoing;

  // Mock state
  final List<TranscriptEntry> _mockTranscript = [];
  int _mockScore = 0;
  int _maxScore = 0; // highest score seen — used in summary
  int _lastRealScore = 0; // tracks last seen score in real mode
  bool _isTranscribing = false;
  bool _isScoreStale = false;

  // Duration & speaker indicator
  int _durationSecs = 0;
  bool _speakerOn = true;
  int _dotPhase = 0;

  // Top banner state
  bool _showSpeakerBanner = false;

  // Message tracking for auto-scroll
  int _lastMessageCount = 0;

  // Incoming: tracks when the user takes over from the system
  bool _userAnswered = false;
  bool _isHangingUp = false; // 防止 hasActiveCall 變 false 時的 auto-pop 把 CallSummaryPage 彈掉

  // Score history for summary chart: [(seconds, score)]
  final List<({int seconds, int score})> _scoreHistory = [];

  // Timers
  final List<Timer> _mockTimers = [];
  Timer? _tickTimer;
  Timer? _dotTimer;
  Timer? _bannerTimer;
  Timer? _bannerDismissTimer;

  // Audio (real mode)
  StreamSubscription<Uint8List>? _audioSub;
  late final CallProvider _cp;
  final _audio = AudioService.I;

  // Scroll
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cp = context.read<CallProvider>();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSecs++);
    });

    _dotTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _dotPhase = (_dotPhase + 1) % 3);
    });

    // One-time speakerphone banner at top of screen
    _bannerTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSpeakerBanner = true);
    });
    _bannerDismissTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) setState(() => _showSpeakerBanner = false);
    });

    if (_isMock) {
      _isOutgoing ? _launchOutgoingMock() : _launchMock();
    } else {
      _audioSub = _cp.audioFrames.listen((bytes) {
        _audio.playBytes(bytes);
      });
      _cp.addListener(_onProviderUpdate);

      // Sync conversation messages on page load
      if (_cp.conversationId != null) {
        DebugLogger.I.log('[CallPage] Fetching conversation history for: ${_cp.conversationId}');
        sl<ApiService>().dio.get('/api/fraud/conversations/${_cp.conversationId}/messages').then((response) {
          final data = response.data as Map<String, dynamic>? ?? {};
          final messages = data['messages'] as List<dynamic>? ?? [];
          DebugLogger.I.log('[CallPage] Loaded ${messages.length} messages from backend');
          _cp.loadConversationHistory(messages);
        }).catchError((e) {
          DebugLogger.I.log('[CallPage] Failed to fetch conversation: $e');
        });
      } else {
        DebugLogger.I.log('[CallPage] No conversationId available yet');
      }
    }
  }

  // ── Score helper ─────────────────────────────────────────────────────────────

  void _updateScore(int score) {
    _mockScore = score;
    if (score > _maxScore) _maxScore = score;
    _scoreHistory.add((seconds: _durationSecs, score: score));
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final newScore = (_cp.scamProbability * 100).round();
    if (newScore != _lastRealScore) {
      _lastRealScore = newScore;
      setState(() => _updateScore(newScore));
    }

    // Auto-scroll to latest message when messages change
    final messageCount = _cp.fcmTranscript.length;
    if (messageCount != _lastMessageCount) {
      _scrollToBottom();
      _lastMessageCount = messageCount;
    }
  }

  // ── Mock sequences ────────────────────────────────────────────────────────────

  void _addTimer(int ms, VoidCallback fn) {
    _mockTimers.add(Timer(Duration(milliseconds: ms), fn));
  }

  TranscriptEntry _entry(
    TranscriptSpeaker speaker,
    String text, {
    bool isHighRisk = false,
  }) =>
      TranscriptEntry(
        speaker: speaker,
        text: text,
        time: DateTime.now(),
        isHighRisk: isHighRisk,
      );

  void _launchMock() {
    setState(() => _isTranscribing = true);

    _addTimer(2000, () {
      setState(() {
        _updateScore(18);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '您好，我是台灣大哥大客服。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(2400, () => setState(() => _isTranscribing = true));

    _addTimer(4000, () {
      setState(() {
        _mockTranscript.add(_entry(TranscriptSpeaker.ai, '您好，請問有什麼需要協助？'));
        _isTranscribing = false;
      });
      _scrollToBottom();
    });
    _addTimer(4400, () => setState(() {
      _isTranscribing = true;
      _isScoreStale = true;
    }));

    _addTimer(7000, () {
      setState(() {
        _updateScore(22);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '做用戶滿意度調查，大概三分鐘。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(7400, () => setState(() => _isTranscribing = true));
    _addTimer(9200, () => setState(() => _isScoreStale = true));

    _addTimer(11000, () {
      setState(() {
        _updateScore(75);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '需要您配合轉帳到安全帳戶。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(11400, () => setState(() {
      _isTranscribing = true;
      _isScoreStale = true;
    }));

    _addTimer(13000, () {
      setState(() {
        _mockTranscript.add(_entry(TranscriptSpeaker.ai, '請提供您的聯絡資訊。'));
        _isTranscribing = false;
      });
      _scrollToBottom();
    });
    _addTimer(13400, () => setState(() {
      _isTranscribing = true;
      _isScoreStale = true;
    }));

    _addTimer(15000, () {
      setState(() {
        _updateScore(87);
        _mockTranscript.add(_entry(
          TranscriptSpeaker.caller,
          '緊急情況，帳戶將被凍結。',
          isHighRisk: true,
        ));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
  }

  void _launchOutgoingMock() {
    setState(() => _isTranscribing = true);

    _addTimer(2000, () {
      setState(() {
        _updateScore(15);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '喂，你好，我是中華電信客服。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(2400, () => setState(() => _isTranscribing = true));

    _addTimer(5000, () {
      setState(() {
        _updateScore(20);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '您的帳號有異常登入紀錄，需要確認。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(5400, () => setState(() {
      _isTranscribing = true;
      _isScoreStale = true;
    }));

    _addTimer(8000, () {
      setState(() {
        _updateScore(68);
        _mockTranscript.add(_entry(TranscriptSpeaker.caller, '請告訴我您的身分證字號與銀行帳號。'));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
    _addTimer(8400, () => setState(() {
      _isTranscribing = true;
      _isScoreStale = true;
    }));

    _addTimer(11000, () {
      setState(() {
        _updateScore(83);
        _mockTranscript.add(_entry(
          TranscriptSpeaker.caller,
          '否則帳號將在 30 分鐘內被停用。',
          isHighRisk: true,
        ));
        _isTranscribing = false;
        _isScoreStale = false;
      });
      _scrollToBottom();
    });
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,  // Position 0 = visual bottom with reversed ListView
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _dotTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerDismissTimer?.cancel();
    for (final t in _mockTimers) {
      t.cancel();
    }
    _audioSub?.cancel();
    _audio.stopPlay();
    _scroll.dispose();
    if (!_isMock) {
      _cp.removeListener(_onProviderUpdate);
      unawaited(_cp.stopMicStream());
    }
    super.dispose();
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();

    if (!_isMock && !cp.hasActiveCall && !_isHangingUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final int score = _isMock
        ? _mockScore
        : (cp.scamProbability * 100).round();
    final int durSecs = _isMock ? _durationSecs : cp.callDuration.inSeconds;
    final String caller = _isMock
        ? (widget.callerNumber ?? (_isOutgoing ? '0912-345-678' : '0800-123-456'))
        : (widget.callerNumber?.isNotEmpty == true
            ? widget.callerNumber!
            : (cp.callerPhone?.isNotEmpty == true
                ? cp.callerPhone!
                : (cp.callId ?? 'Private Number')));
    final List<TranscriptEntry> transcript = _isMock
        ? _mockTranscript
        : cp.fcmTranscript.isNotEmpty
            ? cp.fcmTranscript
            : cp.history.reversed
                .map((e) => TranscriptEntry(
                      speaker: TranscriptSpeaker.caller,
                      text: e.transcript,
                      time: e.time,
                      isHighRisk: (e.stage ?? 0) >= 3,
                    ))
                .toList();

    final bool isTranscribing = _isMock ? _isTranscribing : cp.streaming;
    final bool isScoreStale = _isMock ? _isScoreStale : false;

    final bool hasScore = score > 0;
    final bool isHighRisk = score >= 80 || (!_isMock && cp.isFraudAlert);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildPills(),
            _buildSpeakerBanner(),
            _buildHeader(caller, durSecs),
            _buildRiskBlock(score, hasScore, isScoreStale),
            const SizedBox(height: 6),
            Expanded(
              child: _buildTranscriptSection(transcript, isTranscribing),
            ),
            if (!_isMock && cp.isSafeToAnswer && !isHighRisk) _buildSafeToAnswerBanner(),
            if (isHighRisk) _buildWarning(),
            const SizedBox(height: 12),
            _buildButtons(isHighRisk, _isOutgoing),
            const SizedBox(height: 10),
            _buildSpeaker(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────────

  Widget _buildSpeakerBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: _showSpeakerBanner
          ? Center(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Speaker automatically enabled',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildPills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          const _Pill(label: 'Fraud Detection Active'),
          _Pill(
            label: (_isOutgoing || _userAnswered) ? 'Monitoring Active' : 'AI Answering',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String caller, int secs) {
    final String label = _isOutgoing
        ? (widget.contactName ?? 'Outgoing Call')
        : (widget.contactName ?? caller);

    final String topLabel = _isOutgoing
        ? 'Outgoing'
        : (_userAnswered ? 'In Call' : 'Incoming');

    final bool showNumberBelow =
        widget.contactName != null && widget.callerNumber != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topLabel,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (_isOutgoing || showNumberBelow)
                Text(
                  caller,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
            ],
          ),
          Text(
            _fmt(secs),
            style: GoogleFonts.itim(fontSize: 24, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBlock(int score, bool hasScore, bool isScoreStale) {
    if (!hasScore) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Analyzing call...',
              style: TextStyle(fontSize: 18, color: Colors.white54),
            ),
            const Spacer(),
            if (!_isOutgoing && !_userAnswered)
              const Text(
                'AI is answering for you',
                style: TextStyle(fontSize: 14, color: Colors.white38),
              ),
          ],
        ),
      );
    }

    final bg = _riskBg(score);
    final fg = _riskFg(score);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: score),
                duration: const Duration(milliseconds: 600),
                builder: (_, val, __) => Text(
                  '$val',
                  style: GoogleFonts.itim(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Score',
                      style: TextStyle(
                        fontSize: 14,
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: fg.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _riskLabel(score),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 600),
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: 6,
                backgroundColor: fg.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (isScoreStale)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Updating risk assessment...',
                    style: TextStyle(
                      fontSize: 13,
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: fg.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 4),
              Text(
                'Risk score updates every few exchanges',
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection(
      List<TranscriptEntry> entries, bool isTranscribing) {
    return Column(
      children: [
        Expanded(
          child: entries.isEmpty
              ? _buildEmptyTranscript()
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _buildBubble(entries[entries.length - 1 - i]),
                ),
        ),
        if (isTranscribing) _buildTranscribingIndicator(),
      ],
    );
  }

  Widget _buildEmptyTranscript() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 36,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 10),
          const Text(
            'Waiting for caller to speak',
            style: TextStyle(fontSize: 18, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          const Text(
            'Call content will appear here',
            style: TextStyle(fontSize: 15, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_in_talk_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E30),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  AnimatedOpacity(
                    opacity: _dotPhase == i ? 1.0 : 0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening...',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              Text(
                'Will appear shortly',
                style: TextStyle(fontSize: 13, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(TranscriptEntry e) {
    final isCaller = e.speaker == TranscriptSpeaker.caller;
    final Color bg = e.isHighRisk
        ? const Color(0xFF4A0F0F)
        : (isCaller
            ? const Color(0xFF1E1E30)
            : const Color(0xFF0F2030));
    final Color textColor = e.isHighRisk
        ? const Color(0xFFFF8A80)
        : Colors.white.withValues(alpha: 0.9);
    final Border? border = e.isHighRisk
        ? Border.all(color: const Color(0xFF9B2020), width: 1)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCaller ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isCaller) ...[
            _Avatar(isCaller: true),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft:
                      isCaller ? Radius.zero : const Radius.circular(14),
                  bottomRight:
                      isCaller ? const Radius.circular(14) : Radius.zero,
                ),
                border: border,
              ),
              child: Text(
                e.text,
                style: TextStyle(
                  fontSize: 17,
                  color: textColor,
                  height: 1.55,
                ),
              ),
            ),
          ),
          if (!isCaller) ...[
            const SizedBox(width: 8),
            _Avatar(isCaller: false),
          ],
        ],
      ),
    );
  }

  Widget _buildSafeToAnswerBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.55), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Call appears safe',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Low fraud risk — safe to answer',
                  style: TextStyle(fontSize: 14, color: Color(0xFF81C784)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.55), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF5252), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High-risk fraud detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF5252),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Strongly recommend hanging up now',
                  style: TextStyle(fontSize: 15, color: Color(0xFFFF8A80)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(bool isHighRisk, bool isOutgoing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: isHighRisk
          ? _highRiskBtns(isOutgoing)
          : _normalBtns(isOutgoing),
    );
  }

  Widget _normalBtns(bool isOutgoing) {
    final bool showMonitor = isOutgoing || _userAnswered;
    return Row(
      children: [
        if (!showMonitor) ...[
          Expanded(
            child: _Btn(
              label: 'Answer Call',
              icon: Icons.call,
              color: const Color(0xFF4CAF50),
              filled: false,
              onTap: _onAccept,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _Btn(
            label: showMonitor ? 'Continue' : 'Hang Up',
            icon: showMonitor ? Icons.phone_in_talk_rounded : Icons.call_end,
            color: showMonitor
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
            filled: !showMonitor,
            onTap: showMonitor ? _onContinue : _onHangup,
          ),
        ),
        if (showMonitor) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _Btn(
              label: 'Hang Up',
              icon: Icons.call_end,
              color: const Color(0xFFF44336),
              filled: true,
              onTap: _onHangup,
            ),
          ),
        ],
      ],
    );
  }

  Widget _highRiskBtns(bool isOutgoing) {
    final bool showMonitor = isOutgoing || _userAnswered;
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: 0.4,
            child: _Btn(
              label: showMonitor ? 'Continue' : 'Still Answer',
              icon: showMonitor
                  ? Icons.phone_in_talk_rounded
                  : Icons.call,
              color: Colors.white54,
              filled: false,
              onTap: showMonitor ? _onContinue : _onAccept,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _Btn(
            label: 'Hang Up Now',
            icon: Icons.call_end,
            color: const Color(0xFFF44336),
            filled: true,
            large: true,
            onTap: _onHangup,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeaker() {
    return GestureDetector(
      onTap: () => setState(() => _speakerOn = !_speakerOn),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white
                .withValues(alpha: _speakerOn ? 0.28 : 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: Colors.white
                  .withValues(alpha: _speakerOn ? 0.9 : 0.35),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              _speakerOn ? 'Speaker On' : 'Speaker Off',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.white
                    .withValues(alpha: _speakerOn ? 0.9 : 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────────

  void _onAccept() {
    for (final t in _mockTimers) {
      t.cancel();
    }
    _mockTimers.clear();
    setState(() => _userAnswered = true);
    if (!_isMock) {
      _cp.acceptCall();
      unawaited(sl<ApiService>().answerCall());
    }
  }

  void _onContinue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('(Demo) Call continuing, detection active'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onHangup() {
    _isHangingUp = true;
    for (final t in _mockTimers) {
      t.cancel();
    }
    _mockTimers.clear();

    if (_isMock) {
      final String displayName = widget.contactName ??
          (widget.callerNumber ??
              (_isOutgoing ? '0912-345-678' : '0800-123-456'));
      final String number = widget.callerNumber ??
          (_isOutgoing ? '0912-345-678' : '0800-123-456');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallSummaryPage(
            callerDisplay: displayName,
            callerNumber: number,
            durationSecs: _durationSecs,
            finalScore: _maxScore,
            scoreHistory: List.from(_scoreHistory),
            transcript: List.from(_mockTranscript),
            wasIncoming: !_isOutgoing,
            userAnswered: _userAnswered,
          ),
        ),
      );
    } else {
      // 先擷取逐字稿與 conversationId，hangup() 會清空
      final transcript = List<TranscriptEntry>.from(_cp.fcmTranscript);
      final convId = _cp.conversationId;
      final dur = _durationSecs;
      unawaited(_cp.hangup());
      // 把通話時長存到本機，供通話記錄頁顯示
      if (convId != null && dur > 0) {
        SharedPreferences.getInstance().then((p) {
          p.setInt('call_dur_$convId', dur);
        });
      }
      if (mounted) {
        final display = widget.contactName ?? widget.callerNumber ?? 'Unknown';
        final number = widget.callerNumber ?? '';
        final nav = Navigator.of(context);
        nav.pushReplacement(
          MaterialPageRoute(
            builder: (_) => CallSummaryPage(
              callerDisplay: display,
              callerNumber: number,
              durationSecs: _durationSecs,
              finalScore: _scoreHistory.isEmpty ? null : _maxScore,
              scoreHistory: List.from(_scoreHistory),
              transcript: transcript,
              wasIncoming: !_isOutgoing,
              userAnswered: _userAnswered,
              onViewTranscript: convId == null ? null : () => nav.push(
                MaterialPageRoute(
                  builder: (_) => ConversationDetailPage(
                    conversation: Conversation(
                      id: convId,
                      metadata: ConversationMetadata(
                        callerPhoneNumber: number.isEmpty ? null : number,
                        callerName: widget.contactName,
                      ),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A2F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF81C784)),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isCaller;
  const _Avatar({required this.isCaller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCaller
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isCaller ? Icons.phone_in_talk_rounded : Icons.smart_toy_outlined,
        size: 14,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool large;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    this.large = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = large ? 20 : 18;
    final double vPad = large ? 22 : 20;

    if (filled) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: vPad),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: large ? 4 : 0,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: large ? 26 : 22),
        label: Text(
          label,
          style:
              TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color, width: 1.5),
        foregroundColor: color,
        padding: EdgeInsets.symmetric(vertical: vPad),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: large ? 26 : 22),
      label: Text(
        label,
        style:
            TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
    );
  }
}
