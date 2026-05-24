# 詐騙偵測通話功能 前端規格文件

> 最後更新：2026-05-24 | 版本：v1.2

---

## 1. 功能概述

**核心概念：AI 守門員**

來電時 AI 先代為應對，使用者在旁觀察，隨時可接手或掛斷。系統即時顯示風險分數與逐字稿，讓長者光看顏色和數字就能做決定。

| 流程 | AI 角色 | 核心畫面 |
|---|---|---|
| 接電話 | 守門員（主動應對） | 風險分數 + 逐字稿 + 接聽/掛掉 |
| 打電話 | 旁觀者（靜默監聽） | 風險分數 + 逐字稿 + 掛掉 |

---

## 2. 頁面流程

### 接電話（真實模式）

```
FCM incoming_call
    ↓
main.dart onIncomingCall → pushAndRemoveUntil(CallPage)
    ↓
CallPage (mode: incoming)
  ├── 系統代接中（userAnswered = false）
  ├── 按「我來接聽」→ userAnswered = true
  └── 按「掛掉電話」→ _onHangup()
        ↓ 存通話時長到 SharedPreferences
        ↓
    CallSummaryPage（pushReplacement）
        ↓ 按「返回首頁」
    popUntil(isFirst)
```

### 通話記錄

```
Menu → 通話紀錄
    ↓
ConversationsPage（GET /api/fraud/conversations）
    ↓ 點一筆
ConversationSummaryPage（讀 SharedPreferences 取通話時長）
    ↓ 點「查看逐字稿」
ConversationDetailPage（GET /api/fraud/conversations/{id}/messages）
```

---

## 3. CallPage 規格

### 系統代接中（`_userAnswered = false`）
```
[● Fraud Detection Active]  [● AI Answering]
Unknown / 0912-345-678                   00:05
[ Analyzing call... / 風險分數區塊 ]
[ 逐字稿氣泡 ]
[ Answer Call ]        [ Hang Up ]
         ⊕ Speaker On/Off
```

### 接聽後監聽模式（`_userAnswered = true`）
```
[● Fraud Detection Active]  [● Monitoring Active]
In Call                                  00:34
[ 風險分數區塊 ]
[ 逐字稿氣泡 ]
[ Continue ]        [ Hang Up ]
```

### 高風險（score ≥ 80）
```
⚠️ High-risk fraud detected — Strongly recommend hanging up now
[ Still Answer (opacity 0.4) ]   [ Hang Up Now (紅粗大) ]
```

### 重要 State

| 變數 | 說明 |
|---|---|
| `_isMock` | `ApiConfig.mockCallUi`，目前 false |
| `_userAnswered` | 使用者是否親自接聽 |
| `_isHangingUp` | 防止 hasActiveCall→false 時 auto-pop 彈掉 CallSummaryPage |
| `_durationSecs` | 前端計時器秒數，掛斷時存 SharedPreferences |
| `_maxScore` | 通話中最高風險分數，傳給 CallSummaryPage |
| `_scoreHistory` | `List<({int seconds, int score})>`，傳給走勢圖 |

---

## 4. CallSummaryPage 規格

### 參數

| 參數 | 型別 | 說明 |
|---|---|---|
| `callerDisplay` | String | 顯示名稱 |
| `callerNumber` | String | 電話號碼 |
| `durationSecs` | int? | 通話時長（null = 不顯示） |
| `finalScore` | int? | 最高風險分數（null = 顯示「⚠ 待串接」佔位） |
| `scoreHistory` | List<...> | 時間序列走勢（< 2 筆不顯示圖表） |
| `transcript` | List\<TranscriptEntry\> | 逐字稿（空 = 不顯示可疑句子） |
| `wasIncoming` | bool | 來電 / 撥出 |
| `userAnswered` | bool | 是否親自接聽 |
| `pageTitle` | String | AppBar 標題，預設「通話結束」 |
| `onViewTranscript` | VoidCallback? | 設定後顯示「查看逐字稿」按鈕 |

### 呈現邏輯

- `finalScore == null` → 風險摘要卡顯示灰色「⚠ 待串接」
- `scoreHistory.length < 2` → 不顯示走勢圖
- 無高風險 transcript → 不顯示可疑句子區塊
- `finalScore >= 60` → 顯示「封鎖 / 檢舉」行動區塊

---

## 5. 風險分數配色系統

| 分數 | 狀態 | CallPage（深色背景）| CallSummaryPage（淺色背景）|
|---|---|---|---|
| 0–39 | 安全 | fg: `#66BB6A` bg: `#1A3A2A` | fg: `#1B5E20` bg: `#E8F5E9` |
| 40–59 | 注意 | fg: `#FFCA28` bg: `#3A2E0A` | fg: `#F57F17` bg: `#FFF8E1` |
| 60–79 | 警告 | fg: `#FF7043` bg: `#3A1E0A` | fg: `#BF360C` bg: `#FBE9E7` |
| 80–100 | 危險 | fg: `#EF5350` bg: `#3A0A0A` | fg: `#B71C1C` bg: `#FFEBEE` |

---

## 6. UI 設計原則

**針對長者：**
- 大字體：風險分數 fontSize ≥ 56，按鈕文字 ≥ 16
- 顏色傳達狀態：整塊背景色隨風險等級變化
- 高風險按鈕不對等：「立刻掛掉」加大加粗，「仍要接聽」opacity 0.4
- 不強制：高風險仍保留接聽選項

**設計語言（共用）：**
- 白色背景 `Colors.white`
- 圓角卡片 `borderRadius: 16`
- AppBar：白底、無陰影、`arrow_back_ios_new_rounded`、標題置中 w700
- 頭像：50×50 圓形，teal 系（`#439293`）

---

## 7. 資料模型（欄位說明）

### TranscriptEntry
`speaker`（caller / ai）、`text`、`time`、`isHighRisk`（整句標紅）

### Conversation
`id`（對應 API 的 `conversation_id`）、`title`、`metadata`（`callerPhoneNumber`、`callerName`）、`createdAt`、`updatedAt`

### ConversationMessage
`id`、`role`（"user" = 來電方 / "assistant" = AI）、`content`、`metadata`、`createdAt`

---

## 8. Mock 資料

```dart
// lib/config/api_config.dart
static const bool mockCallUi = false;  // true = Welcome 頁預覽模式
```

`mockCallUi = true` 時，`CallPage._launchMock()` 播放內建劇本（最終分數 87，危險），讓 Welcome 頁可以跑完整流程預覽。
