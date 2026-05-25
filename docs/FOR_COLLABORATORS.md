# Frontend — 協作者說明

## Repo 架構

| Repo | 用途 |
|---|---|
| `AI-Fin-Fraud-Detector/SafeCall` | 共用主 repo，frontend/ 是 SafeCall-Frontend 的 submodule |
| `AI-Fin-Fraud-Detector/SafeCall-Frontend` | Frontend 獨立 repo，每次更新自動 build APK |

---

## 想安裝最新 APK 測試

1. 去 `SafeCall-Frontend` → **Releases**
2. 點 `Latest Build`
3. 下載 `app-debug.apk`
4. 安裝到 Android 裝置或模擬器

APK 下載連結：
```
https://github.com/AI-Fin-Fraud-Detector/SafeCall-Frontend/releases/tag/latest
```

安裝到模擬器（指令）：
```bash
adb install app-debug.apk
```

---

## 想看 Frontend 原始碼

去 `SafeCall-Frontend` repo 或 `SafeCall/frontend/` 資料夾，兩個內容相同。
