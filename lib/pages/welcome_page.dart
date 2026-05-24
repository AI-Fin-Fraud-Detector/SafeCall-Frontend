import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'call_page.dart';
import 'contacts_page.dart';


class _DevButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DevButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    // auth.init() 是非同步的，先等 frame 完成後檢查
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  void _checkAuth() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/menu');
    } else {
      // 等 init() 完成後再次檢查
      _authProvider = auth;
      auth.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      auth.removeListener(_onAuthChanged);
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 圓形 LOGO
            Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/image/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome',
              style: GoogleFonts.mogra(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: buttonColor,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.isLoggedIn) {
                  Navigator.pushReplacementNamed(context, '/menu');
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
              child: Text(
                'Start',
                style: GoogleFonts.mogra(fontSize: 18, color: backgroundColor),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Icon(Icons.code_rounded,
                              size: 14,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Dev Preview',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    _DevButton(
                      icon: Icons.call_received_rounded,
                      label: 'Incoming Call Detection',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CallPage()),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        color: Colors.black.withValues(alpha: 0.08)),
                    _DevButton(
                      icon: Icons.contacts_rounded,
                      label: 'Contacts (Outgoing)',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContactsPage()),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
