# SafeCall Frontend

AI 詐騙電話即時偵測系統，部署於 **Kebbi 機器人**（Android）。

---

## 系統架構

```
Samsung Galaxy (有 SIM 卡)
    │ 真實來電
    ▼
edge device (Python / uv)
    │ gRPC :60015  ─── STT + LLM + TTS
    ▼
backend (FastAPI :1688)
    ├── POST /api/auth/login
    ├── GET  /api/fraud/conversations
    ├── POST /api/fraud/call-end
    └── FCM push notifications
         │
         ▼
Kebbi Robot（此 Flutter App）
```

---

## 即時資料流（重要）

後端透過 **FCM Push Notification** 推送所有即時事件（非 WebSocket）：

| FCM type | 說明 |
|---|---|
| `incoming_call` | 來電通知，含 `conversation_id`、`phone_number` |
| `call_new_message` | 新增逐字稿（`message.id`、`role`、`content`） |
| `call_update_message` | 逐字稿修正（依 `message.id` 更新） |
| `call_delete_message` | 逐字稿刪除（依 `message.id` 移除） |

歷史資料透過 REST API 取得：`GET /api/fraud/conversations`

---

## 專案結構

```
frontend/lib/
├── config/
│   └── api_config.dart           # mockCallUi 開關、API base URL
├── constants.dart                # 顏色、主題常數
├── main.dart                     # App 入口、Provider 初始化、路由
├── di/
│   └── service_locator.dart      # GetIt 依賴注入
├── models/
│   ├── call_transcript.dart      # TranscriptEntry（逐字稿單筆）
│   ├── conversation_models.dart  # Conversation / ConversationMessage / ConversationMetadata
│   ├── fraud_models.dart         # FraudAnalysis（風險分數結構）
│   ├── login_models.dart         # LoginRequest / LoginResponse
│   ├── scam_event.dart           # ScamEvent（WebSocket 詐騙事件）
│   ├── stats_record.dart         # StatsRecord（測試統計）
│   └── ws_message.dart           # WsMessage / WsType（WebSocket 訊息）
├── pages/
│   ├── welcome_page.dart         # 啟動頁（未登入 → login，已登入 → menu）
│   ├── login_page.dart           # 登入畫面
│   ├── menu_page.dart            # 主選單（4 格功能入口）
│   ├── call_page.dart            # 通話偵測主畫面（FCM 即時逐字稿 + 風險分數）
│   ├── call_summary_page.dart    # 通話結束摘要（風險分數、走勢圖、可疑句子）
│   ├── contacts_page.dart        # 聯絡人清單（撥出呼叫）
│   ├── conversations_page.dart   # 通話記錄列表 + 摘要 + 逐字稿
│   ├── butler_chat_page.dart     # AI Butler 對話（UI Demo）
│   ├── food_recognition_page.dart# 食物辨識（WebView Demo）
│   ├── in_app_camera_page.dart   # App 內相機
│   ├── monitor_page.dart         # 開發用 WebSocket 監控頁
│   ├── stats_page.dart           # 測試統計頁
│   └── webview_page.dart         # 通用 WebView
├── providers/
│   ├── auth_provider.dart        # 登入狀態、token、uuid
│   └── call_provider.dart        # FCM 事件處理、fcmTranscript、通話計時
├── services/
│   ├── api_service.dart          # REST API（login、conversations、call-end）
│   ├── fcm_service.dart          # FCM token 訂閱、broadcast stream
│   ├── conversation_service.dart # getConversations / getMessages
│   ├── audio_service.dart        # 音訊錄製與播放（flutter_sound）
│   ├── alert_service.dart        # 系統警告音效
│   ├── web_speech_service.dart   # Web 版語音辨識（Chrome 開發用）
│   ├── kebbi_service.dart        # Kebbi 機器人動作控制
│   ├── secure_storage.dart       # flutter_secure_storage（token 儲存）
│   └── websocket_service.dart    # WebSocket（保留給 MonitorPage 偵錯用）
└── widgets/
    └── auth_guard.dart           # 登入狀態守衛
```

