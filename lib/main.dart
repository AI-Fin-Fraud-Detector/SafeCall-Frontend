import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pwa_install/pwa_install.dart';

import 'constants.dart';
import 'di/service_locator.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'services/debug_logger.dart';
import 'services/fcm_service.dart';
import 'services/kebbi_service.dart';
import 'services/permissions_service.dart';
import 'services/permissions_service.dart';
import 'widgets/auth_guard.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';
import 'pages/monitor_page.dart';
import 'pages/call_page.dart';
import 'pages/stats_page.dart';
import 'pages/food_recognition_page.dart';
import 'pages/butler_chat_page.dart';
import 'pages/contacts_page.dart';
import 'pages/conversations_page.dart';

/// 全域 NavigatorKey — 供 FcmService 在 widget tree 外部導航使用
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初始化（FCM 需要；沒有設定檔時跳過，不影響 UI 開發）
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  PWAInstall().setup(installCallback: () {
    DebugLogger.I.log('APP INSTALLED!');
  });

  KebbiService.init();
  setupServiceLocator();

  // Request required permissions on app startup
  PermissionsService.I.requestAllPermissions().then((results) {
    DebugLogger.I.log('[main] Permission on startup: $results');
  }).catchError((e) {
    DebugLogger.I.log('[main] Permission request error: $e');
  });


  // FCM 初始化 — 收到 incoming_call 時跳轉到 CallPage
  FcmService.I.onIncomingCall = (conversationId, phoneNumber, callerName) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CallPage(
          mode: CallMode.incoming,
          contactName: callerName,
          callerNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        ),
      ),
      (route) => route.isFirst,
    );
  };

  // Handle remote hangup (when other side ends call)
  FcmService.I.onRemoteHangup = () {
    DebugLogger.I.log('[main] Remote hangup callback triggered');
    try {
      final callProvider = GetIt.I<CallProvider>();
      if (callProvider.inCall) {
        DebugLogger.I.log('[main] Ending call due to remote hangup (NOT sending API)');
        callProvider.endCallFromRemote();
      }
    } catch (e) {
      DebugLogger.I.log('[main] Error handling remote hangup: $e');
    }
  };

  // 初始化並取得 FCM token（非同步，不阻擋啟動）
  FcmService.I.initialize().then((token) {
    if (token != null) {
      DebugLogger.I.log('[main] FCM token ready: $token');
    } else if (FcmService.I.needsSSEFallback) {
      DebugLogger.I.log('[main] FCM unavailable, will use SSE fallback after login');
    }
  }).catchError((e) {
    DebugLogger.I.log('[main] FCM initialization error: $e');
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Fraud Detect App',
      theme: ThemeData(
        textTheme: GoogleFonts.itimTextTheme(),
        primaryTextTheme: GoogleFonts.itimTextTheme(),
        scaffoldBackgroundColor: backgroundColor,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/menu': (context) => const MenuPage(),
        '/monitor': (context) => const AuthGuard(child: MonitorPage()),
        '/contacts': (context) => const AuthGuard(child: ContactsPage()),
        '/conversations': (context) => const AuthGuard(child: ConversationsPage()),
        '/stats': (context) => const AuthGuard(child: StatsPage()),
        '/food': (_) => const FoodRecognitionPage(),
        '/butler': (_) => const ButlerChatPage(),
      },
    );
  }
}
