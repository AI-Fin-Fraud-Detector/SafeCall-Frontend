import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/call_transcript.dart';

// ── Risk helpers ──────────────────────────────────────────────────────────────

Color _riskFg(int score) {
  if (score < 40) return const Color(0xFF1B5E20);
  if (score < 60) return const Color(0xFFF57F17);
  if (score < 80) return const Color(0xFFBF360C);
  return const Color(0xFFB71C1C);
}

Color _riskBg(int score) {
  if (score < 40) return const Color(0xFFE8F5E9);
  if (score < 60) return const Color(0xFFFFF8E1);
  if (score < 80) return const Color(0xFFFBE9E7);
  return const Color(0xFFFFEBEE);
}

String _riskLabel(int score) {
  if (score < 40) return 'Safe';
  if (score < 60) return 'Caution';
  if (score < 80) return 'Warning';
  return 'Danger';
}

String _riskDescription(int score) {
  if (score < 40) return 'No fraud detected. Stay vigilant.';
  if (score < 60) return 'Some suspicious signs detected. Avoid sharing personal information.';
  if (score < 80) return 'Significant fraud indicators detected. We recommend ending the call.';
  return 'Highly suspected fraud. Do not share personal information or transfer money.';
}

Color _chartColor(int score) {
  if (score < 40) return const Color(0xFF4CAF50);
  if (score < 60) return const Color(0xFFFFCA28);
  if (score < 80) return const Color(0xFFFF7043);
  return const Color(0xFFF44336);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class CallSummaryPage extends StatelessWidget {
  final String callerDisplay;
  final String callerNumber;
  final int? durationSecs;   // null = 歷史紀錄無此資料
  final int? finalScore;     // null = Edge 尚未串接，顯示佔位
  final List<({int seconds, int score})> scoreHistory;
  final List<TranscriptEntry> transcript;
  final bool wasIncoming;
  final bool userAnswered;
  final String pageTitle;
  final VoidCallback? onViewTranscript; // 若設定，底部顯示「查看逐字稿」按鈕

  const CallSummaryPage({
    super.key,
    required this.callerDisplay,
    required this.callerNumber,
    this.durationSecs,
    this.finalScore,
    required this.scoreHistory,
    required this.transcript,
    required this.wasIncoming,
    required this.userAnswered,
    this.pageTitle = 'Call Ended',
    this.onViewTranscript,
  });

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighRisk = finalScore != null && finalScore! >= 60;
    final List<TranscriptEntry> suspicious =
        transcript.where((e) => e.isHighRisk).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          pageTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCallInfoCard(),
            const SizedBox(height: 14),
            _buildRiskSummary(),
            if (scoreHistory.length >= 2) ...[
              const SizedBox(height: 14),
              _buildScoreChart(),
            ],
            if (suspicious.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildSuspiciousPhrases(suspicious),
            ],
            if (isHighRisk) ...[
              const SizedBox(height: 14),
              _buildActions(context),
            ],
            if (onViewTranscript != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onViewTranscript,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Colors.black26),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 20, color: Colors.black54),
                label: const Text(
                  'View Transcript',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Colors.black26),
              ),
              child: const Text(
                'Back to Home',
                style: TextStyle(fontSize: 17, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Call info ─────────────────────────────────────────────────────────────────

  Widget _buildCallInfoCard() {
    final Color tagColor =
        wasIncoming ? const Color(0xFF1B5E20) : const Color(0xFF0D47A1);
    final Color tagBg =
        wasIncoming ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);
    final IconData callIcon = wasIncoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: tagBg, shape: BoxShape.circle),
            child: Icon(callIcon, color: tagColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callerDisplay,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  callerNumber,
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      label: wasIncoming ? 'Incoming' : 'Outgoing',
                      color: tagColor,
                      bg: tagBg,
                    ),
                    if (durationSecs != null)
                      _Tag(
                        label: _fmt(durationSecs!),
                        color: Colors.black54,
                        bg: const Color(0xFFF0F0F0),
                      ),
                    if (wasIncoming)
                      _Tag(
                        label: userAnswered ? 'Answered by User' : 'Answered by AI',
                        color: Colors.black54,
                        bg: const Color(0xFFF0F0F0),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Risk summary ──────────────────────────────────────────────────────────────

  Widget _buildRiskSummary() {
    if (finalScore == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_empty_rounded,
                color: Colors.black38, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Risk Analysis',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start Edge service to get risk scores and trend chart.',
                    style: TextStyle(fontSize: 13, color: Colors.black38),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '⚠ Pending',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final fg = _riskFg(finalScore!);
    final bg = _riskBg(finalScore!);
    final IconData icon = finalScore! < 40
        ? Icons.check_circle_outline_rounded
        : finalScore! < 60
            ? Icons.info_outline_rounded
            : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 上半：文字為主，長者第一眼判斷風險 ──────────────────────────
          Row(
            children: [
              Icon(icon, color: fg, size: 28),
              const SizedBox(width: 10),
              Text(
                _riskLabel(finalScore!),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _riskDescription(finalScore!),
            style: TextStyle(fontSize: 15, color: fg, height: 1.55),
          ),

          // ── 分隔 ─────────────────────────────────────────────────────────
          const SizedBox(height: 16),
          Divider(color: fg.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),

          // ── 下半：label 左、大數字右 ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Peak\nRisk Score',
                style: TextStyle(
                  fontSize: 14,
                  color: fg.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${finalScore!}',
                    style: GoogleFonts.itim(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      ' /100',
                      style: TextStyle(
                        fontSize: 16,
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Score chart ───────────────────────────────────────────────────────────────

  Widget _buildScoreChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Score Trend',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Risk changes during the call',
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScoreChartPainter(scoreHistory),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suspicious phrases ────────────────────────────────────────────────────────

  Widget _buildSuspiciousPhrases(List<TranscriptEntry> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_rounded, color: Color(0xFFE53935), size: 20),
              SizedBox(width: 8),
              Text(
                'Suspicious phrases flagged by AI',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((e) => _SuspiciousPhrase(text: e.text)),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showBlockDialog(context),
              icon: const Icon(Icons.block_rounded, size: 22),
              label: const Text(
                'Block This Number',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (finalScore != null && finalScore! >= 80) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE53935)),
                  foregroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showReportDialog(context),
                icon: const Icon(Icons.report_rounded, size: 22),
                label: const Text(
                  'Report Fraud Call',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block This Number',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Blocking $callerNumber will automatically filter future calls from this number.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$callerNumber blocked (demo mode)'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Confirm Block',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Report Fraud Call',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Your report helps protect others. Thank you.\n\n(This feature is currently in demo mode)'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Report submitted (demo mode)'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Submit Report',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Tag({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class _SuspiciousPhrase extends StatelessWidget {
  final String text;
  const _SuspiciousPhrase({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Risk score chart ──────────────────────────────────────────────────────────

class _ScoreChartPainter extends CustomPainter {
  final List<({int seconds, int score})> data;

  const _ScoreChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const double padL = 36.0;
    const double padR = 14.0;
    const double padT = 8.0;
    const double padB = 26.0;

    final double plotW = size.width - padL - padR;
    final double plotH = size.height - padT - padB;
    final double maxSecs =
        data.last.seconds.toDouble().clamp(1.0, double.infinity);

    // ── Background risk zones ──────────────────────────────────────────────
    final zonePaint = Paint()..style = PaintingStyle.fill;
    for (final zone in [
      (min: 0.0, max: 40.0, color: const Color(0x084CAF50)),
      (min: 40.0, max: 60.0, color: const Color(0x08FFCA28)),
      (min: 60.0, max: 80.0, color: const Color(0x08FF7043)),
      (min: 80.0, max: 100.0, color: const Color(0x08F44336)),
    ]) {
      zonePaint.color = zone.color;
      final top = padT + plotH * (1 - zone.max / 100);
      final bottom = padT + plotH * (1 - zone.min / 100);
      canvas.drawRect(
          Rect.fromLTRB(padL, top, padL + plotW, bottom), zonePaint);
    }

    // ── Horizontal grid lines + Y labels ──────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (final val in [0, 25, 50, 75, 100]) {
      final y = padT + plotH * (1 - val / 100);
      canvas.drawLine(Offset(padL, y), Offset(padL + plotW, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '$val',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 5, y - tp.height / 2));
    }

    // ── Convert data to canvas offsets ────────────────────────────────────
    final List<Offset> pts = data.map((d) {
      final x = padL + (d.seconds / maxSecs) * plotW;
      final y = padT + plotH * (1 - d.score / 100);
      return Offset(x, y);
    }).toList();

    // ── Filled area under the line ────────────────────────────────────────
    final path = Path()..moveTo(pts.first.dx, padT + plotH);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(pts.last.dx, padT + plotH);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _chartColor(data.last.score).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // ── Line segments (colored by endpoint score) ─────────────────────────
    for (int i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(
        pts[i],
        pts[i + 1],
        Paint()
          ..color = _chartColor(data[i + 1].score)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Data point circles ────────────────────────────────────────────────
    for (int i = 0; i < pts.length; i++) {
      final color = _chartColor(data[i].score);
      canvas.drawCircle(pts[i], 5, Paint()..color = color);
      canvas.drawCircle(pts[i], 3, Paint()..color = Colors.white);
    }

    // ── X-axis time labels (first and last) ───────────────────────────────
    void drawTimeLabel(int secs, double x) {
      final m = secs ~/ 60;
      final s = secs % 60;
      final label =
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, size.height - padB + 6));
    }

    drawTimeLabel(data.first.seconds, pts.first.dx);
    drawTimeLabel(data.last.seconds, pts.last.dx);
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter old) =>
      old.data.length != data.length;
}
