import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/line_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _bindingLine = false;
  String? _message;
  String? _error;
  bool _loadingLineStatus = true;
  bool _lineBound = false;

  @override
    void initState() {
      super.initState();
      _loadLineStatus();
    }

    Future<void> _loadLineStatus() async {
      try {
        final bound = await LineService.I.getBindingStatus();

        if (!mounted) return;

        setState(() {
          _lineBound = bound;
          _loadingLineStatus = false;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _loadingLineStatus = false;
          _error = 'Unable to get LINE binding status: $e';
        });
      }
    }

  Future<void> _bindLine() async {
    if (_bindingLine) return;

    setState(() {
      _bindingLine = true;
      _message = null;
      _error = null;
    });

    try {
      final loginUrl = await LineService.I.getLoginUrl();

      if (!mounted) return;

      // Kebbi has no LINE app or browser, so the LINE Login URL is shown as a
      // QR code to scan with a phone. When the app itself runs on a phone, the
      // dialog also offers a button that opens the URL directly. Either way the
      // backend binds the account and the dialog polls status until then.
      final bound = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LineQrDialog(url: loginUrl),
      );

      if (!mounted) return;

      // Cancel / expiry can close the dialog while a status poll is in flight,
      // so the binding may have completed anyway: re-check before reporting.
      var bindingCompleted = bound == true;
      if (!bindingCompleted) {
        await _loadLineStatus();
        if (!mounted) return;
        bindingCompleted = _lineBound;
      }

      setState(() {
        if (bindingCompleted) {
          _lineBound = true;
          _message = 'LINE account connected.';
        } else {
          _message = 'LINE binding was not completed.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'LINE binding failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _bindingLine = false;
        });
      }
    }
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSeaBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 32,
                      color: iconColor,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.itim(
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.itim(
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.itim(
            fontSize: 24,
            color: textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Notification',
              style: GoogleFonts.itim(
                fontSize: 17,
                color: textColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildSettingItem(
              icon: _lineBound
                  ? Icons.check_circle_outline
                  : Icons.chat_bubble_outline,
              title: _lineBound
                  ? 'LINE Connected'
                  : 'Bind LINE',
              subtitle: _loadingLineStatus
                  ? 'Checking LINE binding status...'
                  : _lineBound
                      ? 'Your LINE account is connected to SafeCall'
                      : 'Connect your LINE account to SafeCall',
              loading:
                  _bindingLine || _loadingLineStatus,
              onTap:
                  (_bindingLine || _loadingLineStatus || _lineBound)
                      ? null
                      : _bindLine,
            ),

            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _message!,
                  style: GoogleFonts.itim(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.itim(
                    fontSize: 14,
                    color: const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a QR code for the LINE Login URL and closes itself with `true` once
/// the backend reports the account as bound, or `false` on cancel / expiry.
class _LineQrDialog extends StatefulWidget {
  const _LineQrDialog({required this.url});

  final String url;

  @override
  State<_LineQrDialog> createState() => _LineQrDialogState();
}

class _LineQrDialogState extends State<_LineQrDialog> {
  static const _pollInterval = Duration(seconds: 2);
  // The backend keeps the login state for 10 minutes; stop a bit earlier.
  static const _expiry = Duration(minutes: 9);

  late final DateTime _deadline = DateTime.now().add(_expiry);
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_checking) return;

    if (DateTime.now().isAfter(_deadline)) {
      _timer?.cancel();
      if (mounted) Navigator.pop(context, false);
      return;
    }

    _checking = true;
    try {
      final bound = await LineService.I.getBindingStatus();
      if (bound && mounted) {
        _timer?.cancel();
        Navigator.pop(context, true);
      }
    } catch (_) {
      // transient network error: keep polling until the deadline
    } finally {
      _checking = false;
    }
  }

  Future<void> _openOnThisDevice() async {
    try {
      final launched = await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('Unable to open LINE Login page.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open LINE login: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: backgroundColor,
      title: Text(
        'Bind LINE',
        style: GoogleFonts.itim(fontSize: 22, color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(
              data: widget.url,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan this QR code with your phone, then log in to LINE and allow access.',
            textAlign: TextAlign.center,
            style: GoogleFonts.itim(fontSize: 15, color: textColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openOnThisDevice,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              'Open LINE on this device',
              style: GoogleFonts.itim(fontSize: 16, color: textColor),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.itim(fontSize: 16, color: textColor),
          ),
        ),
      ],
    );
  }
}
