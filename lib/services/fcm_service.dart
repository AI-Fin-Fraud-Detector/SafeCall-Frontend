import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_logger.dart';
import 'sse_service.dart';

const _kNotifHistoryKey = 'fcm_notif_history';

/// 背景訊息 handler — 必須是 top-level function，跑在獨立 isolate
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.data}');
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kNotifHistoryKey);
    final List<dynamic> history = existing != null ? jsonDecode(existing) : [];
    history.add({
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': data,
    });
    await prefs.setString(_kNotifHistoryKey, jsonEncode(history));
  }
}

/// FCM 通知資料（含完整 data map）
class FcmNotifData {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const FcmNotifData({this.title, this.body, required this.data});

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'data': data,
      };

  factory FcmNotifData.fromJson(Map<String, dynamic> json) => FcmNotifData(
        title: json['title'] as String?,
        body: json['body'] as String?,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      );
}

class FcmService with WidgetsBindingObserver {
  FcmService._();
  static final FcmService I = FcmService._();

  /// 所有歷史通知（最新在最後）
  final ValueNotifier<List<FcmNotifData>> notifHistory =
      ValueNotifier(const []);

  /// 所有 FCM data 事件的 broadcast stream（incoming_call / call_*_message）
  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventCtrl.stream;

  /// 用戶點通知後的 callback → (conversationId, phoneNumber, callerName)
  void Function(String conversationId, String phoneNumber, String? callerName)?
      onIncomingCall;

  bool _fcmFailed = false;
  bool get needsSSEFallback => _fcmFailed;

  Future<String?> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    WidgetsBinding.instance.addObserver(this);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    DebugLogger.I.log('FCM permission: ${settings.authorizationStatus}');

    await loadPersistedNotif();

    FirebaseMessaging.onMessage.listen(_storeAndNavigate);
    FirebaseMessaging.onMessageOpenedApp.listen(_storeAndNavigate);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _storeAndNavigate(initial);

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] Token: $fcmToken');
      DebugLogger.I.log('FCM token: ${fcmToken ?? "null"}');

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        DebugLogger.I.log('FCM token refreshed: $newToken');
        _onTokenRefreshed?.call(newToken);
      });

      return fcmToken;
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('[FCM] getToken error: $errorStr');
      DebugLogger.I.log('FCM getToken error: $errorStr');

      if (errorStr.contains('MISSING_INSTANCEID_SERVICE') ||
          errorStr.contains('An unknown error occurred') ||
          errorStr.contains('APNS token') ||
          errorStr.contains('null')) {
        debugPrint('[FCM] FCM unavailable - will use SSE fallback');
        DebugLogger.I.log('FCM unavailable - will use SSE fallback');
      }

      _fcmFailed = true;
      return null;
    }
  }

  Future<void> initializeSSEFallback(String baseUrl, String userId, String token) async {
    if (!_fcmFailed) {
      debugPrint('[FCM] FCM is working, SSE fallback not needed');
      DebugLogger.I.log('FCM is working, SSE fallback not needed');
      return;
    }

    debugPrint('[FCM] Starting SSE fallback: userId=$userId, baseUrl=$baseUrl');
    DebugLogger.I.log('FCM Starting SSE fallback initialization');

    // Subscribe to SSE events and forward to FCM event stream
    SSEService.I.events.listen((event) {
      debugPrint('[FCM] SSE event received: ${event['type']}');
      _eventCtrl.add(event);
      if (event['type'] == 'incoming_call') {
        debugPrint('[FCM] Processing incoming_call from SSE');
        _storeMessage(RemoteMessage(
          data: event,
          notification: RemoteNotification(
            title: event['title'] as String?,
            body: event['body'] as String?,
          ),
        ));
      }
    });

    try {
      await SSEService.I.connect(
        userId: userId,
        app: 'kebbi',
        token: token,
        baseUrl: baseUrl,
      );
      debugPrint('[FCM] SSE fallback initialized successfully');
      DebugLogger.I.log('FCM SSE fallback initialized successfully');
    } catch (e) {
      debugPrint('[FCM] SSE fallback connection failed: $e');
      DebugLogger.I.log('FCM SSE fallback connection failed: $e');
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadPersistedNotif();
    }
  }

  Future<void> loadPersistedNotif() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_kNotifHistoryKey);
    if (raw == null) return;
    try {
      final List<dynamic> list = jsonDecode(raw);
      final parsed = list
          .map((e) => FcmNotifData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      notifHistory.value = parsed;
    } catch (e) {
      debugPrint('[FCM] Failed to parse notif history: $e');
    }
  }

  void Function(String newToken)? _onTokenRefreshed;

  void setTokenRefreshCallback(void Function(String) cb) {
    _onTokenRefreshed = cb;
  }

  /// 解析可能是 JSON string 或已解析 Map 的欄位
  Map<String, dynamic> _parseField(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        return jsonDecode(value) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  Future<void> _storeMessage(RemoteMessage message) async {
    debugPrint('[FCM] Message received: ${message.data}');
    final data = message.data;
    final type = data['type'] as String? ?? '';

    // 只把 incoming_call 存通知歷史（其他 type 是即時資料，不需要持久化）
    if (type == 'incoming_call') {
      final notif = FcmNotifData(
        title: message.notification?.title,
        body: message.notification?.body,
        data: data,
      );
      final updated = [...notifHistory.value, notif];
      notifHistory.value = updated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kNotifHistoryKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    }

    // 所有 type 都 emit 給 CallProvider 處理
    if (type.isNotEmpty) {
      final convId = data['conversation_id'] as String? ?? '';
      DebugLogger.I.log('FCM event: $type${convId.isNotEmpty ? " conv=$convId" : ""}');
      _eventCtrl.add(Map<String, dynamic>.from(data));
    }
  }

  Future<void> _storeAndNavigate(RemoteMessage message) async {
    await _storeMessage(message);
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      final detail = _parseField(data['detail']);
      final conversationId = detail['conversation_id'] as String? ?? '';
      final phoneNumber =
          detail['phone_number'] as String? ?? data['phone_number'] as String? ?? '';
      final callerName =
          detail['caller_name'] as String? ?? data['caller_name'] as String?;

      if (conversationId.isNotEmpty) {
        onIncomingCall?.call(conversationId, phoneNumber, callerName);
      }
    }
  }
}
