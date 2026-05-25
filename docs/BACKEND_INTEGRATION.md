# 前端後端串接規格與進度追蹤

> 最後更新：2026-05-26

---

## 架構

```
Samsung Galaxy (SIM 卡)  ──來電──▶  edge device (Python)
                                        │ gRPC :60015
                                        ▼
                                   backend server
                                   ├── auth    (登入/token)
                                   ├── fraud   (AI 偵測、對話儲存)
                                   └── push    (FCM 推播)
                                        │ FCM
                                        ▼
                              Kebbi / 模擬器 (Flutter App)
```

---

## API 對照表

| 功能 | 端點 | 狀態 |
|---|---|---|
| 登入 | `POST /api/auth/login` JSON `{email, password}` | ✅ |
| 用戶資料 | `GET /api/auth/status` | ✅ |
| FCM token 訂閱 | `POST /api/push/subscribe/kebbi` | ✅ |
| 來電通知 | FCM `type: "incoming_call"` | ✅ |
| 即時逐字稿（新增） | FCM `type: "call_new_message"` | ✅ |
| 逐字稿更新 | FCM `type: "call_update_message"` | ✅ |
| 逐字稿刪除 | FCM `type: "call_delete_message"` | ✅ |
| SSCI 風險更新 | FCM `type: "ssci_update"` | ✅ |
| 詐騙警告 | FCM `type: "fraud_alert"` | ✅ |
| 可安全接聽 | FCM `type: "safe_to_answer"` | ✅ |
| 使用者接聽通知 | `POST /api/fraud/answer-call` body: 空 | ✅ |
| 對話列表 | `GET /api/fraud/conversations` | ✅ |
| 對話訊息 | `GET /api/fraud/conversations/{id}/messages` | ✅ |
| 通話結束（FCM flow） | `POST /api/fraud/call-end` body: 空 | ✅ |

---

## FCM Payload 格式

### incoming_call
```json
{
  "type": "incoming_call",
  "detail": {
    "phone_number": "0912345678",
    "caller_name": null,
    "conversation_id": "550e8400-..."
  }
}
```

### call_new_message
```json
{
  "type": "call_new_message",
  "conversation_id": "550e8400-...",
  "message": {
    "id": "660e8400-...",
    "role": "user",
    "content": "您好，我是台灣大哥大客服。",
    "metadata": null
  }
}
```
- `role: "user"` = 來電方（STT 轉錄）
- `role: "assistant"` = AI 回應

### call_update_message / call_delete_message
- update：同 `call_new_message` 格式，用 `message.id` 找舊的並更新 content
- delete：`{ "type": "call_delete_message", "message": { "id": "..." } }`

### ssci_update
```json
{
  "type": "ssci_update",
  "conversation_id": "550e8400-...",
  "ssci": {
    "trigger_index": 1,
    "scam_probability": 0.15,
    "confidence": 0.85,
    "evidence": 0.67,
    "agreement": 0.89,
    "stability": 0.98
  }
}
```

### fraud_alert
```json
{
  "type": "fraud_alert",
  "conversation_id": "550e8400-...",
  "scam_probability": 0.75
}
```

### safe_to_answer
```json
{
  "type": "safe_to_answer",
  "conversation_id": "550e8400-...",
  "scam_probability": 0.20
}
```

---

## 第一階段：已完成

Step 1–9（google-services.json、api_config、登入、FCM Service、CallProvider、CallPage 真實模式、CallSummaryPage、ConversationService、ConversationsPage）全部完成。

---

## 第二階段：串接進度

| 項目 | 說明 | 優先度 |
|---|---|---|
| **Edge gRPC 串接** | port 60015 已開通；逐字稿完整流程已驗證 | ✅ 完成 |
| **風險分數串接** | 通話中分數由 FCM `ssci_update` 即時更新；掛斷時存 SharedPreferences（`call_score_{id}`）；歷史頁已能讀取。後端若未來儲存分數可直接串 API | ✅ 完成 |
| **通話時長** | 掛斷時前端已存 SharedPreferences（`call_dur_{id}`）；歷史頁已能讀取 | ✅ 完成 |
| FCM token 自動訂閱 retry | 啟動時 DNS 未就緒導致失敗；目前 workaround 手動 Bruno | 中 |
| 聯絡人資料持久化 | shared_preferences，純前端 | 中 |
| 封鎖號碼後端串接 | 目前為 mock dialog | 低 |
| Kebbi 螢幕尺寸調整 | 實機測試後再調 | 低 |

---

## 後端目前儲存的資料（重要）

`conversation.metadata` 只有 `{caller_phone_number, caller_name}`。
**沒有儲存**：風險分數、分數走勢、通話時長、message.isHighRisk。
前端已在掛斷時將最高風險分數存入 SharedPreferences（`call_score_{id}`），歷史記錄頁面可讀取顯示。後端若未來新增分數欄位，可直接替換此邏輯。

---

## 測試流程（Edge 開通後）

1. `uv run python edge/main.py`（等待 `Starting microphone stream...`）
2. `flutter run -d <emulator>`
3. Bruno `POST /api/push/subscribe/kebbi`
4. Bruno `POST /api/fraud/incoming-call` → App 跳 CallPage
5. Edge 處理音訊 → FCM 推逐字稿 → CallPage 顯示
6. 掛斷 → CallSummaryPage → 通話記錄查看逐字稿
