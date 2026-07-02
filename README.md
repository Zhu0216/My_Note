# My Note

All-in-one 個人管理筆記本。第一版先以 Flutter 完成 Android 與 Web 的地端功能，Firebase 連線配置已預留，後續再接 Auth、Firestore、Storage、FCM、Hosting 與背景同步。

## 目前功能

- Home 首頁：今日/近期資訊、即將到來、月結算、最近筆記、待辦事項、可調整區塊順序/顯示/樣式。
- Notes 筆記：資料夾/巢狀資料夾、未分類、垃圾桶、搜尋/篩選、排序、格線/清單/簡易清單、批量編輯、置頂分區、四種模板入口。
- 一般筆記編輯：富文字 toolbar、標題/標籤直接編輯、圖片/附件/待辦插入、返回自動儲存、刪除確認。
- 圖片編輯：圖片以獨立區塊佔位，文字只能在圖片上下方；支援裁切、縮放、自由移動、左/中/右對齊、框線顏色與線寬。
- Calendar 行程：日曆點選日期、當日行程、時間排序、新增/編輯/刪除、返回自動儲存。
- Finance 記帳：收入/支出、存餘帳戶、預算輸入、金流顯示/隱藏、支出/收入圖表、近期紀錄、訂閱管理與左滑刪除。
- Todo 待辦：同一 block 多行編輯、完成/未完成分區、期限、提醒、長按管理。
- Settings 設定：Firebase 狀態與後續雲端配置入口。

## Editor 更新

- 已加入 `appflowy_editor 6.2.0` 依賴，並先以相容 JSON 方式產生 `templateData.appflowy` 文件鏡像；圖片會轉成 AppFlowy image block JSON。
- 已加入 `flutter_box_transform 0.4.7`，目前可見圖片縮放/拖移改由 TransformableBox 管理。
- `image_cropper 12.2.1` 保留，用於圖片裁切。
- 因 `appflowy_editor 6.2.0` 要求 `file_picker ^10.2.0`，`file_picker` 已從 11.x 調整為 `10.3.3`，現有 pick/save API 已改為 `FilePicker.platform`。
- 目前仍保留舊的 `RichNoteTextController` 作為可見編輯器。`appflowy_editor 6.2.0` runtime 在 Flutter 3.44 Web build 會遇到 `TextInputClient.onFocusReceived` 相容問題，因此本次先不直接 import runtime；完整可視 AppFlowy editor 替換與自訂 attachment block 尚未完成。

## Firebase 規劃

- Firebase Auth：使用者登入。
- Cloud Firestore：筆記、行程、訂閱、記帳、待辦資料。
- Firebase Storage：圖片與附件。
- Cloud Functions：背景任務、提醒與未來 Google Calendar 同步。
- Firebase Hosting：Flutter Web 部署。
- FCM：手機推播通知。

## 開發指令

本專案使用本機 D 槽 pub cache，避免 Android/Gradle 從 C 槽 cache 取套件造成不同 root 問題。

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

安裝到指定 Android 裝置：

```powershell
.\scripts\flutter_project.ps1 install -d <device-id>
```

## 維護原則

- 修改功能後同步更新 README 與 `docs/`。
- 成功驗證後更新 `.success.bak` 備份。
- 只提交 app 必要檔案，忽略 build output、cache、測試截圖與本機 log。
- Firebase 實際專案金鑰與部署設定不提交到 repo。
