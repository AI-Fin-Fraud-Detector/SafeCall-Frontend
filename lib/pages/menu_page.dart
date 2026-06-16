// 主選單
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import 'debug_log_page.dart';
import 'call_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const _icons  = [Icons.contacts, Icons.history, Icons.fastfood, Icons.support_agent];
  static const _labels = ['Contacts', 'Call History', 'Food Recognition', 'Butler'];
  static const _routes = ['/contacts', '/conversations', '/food', '/butler'];

  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatElapsedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();
    final hasActiveCallWithId = cp.hasActiveCall && cp.conversationId != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text('Menu'),
        actions: [
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Debug Log',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugLogPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 0.8,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                ),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, _routes[index]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kSeaBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_icons[index], size: 48, color: iconColor),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _labels[index],
                          style: GoogleFonts.itim(fontSize: 17, color: textColor),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Active call badge — only show if has active call AND conversation_id exists
            if (hasActiveCallWithId)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () async {
                    await cp.syncCallStatusOnResume();
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallPage(
                            mode: CallMode.incoming,
                            contactName: cp.callerName,
                            callerNumber: cp.callerPhone,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _formatElapsedTime(cp.callDuration),
                          style: GoogleFonts.itim(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
