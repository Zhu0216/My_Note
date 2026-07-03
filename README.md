# My Note

All-in-one 個人管理筆記本，使用 Flutter 開發，目標支援 Android 手機與 Flutter Web。第一版以本機功能完整為主，後續逐步接上 Firebase Auth、Cloud Firestore、Storage、FCM、Hosting。

## 目前功能

- Home 首頁：月結算、今日行程、即將到來、待辦事項、最近筆記與快速新增。
- Notes 筆記：資料夾、標籤、搜尋、排序、檢視模式、批量編輯、垃圾桶、四種模板入口。
- 筆記編輯器：Rich text toolbar、待辦核取方塊、圖片插入/選取/裁切/縮放/框線/對齊/移動、附件插入與下載。
- Calendar 行程：月曆、點擊日期行程、時間排序、新增/編輯/刪除。
- Finance 記帳：存餘、收入、支出、帳戶、分類統計、預算、訂閱管理。
- Settings 設定：Firebase 狀態與未來雲端同步入口。

## 本次更新

- 修正筆記圖片點擊：點圖片本體會立即選取圖片並切換圖片 toolbar，不會先選到 paragraph 或插入行。
- 修正圖片遮擋輸入問題：圖片 block 回報實際 visual rect，點擊圖片區域會阻止文字區取得 focus，避免出現 caret 或鍵盤。
- 加入 debug 驗證 log：`IMAGE_VISUAL_TAP ... nextParagraph.y>=...`，用來證明圖片 block 佔用真實 layout 高度。
- 移除未實際使用的 `appflowy_editor` 依賴，保留內部 `templateData.appflowy` JSON mirror 作為未來相容資料格式。

## 驗證

- `dart analyze lib/main.dart`：通過。
- `flutter build apk --debug --no-pub`：通過。
- X510 實機安裝：通過。
- X510 圖片點擊測試：點擊圖片中心只出現 `IMAGE_VISUAL_TAP`，未出現 `PARAGRAPH_TAP` / `CARET_CHANGED`，且鍵盤未跳出。
- `flutter build web --debug --no-wasm-dry-run --no-pub`：通過。
- Web 本機檢查：`http://127.0.0.1:8080/` 回應 `200`。

## Firebase 規劃

- Firebase Auth：使用者登入。
- Cloud Firestore：筆記、行程、訂閱、記帳資料。
- Firebase Storage：附件與圖片。
- Cloud Functions：背景任務與 Google Calendar 同步。
- Firebase Hosting：Flutter Web 部署。
- FCM：手機推播通知。

## 開發指令

PowerShell：

```powershell
.\scripts\flutter_project.ps1 pub get
.\scripts\flutter_project.ps1 analyze
.\scripts\flutter_project.ps1 build web --debug --no-wasm-dry-run
.\scripts\flutter_project.ps1 build apk --debug
```

CMD：

```cmd
scripts\flutter_project.cmd pub get
scripts\flutter_project.cmd analyze
scripts\flutter_project.cmd build apk --debug
```

安裝到 Android 測試機：

```powershell
.\scripts\flutter_project.ps1 install -d <device-id>
```

## 維護規則

- 每次成功修改後同步更新 README。
- 成功版本同步更新 `.success.bak` 備份。
- 不提交 build output、cache、暫存測試截圖/XML/log。
- Firebase 金鑰與環境設定不得提交到 repo。
