# My Note

All-in-one 個人管理筆記本，使用 Flutter 建置，目標支援 Android 手機/平板與 Flutter Web。第一版以地端功能完整為主，Firebase 連線與部署能力已逐步接入，後續可延伸到 Google Play / Apple App Store 上線流程。

## 主要功能

- Home 首頁：月結算、今日行程、即將到來、最近筆記、待辦事項與快速新增；最近筆記支援左滑刪除。
- Notes 筆記：資料夾、標籤、搜尋、排序、檢視模式、模板篩選、置頂、垃圾桶、多選編輯。
- Rich Note Editor：文字格式、待辦核取方塊、圖片、附件、背景設定、匯出入口；圖片支援選取、移動、鎖定與解除鎖定。
- Calendar 行程：月曆、日期行程清單、新增/編輯/刪除行程、提醒欄位。
- Finance 記帳：存餘帳戶、收入、支出、分類統計、預算提醒、訂閱管理。
- Settings 設定：Firebase 狀態與未來同步/部署設定入口。

## 筆記圖片編輯

- 圖片不再使用 editor 外層浮動層，而是 document flow 中的獨立圖片 block。
- 圖片 block 會佔用真實 layout 高度，圖片下方段落會排在圖片 block 底部之後。
- 圖片點擊範圍與實際顯示範圍一致，點擊圖片本體會直接選取圖片並顯示圖片 toolbar。
- 圖片儲存 `x`、`y`、`width`、`height` 數值；移動模式開啟時才可拖移，縮放會更新尺寸。
- 縮放使用八個控制點，支援非等比例縮放。
- 對齊功能只調整水平位置；移動會從目前位置開始，不再被對齊重置。
- 垂直拖移圖片時改以文件流 block 順序調整圖片位置，避免圖片覆蓋文字或輸入行。
- 圖片可鎖定；鎖定後 toolbar 只保留鎖頭，所有移動、縮放、裁切、框線、對齊與刪除操作都會停用，點鎖頭可解除鎖定。
- 圖片外框線徑改為 toolbar 內嵌輸入列，取消與套用不再開啟系統 dialog。
- 插入圖片後會保留圖片下方可輸入段落，但會清理插入位置附近多餘的連續空白行。

## 待辦事項互動

- 點擊待辦文字可直接在列表中編輯。
- 長按待辦事項會開啟下方操作選單，可選擇編輯、刪除或完成。
- 編輯頁不會自動跳出鍵盤，點擊標題欄位後才開始輸入。
- 編輯頁以右上角叉叉取消、打勾完成，不再顯示底部儲存/取消按鈕。
- 完成、取消與刪除會分別顯示 `完成待辦`、`取消編輯`、`刪除待辦事項` 提示。

## 筆記編輯更新

- 新筆記標題預設保持空白，只顯示 `請輸入標題` 提示；返回儲存時若仍未輸入才存成 `未命名筆記`。
- 文字段落拆分後仍使用 rich text controller 呈現粗體、斜體、底線、上下標、程式碼、引用與待辦核取方塊。
- 工具列新增字型選單，並保留字級、行距、復原/再製、圖片、附件與待辦插入。
- 工具列會同步目前段落 TextField 的游標與反白範圍：選取文字時直接套用格式，未選取時切換接下來輸入的格式。
- 工具列格式變更會立即刷新目前段落，不需重新進入頁面；下拉按鈕文字會自動省略，避免工具列 overflow。
- 筆記內容 placeholder 只會在全文空白時顯示；已有文字、圖片、附件或待辦時不再顯示。
- 點擊圖片 block 的空白處會跳到最近的文字輸入行，避免圖片區域產生游標。
- 附件預覽會依檔案類型處理：圖片直接顯示、文字檔顯示可選取文字，其他檔案提供下載後用外部 App 開啟。
- 背景設定改為顏色/圖片二選一，顏色以色票顯示，圖片由檔案選擇器選取。

## Firebase 規劃

- Firebase Auth：使用者登入。
- Cloud Firestore：筆記、行程、訂閱、記帳資料。
- Firebase Storage：附件與圖片。
- Cloud Functions：背景任務與未來 Google Calendar 同步。
- Firebase Hosting：Flutter Web 部署。
- FCM：手機推播通知。

目前 Firebase CLI 登入曾受本機 OAuth/網路環境影響，專案端已保留 Firebase 設定入口與 `firebase_options.dart` 結構，後續完成登入後可繼續初始化服務。

## 開發命令

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

安裝到 Android 裝置:

```powershell
.\scripts\flutter_project.ps1 install -d <device-id>
```

## 本次驗證

- `flutter analyze lib/main.dart`：通過，No issues found。
- `flutter test test/widget_test.dart`：通過，包含 toolbar 選取文字套用格式、無選取時 typing mode、以及 editor UI 點擊 toolbar 的測試。
- `flutter build web --no-pub`：通過，輸出 `build\web`。
- Web：`http://localhost:8080/` 回應 200，已開啟瀏覽器檢視最新 `build\web`。
- `flutter build apk --debug --no-pub`：通過，輸出 `build\app\outputs\flutter-apk\app-debug.apk`。
- X510：已安裝 debug APK 並啟動 `com.allinone.mynote`，截圖確認首頁正常顯示、無紅畫面。

## 已知警告

- Android build 仍顯示 Kotlin Gradle Plugin 警告，來源為 `file_picker`、`firebase_storage`、`share_plus` 等套件尚未完全遷移到 Built-in Kotlin。此次不影響 debug APK 建置與安裝。
- Web build 顯示 wasm dry run 警告，來源為第三方 web 套件的 JS interop runtime check。一般 Flutter Web build 可正常產出，若未來要啟用 wasm 需追蹤套件更新。

## 維護流程

- 每次成功修改後更新 README。
- 每次成功修改後建立/更新成功備份。
- 不提交 build output、cache、測試截圖、XML 或 log 暫存檔。
