# My Note

All-in-one 個人管理筆記本，使用 Flutter 開發，目標支援 Android 手機 / 平板與 Flutter Web。第一階段以地端功能穩定為主，Firebase 已保留接軌設定，後續可逐步加入 Auth、Firestore、Storage、FCM 與 Hosting。

## 目前功能

- Home 首頁：月結算、今日行程、即將到來、最近筆記與快速新增入口。
- Notes 筆記：資料夾、未分類、垃圾桶、置頂、搜尋、排序、檢視模式、批量編輯與模板入口。
- Rich Note Editor：文字格式、字級滾輪、字型選擇、清單、待辦核取方塊、圖片、附件、背景設定、插入待辦與匯出入口。
- Calendar 行程：依日期查看行程、新增 / 編輯 / 刪除與提醒相關欄位。
- Finance 記帳：存餘、本月收入、本月支出、支出 / 收入統計、帳戶與近期紀錄。
- Settings 設定：Firebase 規劃與本機設定入口。

## 筆記字型

- `裝置(XX體)` 會跟隨 Samsung 裝置目前套用的系統字型。
- X510 上已驗證可偵測 Samsung FlipFont 字型套件，並列出已安裝字體，例如 `少女體`、`Samsung One`、`Roboto`、`Foundation`。
- 選擇 `裝置(XX體)` 會跟著系統切換；選擇單一字體名稱則固定使用該字體。
- 字型按鈕已改成依文字寬度自適應，會將 toolbar 後方項目往右推，超出畫面時維持橫向捲動與左右箭頭。

## Firebase 狀態

- Firebase CLI 已改用 `D:\Flutter_Project\firebase-cli`。
- 專案已有 Firebase 設定檔接點，後續可加入：
  - Firebase Auth：使用者登入
  - Cloud Firestore：筆記、行程、訂閱、記帳資料
  - Firebase Storage：附件與圖片
  - Cloud Functions：背景任務與 Google Calendar 同步
  - Firebase Hosting：Flutter Web 部署
  - FCM：手機推播通知

## 開發與測試

PowerShell:

```powershell
.\scripts\flutter_project.ps1 pub get
.\scripts\flutter_project.ps1 analyze
.\scripts\flutter_project.ps1 build web --debug --no-wasm-dry-run
.\scripts\flutter_project.ps1 build apk --debug
```

CMD:

```cmd
scripts\flutter_project.cmd pub get
scripts\flutter_project.cmd analyze
scripts\flutter_project.cmd build apk --debug
```

常用直接指令：

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
flutter build web --no-pub
```

## 已驗證

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- `flutter build apk --debug --no-pub`
- `flutter build web --no-pub`
- Samsung X510 安裝與截圖確認筆記裝置字型功能

## 已知警告

- Android build 仍會出現 Kotlin Gradle Plugin 未來相容性警告，來源包含 `file_picker`、`firebase_storage`、`share_plus` 等套件。現階段不影響 debug APK 建置與 app 功能。
- Web build 會出現 Flutter wasm dry run 提示，現階段不影響一般 Flutter Web build。
