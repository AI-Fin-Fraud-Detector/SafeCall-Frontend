import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '/models/login_models.dart';
import '/services/api_service.dart';
import '/services/debug_logger.dart';
import '/services/fcm_service.dart';
import '/services/secure_storage.dart';
import '/config/api_config.dart';
import 'package:get_it/get_it.dart';
import '../di/service_locator.dart';


class AuthProvider extends ChangeNotifier {
  final ApiService _api = sl<ApiService>();

  bool _loading = false;
  bool get loading => _loading;

  String? _token;
  String? get token => _token;

  String? _uuid;
  String? get uuid => _uuid;

  String? _name;
  String? get name => _name;

  String? _email;
  String? get email => _email;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;

  Future<void> init() async {
    // Load all auth data FIRST before calling _registerFcmToken
    try {
      _token = await SecureStorage.readToken();
      _uuid = await SecureStorage.readUuid();
      _name = await SecureStorage.readName();
      _email = await SecureStorage.readEmail();
      _phoneNumber = await SecureStorage.readPhone();
    } catch (_) {}

    if (_token != null && _token!.isNotEmpty) {
      sl<ApiService>().setAccessToken(_token);
      _registerFcmToken();
    }
    notifyListeners();
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();

    if (ApiConfig.devBypassLogin) {
      final fakeToken = ApiConfig.devFakeAccessToken;

      _token = fakeToken;
      GetIt.I<ApiService>().setAccessToken(fakeToken);
      _uuid = 'dev-uuid';
      _name = 'Dev User';
      _email = email;
      _phoneNumber = '';

      await SecureStorage.saveLogin(
        token: fakeToken,
        uuid: _uuid!,
        name: _name!,
        email: _email!,
        phoneNumber: '',
      );

      _registerFcmToken();
      _loading = false;
      notifyListeners();
      return null;
    }

    try {
      final res = await _api.login(LoginRequest(email: email, password: password));
      _token = res.accessToken;
      GetIt.I<ApiService>().setAccessToken(res.accessToken);
      _uuid = res.uuid;
      _name = res.name;
      _email = res.email;
      _phoneNumber = res.phoneNumber;

      await SecureStorage.saveLogin(
        token: res.accessToken,
        uuid: res.uuid,
        name: res.name,
        email: res.email,
        phoneNumber: res.phoneNumber,
      );

      _registerFcmToken();

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _uuid = null;
    _name = null;
    _email = null;
    _phoneNumber = null;
    await SecureStorage.clear();
    notifyListeners();
  }

  bool get isLoggedIn => _token?.isNotEmpty == true;

  /// 取得 FCM token 並向後端註冊，若失敗或返回 null 則使用 SSE fallback
  Future<void> _registerFcmToken() async {
    DebugLogger.I.log('[Auth] _registerFcmToken() called');

    if (_token == null || _uuid == null) {
      DebugLogger.I.log('[Auth] Missing token or uuid, skipping FCM registration');
      return;
    }

    DebugLogger.I.log('[Auth] Getting FCM token...');
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      DebugLogger.I.log('[Auth] getToken() returned: ${fcmToken?.substring(0, 20) ?? "null"}...');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        DebugLogger.I.log('[Auth] ✓ Got FCM token: ${fcmToken.substring(0, 20)}...');
        try {
          await sl<ApiService>().registerFcmToken(fcmToken);
          DebugLogger.I.log('[Auth] ✓ FCM token registered successfully');
          return;
        } catch (registerError) {
          DebugLogger.I.log('[Auth] ✗ FCM registration ERROR: $registerError');
          DebugLogger.I.log('[Auth] → Initializing SSE fallback due to registration failure');
          await _initializeSSEFallback();
          return;
        }
      } else {
        DebugLogger.I.log('[Auth] ✗ FCM token is NULL (iOS/simulator)');
        DebugLogger.I.log('[Auth] → Initializing SSE fallback due to null token');
        await _initializeSSEFallback();
      }
    } catch (e) {
      DebugLogger.I.log('[Auth] ✗ FCM getToken() ERROR: $e');
      DebugLogger.I.log('[Auth] → Initializing SSE fallback due to getToken error');
      await _initializeSSEFallback();
    }
  }

  Future<void> _initializeSSEFallback() async {
    try {
      DebugLogger.I.log('[Auth] Starting SSE fallback initialization for userId=$_uuid...');
      await FcmService.I.initializeSSEFallback(
        ApiConfig.baseUrl,
        _uuid!,
        _token!,
      );
      DebugLogger.I.log('[Auth] SSE fallback initialized successfully');
    } catch (e) {
      DebugLogger.I.log('[Auth] SSE fallback initialization failed: $e');
      rethrow;
    }
  }
}
