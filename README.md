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
- 插入圖片後會保留圖片下方空白輸入段落，避免圖片在文末時無法繼續輸入。

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

- `dart analyze lib/main.dart`：通過，No issues found。
- `flutter build web --no-pub`：通過，輸出 `build\web`。
- `flutter build apk --debug --no-pub`：通過，輸出 `build\app\outputs\flutter-apk\app-debug.apk`。
- X510 安裝：成功安裝 `com.allinone.mynote` debug APK。
- X510 待辦新增：輸入標題後取消與確認皆回到主頁，未再出現 `_dependents.isEmpty` Flutter assertion。
- X510 筆記左滑：筆記項目可左滑顯示固定寬度紅底白色垃圾桶；首頁最近筆記已接入同一刪除元件。
- X510 圖片選取：點擊圖片本體後立即顯示圖片 toolbar 與八個控制點。
- X510 圖片移動：移動模式開啟後可拖曳圖片；未開啟或鎖定時不可拖移。
- X510 圖片鎖定：點鎖頭後 toolbar 只剩鎖頭，點圖片外空白會退出圖片選取並回到文字 toolbar。
- X510 圖片版面：圖片上下保留文字輸入段落，未出現圖片覆蓋文字輸入行或紅畫面。
- Web：`http://127.0.0.1:8080/` 已啟動並開啟瀏覽器檢視。

## 已知警告

- Android build 仍顯示 Kotlin Gradle Plugin 警告，來源為 `file_picker`、`firebase_storage`、`share_plus` 等套件尚未完全遷移到 Built-in Kotlin。此次不影響 debug APK 建置與安裝。
- Web build 顯示 wasm dry run 警告，來源為第三方 web 套件的 JS interop runtime check。一般 Flutter Web build 可正常產出，若未來要啟用 wasm 需追蹤套件更新。

## 維護流程

- 每次成功修改後更新 README。
- 每次成功修改後建立/更新成功備份。
- 不提交 build output、cache、測試截圖、XML 或 log 暫存檔。
