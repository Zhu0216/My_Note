# My Note

My Note 是一款 All-in-one 個人管理筆記本，目標是在手機、平板與網頁上整合筆記、行程、記帳、訂閱與待辦事項。第一版以本機端功能完整與操作體驗穩定為主，並保留 Firebase 雲端同步、登入、附件儲存與推播通知的架構。

## 功能

### 首頁 Home

- 顯示今日行程、即將到來、本月收支、最近筆記與待辦事項。
- 支援首頁區塊排序、顯示 / 隱藏、條列 / 方塊樣式切換與摺疊顯示。
- 右下角 FAB 可快速新增筆記、待辦、記帳、訂閱費用與行程。

### 筆記 Notes

- 支援一般筆記、計劃、心智圖、人生試算表等模板入口。
- 支援資料夾、巢狀資料夾、未分類、所有筆記與垃圾桶。
- 支援搜尋、排序、檢視模式、模板篩選、批量編輯、移動、重新命名與刪除。
- 支援置頂筆記，置頂筆記會固定顯示在一般筆記上方。
- 垃圾桶提供檢視、復原、刪除與清空功能。

### Rich Note Editor

- 支援文字格式：字級、字型、粗體、斜體、底線、刪除線、上下標、行距、引用、程式碼、編號清單、項目清單與待辦清單。
- 支援 Samsung 裝置字型偵測，字型選單可顯示 `裝置(目前字體)` 與已安裝裝置字型，例如 `少女體`、`Samsung One`、`Roboto`、`Foundation`。
- 支援插入圖片，圖片可選取、縮放、移動、對齊、裁切、加框線與刪除。
- 支援插入附件與待辦事項。
- 支援背景顏色與背景圖片設定。
- 支援返回自動儲存與刪除確認。

### 行程 Calendar

- 支援月曆、週曆與當日行程清單。
- 點擊日期後顯示該日行程，新增行程會預設使用目前選取日期與時間。
- 支援新增、編輯、刪除與提醒設定。
- Google Calendar 同步保留為後續功能。

### 記帳 Finance

- 支援收入、支出、帳戶、分類與時間紀錄。
- 支援存餘帳戶，顯示帳戶名稱與金額，可新增、編輯與刪除帳戶。
- 支援本月收入、本月支出、存餘金額、支出分類與收入分類統計。
- 支援預算提醒、圓餅 / 環狀圖與日期時間軸紀錄。
- 訂閱管理整合於記帳功能，可記錄訂閱名稱、金額、付款週期、下次付款日、付款方式、分類、提醒天數與啟用狀態。

### 待辦事項

- 支援待辦、完成狀態、期限、提醒與提醒時間。
- 首頁待辦可直接編輯文字，長按可設定期限、提醒、完成或刪除。
- 已完成待辦可集中顯示，並保留完成時間。

### 設定 Settings

- 放置 Firebase、同步、通知與未來個人化設定入口。
- 後續可加入導覽列風格、主題與資料同步設定。

## 資料與 Firebase 使用情況

### 目前資料狀態

- 第一版目前以本機資料為主，適合離線開發、功能驗證與裝置測試。
- 本機資料包含筆記、資料夾、行程、待辦、記帳紀錄、訂閱項目、存餘帳戶與首頁顯示設定。

### Firebase 規劃

- Firebase Auth：儲存使用者登入狀態，讓不同裝置可使用同一帳號同步資料。
- Cloud Firestore：儲存筆記、資料夾、行程、待辦、訂閱、記帳紀錄、帳戶、預算與首頁設定。
- Firebase Storage：儲存筆記圖片、附件、背景圖片與匯出檔案。
- Firebase Cloud Messaging：提供行程提醒、訂閱扣款提醒、待辦提醒與預算提醒推播。
- Cloud Functions：處理背景任務、定期提醒、資料清理與未來 Google Calendar 同步。
- Firebase Hosting：部署 Flutter Web 版本。

## 開發工具

- Codex
- Visual Studio Code
- Flutter
- Dart
- Android Studio
- Android SDK / ADB
- Firebase CLI
- Git
- GitHub

## 使用套件

- `cupertino_icons`：pub.dev
- `shared_preferences`：pub.dev
- `firebase_core`：pub.dev
- `firebase_auth`：pub.dev
- `cloud_firestore`：pub.dev
- `firebase_storage`：pub.dev
- `firebase_messaging`：pub.dev
- `file_picker`：pub.dev
- `image_cropper`：pub.dev
- `pdf`：pub.dev
- `printing`：pub.dev
- `share_plus`：pub.dev
- `shadcn_ui`：pub.dev
- `flutter_box_transform`：pub.dev
- `flutter_lints`：pub.dev

## UI / Template 參考

- FlutterFlow shadcn/ui Library
- FlutterFlow Rich Text template
- FlutterFlow Nav Bars template
