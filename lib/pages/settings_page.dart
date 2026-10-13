import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

      final uri = Uri.parse(loginUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Unable to open LINE Login page.');
      }

      if (!mounted) return;

      setState(() {
        _message = 'The LINE login page has been opened. Please complete the account login and authorization.';
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
                  (_bindingLine || _loadingLineStatus)
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