---

## 主要頁面說明

### CallPage（通話偵測）
- FCM `incoming_call` → 導向此頁，AI 代接中（`_userAnswered = false`）
- FCM `call_new_message` → 即時顯示逐字稿氣泡
- 按「Answer Call」→ `_userAnswered = true`，轉為監聽模式
- 按「Hang Up」→ `POST /api/fraud/call-end` → 導向 CallSummaryPage

### CallSummaryPage（通話摘要）
- 顯示：通話時長、方向（Incoming/Outgoing）、接聽方式（User/AI）
- 顯示：峰值風險分數、走勢圖、可疑句子
- 「View Transcript」按鈕 → ConversationDetailPage

### ConversationsPage（通話記錄）
- 列表：`GET /api/fraud/conversations`
- 點一筆 → ConversationSummaryPage（讀 SharedPreferences 取時長）
- 「View Transcript」→ ConversationDetailPage（`GET .../messages`）

### ContactsPage（聯絡人）
- 本地聯絡人清單，發起撥出呼叫
- 信任標記（Trusted / Trust 等級）

---

## 功能串接狀態

| 功能 | 狀態 | 說明 |
|---|---|---|
| 登入 / token | ✅ 完成 | `POST /api/auth/login` + SecureStorage |
| FCM 訂閱 | ✅ 完成 | `POST /api/push/subscribe/kebbi` |
| 來電通知 | ✅ 完成 | FCM `incoming_call` |
| 即時逐字稿 | ✅ 完成 | FCM `call_new_message/update/delete` |
| 通話結束信號 | ✅ 完成 | `POST /api/fraud/call-end` |
| 通話記錄列表 | ✅ 完成 | `GET /api/fraud/conversations` |
| 逐字稿查看 | ✅ 完成 | `GET /api/fraud/conversations/{id}/messages` |
| 風險分數 | 🟡 部分 | 前端佔位顯示；需後端儲存 finalScore / scoreHistory |
| AI Butler 對話 | ❌ Demo | UI 模擬，未串 `/api/chat/` |
| 食物辨識 | ❌ Demo | 開啟外部 WebView，未串 API |
| FCM token retry | 🟡 已知問題 | 啟動時 DNS 未就緒可能 timeout；手動用 Bruno 補訂 |

---

## Mock 開關

```dart
// lib/config/api_config.dart
static const bool mockCallUi = false;
// true  → Welcome 頁可直接預覽完整通話流程（不需後端）
// false → 真實 FCM 模式（正式使用）
```

---

## 設定

| 項目 | 值 |
|---|---|
| Backend base URL | `https://vision.futuremedialab.tw:1688` |
| App package | `tw.futuremedialab.frauddetect` |
| FCM 設定檔 | `android/app/google-services.json` |
| Target platform | Android（Kebbi 機器人） |

---

## 本機開發

### Android 模擬器
```bash
flutter run -d <emulator-id>
```

常見問題：
- DNS 無法解析：`adb shell setprop net.dns1 8.8.8.8`
- FCM token 訂閱失敗：手動用 Bruno 打 `POST /api/push/subscribe/kebbi`
- 觸發測試來電：Bruno `POST /api/fraud/incoming-call`

### Chrome（UI 快速開發，不支援 FCM）
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

### 規格文件
- `docs/FRAUD_CALL_SPEC.md`：通話偵測 UI 規格
- `docs/BACKEND_INTEGRATION.md`：API 串接規格與進度

---

## Assets

| 路徑 | 用途 |
|---|---|
| `assets/image/logo.png` | App Logo |
| `assets/filtered_terms.json` | 詐騙關鍵字清單 |
| `assets/mock_call.json` | Mock 通話資料（mockCallUi = true 時用） |
| `assets/sounds/Fraud.mp3` | 高風險警告音 |
| `assets/sounds/Not_Fraud.mp3` | 安全提示音 |
