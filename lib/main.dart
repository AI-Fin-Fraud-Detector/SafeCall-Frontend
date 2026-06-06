import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:get_it/get_it.dart';

import 'constants.dart';
import 'di/service_locator.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'services/api_service.dart';
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

/// 全域 CallProvider — 供 notification handler 使用
late CallProvider callProvider;

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

  // Initialize CallProvider EARLY so its FCM event listener is attached
  // before any notifications arrive via SSE/FCM
  callProvider = CallProvider();
  DebugLogger.I.log('[main] CallProvider initialized early for event listener');

  // Request required permissions on app startup
  PermissionsService.I.requestAllPermissions().then((results) {
    DebugLogger.I.log('[main] Permission on startup: $results');
  }).catchError((e) {
    DebugLogger.I.log('[main] Permission request error: $e');
  });


  // 用戶點擊通知時 (cases 2 & 3: tap notification while backgrounded or foreground)
  FcmService.I.onIncomingCall = (conversationId, phoneNumber, callerName) {
    DebugLogger.I.log('[main] Incoming call notification tapped: $phoneNumber ($callerName)');
    final nav = navigatorKey.currentState;
    if (nav == null) {
      DebugLogger.I.log('[main] Cannot navigate - navigator is null');
      return;
    }

    // Check backend for active call to decide where to navigate
    _checkActiveCallAndNavigate(nav, conversationId, phoneNumber, callerName);
  };

  // Handle remote hangup (when other side ends call)
  FcmService.I.onRemoteHangup = () {
    DebugLogger.I.log('[main] Remote hangup callback triggered');
    try {
      final context = navigatorKey.currentContext;
      DebugLogger.I.log('[main] Context available: ${context != null}');
      if (context != null) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        DebugLogger.I.log('[main] CallProvider hasActiveCall: ${callProvider.hasActiveCall}');
        if (callProvider.hasActiveCall) {
          DebugLogger.I.log('[main] Ending call due to remote hangup (NOT sending API)');
          callProvider.endCallFromRemote();
        } else {
          DebugLogger.I.log('[main] No active call, ignoring remote hangup');
        }
      } else {
        DebugLogger.I.log('[main] No context available for remote hangup');
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

  _runApp();
}

/// Check if user has active call, navigate accordingly
Future<void> _checkActiveCallAndNavigate(
  NavigatorState nav,
  String conversationId,
  String phoneNumber,
  String? callerName,
) async {
  try {
    final apiService = GetIt.I<ApiService>();
    final dioResponse = await apiService.dio.get('/api/fraud/active-call');
    final response = dioResponse.data as Map<String, dynamic>;

    final hasActiveCall = response['has_active_call'] as bool? ?? false;
    DebugLogger.I.log('[main] Backend active call check: $hasActiveCall');

    if (hasActiveCall) {
      // User is in another call - navigate to that call page and fetch messages
      final activeConversationId = response['conversation_id'] as String? ?? '';
      final activePhoneNumber = response['phone_number'] as String? ?? '';
      final activeCallerName = response['caller_name'] as String?;

      DebugLogger.I.log('[main] User in active call, fetching conversation messages');

      // Fetch conversation messages to sync with backend
      if (activeConversationId.isNotEmpty) {
        try {
          await apiService.dio.get('/api/fraud/conversations/$activeConversationId/messages');
          DebugLogger.I.log('[main] Conversation messages synced');
        } catch (e) {
          DebugLogger.I.log('[main] Failed to fetch messages: $e');
        }
      }

      DebugLogger.I.log('[main] Navigating to ongoing call');
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CallPage(
            mode: CallMode.incoming,
            contactName: activeCallerName,
            callerNumber: activePhoneNumber.isNotEmpty ? activePhoneNumber : null,
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      // No active call - show incoming call screen
      DebugLogger.I.log('[main] No active call, showing incoming call screen');
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
    }
  } catch (e) {
    DebugLogger.I.log('[main] Error checking active call: $e');
    // Fallback: show incoming call screen
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
  }
}

void _runApp() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider.value(value: callProvider),
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
