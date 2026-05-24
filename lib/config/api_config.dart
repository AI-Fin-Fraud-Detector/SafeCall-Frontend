class ApiConfig {
  ApiConfig._();

  // =========================
  // Feature flags
  // =========================
  static const bool mockLogin = false;
  static const Duration mockDelay = Duration(milliseconds: 600);

  static const bool mockWs = false;
  static const Duration mockWsInterval = Duration(seconds: 2);

  // 獨立的通話 UI mock 開關（true = CallPage 用內建 timer 序列，不需要後端）
  static const bool mockCallUi = false;

  // =========================
  // REST API（登入 / chat / food / hangup / logout）
  // =========================
  static const String apiBaseUrl = 'https://vision.futuremedialab.tw:1688';

  static const String baseUrl = apiBaseUrl;

  // ---- REST paths (依你 Postman 截圖) ----
  static const String loginPath = '/api/auth/login';
  static const String statusPath = '/api/auth/status';
  static const String chatPath = '/api/chat/';
  static const String foodRecognitionPath = '/api/food-recognition/';
  static const String fraudPath = '/api/fraud/';
  static const String pushSubscribePath = '/api/push/subscribe/kebbi';
  static const String conversationsPath = '/api/fraud/conversations';
  static const String hangupPath = '/api/hangup';
  static const String logoutPath = '/auth/logout';

  // =========================

  // =========================
  static const String socketBaseUrl = 'https://vision.futuremedialab.tw:1688';

  static const String wsBase = 'wss://vision.futuremedialab.tw:1688';

  // =========================
  // Common headers / device id
  // =========================
  static const String installationIdHeader = 'X-Installation-Id';

  static const String defaultInstallationId = 'device001';

  static const bool devBypassLogin = false;

// 給一個假 token，後端開了再改回 false
  static const String devFakeAccessToken = 'dev-fake-token';
}
