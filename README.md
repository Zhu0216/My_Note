# My Note

All-in-one 個人管理筆記本，使用 Flutter 建置，目標支援 Android 手機、平板與 Flutter Web。第一版以本地端功能完善為主，Firebase 已保留整合架構，後續可接 Auth、Firestore、Storage、FCM、Hosting。

## 目前功能

- Home 首頁：今日/近期資訊、即將到來、月結算、最近筆記、待辦事項、首頁區塊順序與樣式調整。
- Notes 筆記：資料夾與巢狀資料夾、未分類、垃圾桶、置頂分區、搜尋/篩選、檢視模式、排序、四種模板入口、一般筆記 Rich Text 工具列編輯器、左滑刪除。
- Calendar 行程：月曆/週曆/清單、當日行程、新增/編輯行程、日期與時間選擇、提醒設定、左滑刪除。
- Finance 記帳：存餘帳戶、收入/支出、帳戶選擇、日期與時間、月預算、支出分類、收入帳戶長條圖、支出/收入時間軸、訂閱管理。
- Todo 待辦：多行 block 編輯、期限、提醒時間、完成項目、拖曳排序。
- Settings 設定：Firebase 與上架規劃資訊。
- UI：下方導覽列套用 Nav Bars Template 6 風格，並保留未來切換導覽列風格的程式結構；存餘帳戶新增/編輯維持原本彈窗樣式。

## Firebase 規劃

- Firebase Auth：使用者登入。
- Cloud Firestore：筆記、行程、訂閱、記帳與設定同步。
- Firebase Storage：筆記附件與圖片。
- Cloud Functions：背景任務與未來 Google Calendar 同步。
- Firebase Hosting：Flutter Web 部署。
- FCM：手機推播通知。

## 本機開發

建議使用專案提供的 wrapper，固定 Pub cache 在 `D:\Flutter_Project\my_note\.dart_localappdata\Pub\Cache`，避免 Windows 上 Android plugin 來源在 C 槽、build 目錄在 D 槽時發生 Gradle roots 錯誤。

```powershell
.\scripts\flutter_project.ps1 pub get
.\scripts\flutter_project.ps1 analyze
.\scripts\flutter_project.ps1 build web --debug --no-wasm-dry-run
.\scripts\flutter_project.ps1 build apk --debug
```

CMD 也可使用：

```cmd
scripts\flutter_project.cmd pub get
scripts\flutter_project.cmd analyze
scripts\flutter_project.cmd build apk --debug
```

安裝到已連線 Android 裝置：

```powershell
.\scripts\flutter_project.ps1 install -d <device-id>
```

## 專案維護

- 修改功能時同步更新本 README。
- FlutterFlow template 套用紀錄維護於 `docs/flutterflow_templates.md`，D 槽探測/整理索引同步在 `D:\Flutter_Project\flutterflow_project_probe\my_note_templates.md`。
- 不提交本機 cache、build output、測試截圖、log 與 Codex 工作檔。
- Firebase 實際憑證與正式環境設定不要直接提交到公開 repo。
