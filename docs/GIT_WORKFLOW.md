# Git 工作流程與 APK 發佈

## Repo 架構

```
SafeCall (共用 repo)               SafeCall-Frontend (獨立 repo)
└── frontend/  ←── 原始碼 ───▶    └── 內容與 frontend/ 相同
    協作者在這裡看程式碼                ↓ GitHub Actions
                                    build APK
                                        ↓
                                    Releases 頁面
                                        ↓
                                    協作者下載 APK 安裝到裝置
```

兩個 repo 的 `frontend/` 內容完全相同，透過 `git subtree` 同步。

---

## 本機 Remote 設定（只需做一次）

```bash
# 確認目前的 remotes
git remote -v

# 如果沒有 frontend-origin，加上去
git remote add frontend-origin git@github.com:AI-Fin-Fraud-Detector/SafeCall-Frontend.git
```

---

## 日常開發流程

### 1. 開始前先 pull 最新內容
```bash
git pull origin develop
```

### 2. 改完程式後 commit
```bash
git add frontend/
git commit -m "feat: 簡短描述改了什麼"
```

### 3. 推到 SafeCall（原始碼，讓協作者看）
```bash
git push origin develop
```

### 4. 推到 SafeCall-Frontend（觸發 APK build）
```bash
git subtree push --prefix=frontend frontend-origin main
```

> `--prefix=frontend` 代表只推 `frontend/` 資料夾的內容到新 repo（不會帶到 backend/、edge/ 等）

---

## GitHub Actions 說明

檔案位置：`frontend/.github/workflows/build.yml`

每次 push 到 `SafeCall-Frontend` 的 `main` branch 時，GitHub 會自動：

| 步驟 | 說明 |
|---|---|
| `actions/checkout` | 把程式碼下載到雲端機器 |
| `actions/setup-java` | 安裝 Java 17（Android build 需要） |
| `subosito/flutter-action` | 安裝 Flutter stable |
| `flutter pub get` | 安裝 Dart 套件（相當於 npm install） |
| `flutter build apk --debug` | 編譯產生 APK |
| `softprops/action-gh-release` | 上傳 APK 到 Releases 頁面 |

Build 結果可在 `SafeCall-Frontend` → **Actions** 頁面查看。
APK 下載位置：`SafeCall-Frontend` → **Releases** → `Latest Build` → `app-debug.apk`

---

## Branch 策略

| Branch | 用途 |
|---|---|
| `develop` | 日常開發，所有改動先推這裡 |
| `main` | 穩定版，透過 PR 從 develop 合併進來 |

> SafeCall-Frontend 只有 `main`，沒有 develop，因為那個 repo 只負責 build APK。

---

## 分支切換與確認

```bash
# 確認目前在哪個 branch
git branch --show-current

# 切換到 develop
git checkout develop

# 查看所有 remote
git remote -v
```
