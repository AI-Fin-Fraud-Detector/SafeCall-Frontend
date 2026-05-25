# Git 工作流程與 APK 發佈

## Repo 架構

```
SafeCall (共用 repo)
└── frontend/      ← submodule，實體是 SafeCall-Frontend repo
    在這裡 git push = 推到 SafeCall-Frontend

SafeCall-Frontend (獨立 repo)
└── 每次 push 到 main → GitHub Actions 自動 build APK → Releases 頁面
```

`frontend/` 資料夾本身就是 SafeCall-Frontend repo。
在 `frontend/` 裡執行的 git 指令對 SafeCall-Frontend 操作。
在 SafeCall 根目錄執行的 git 指令對 SafeCall 操作。

---

## 初次設定（只需做一次）

```bash
# 1. Clone SafeCall
git clone git@github.com:AI-Fin-Fraud-Detector/SafeCall.git
cd SafeCall

# 2. 初始化 submodule（把 SafeCall-Frontend 內容拉進來）
git submodule update --init --recursive

# 3. 進到 frontend，切到 main branch
cd frontend
git switch main

# 4. 改成 SSH（submodule 預設用 HTTPS，改成 SSH 比較方便）
git remote set-url origin git@github.com:AI-Fin-Fraud-Detector/SafeCall-Frontend.git

# 5. Pull 最新內容
git pull
```

### 本機測試必要步驟
`google-services.json` 已從 git 移除（不追蹤），需要手動放置：
```
frontend/android/app/google-services.json
```
沒有這個檔案，本機無法 build 或測試 FCM 功能。檔案向團隊索取。

---

## 日常開發流程

```
frontend/ 裡開發
    ↓
git push → SafeCall-Frontend → GitHub Actions build APK
    ↓
回到 SafeCall 根目錄，更新 submodule 指標
    ↓
git push → SafeCall develop
```

### 詳細指令

```bash
# ── 在 frontend/ 裡（對 SafeCall-Frontend 操作）──

cd frontend
git add .
git commit -m "feat: 描述改了什麼"
git push origin main          # 推到 SafeCall-Frontend，觸發 APK build

# ── 回到 SafeCall 根目錄（對 SafeCall 操作）──

cd ..
git add frontend              # 更新 submodule 指標（記錄 frontend 現在指向哪個 commit）
git commit -m "update frontend"
git push origin develop       # 推到 SafeCall 的 develop branch
```

---

## Pull 最新內容（協作者有更新時）

```bash
# 在 SafeCall 根目錄
git pull origin develop

# 更新 submodule 到最新
git submodule update --recursive
```

---

## APK 下載

GitHub Actions build 完成後，APK 出現在：
```
https://github.com/AI-Fin-Fraud-Detector/SafeCall-Frontend/releases/tag/latest
```

協作者下載 `app-debug.apk` 安裝到 Android 裝置即可。

安裝到模擬器：
```bash
adb install app-debug.apk
```

---

## Branch 策略

| Repo | Branch | 用途 |
|---|---|---|
| SafeCall-Frontend | `main` | 唯一 branch，每次 push 觸發 APK build |
| SafeCall | `develop` | 日常開發，功能完成後 PR merge 到 main |
| SafeCall | `main` | 穩定版，只透過 PR 合併 |
