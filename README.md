# My Note

All-in-one 個人管理筆記本，使用 Flutter 開發，目標支援 Android、Flutter Web，並逐步接入 Firebase Auth、Cloud Firestore、Firebase Storage、FCM 與 Firebase Hosting。

## 目前功能

- Home 首頁：月結算、今日行程、即將到來、最近筆記、待辦事項、可調整區塊順序與顯示樣式。
- Notes 筆記：資料夾、未分類、垃圾桶、搜尋/篩選、排序、清單/格線/簡易清單、批次編輯、置頂、左滑刪除。
- 一般筆記編輯：標題與標籤直接編輯、rich text toolbar、文字樣式、清單、待辦核取方塊、圖片、附件、背景設定、另存為入口。
- 筆記模板：筆記、計劃、心智圖、人生試算表。四種模板已分流，未來可各自擴充成不同資料格式。
- Calendar 行程：日期點選、當日行程、新增/編輯/刪除、時間選擇、左滑刪除。
- Finance 記帳：存餘、本月收入、本月支出、收支紀錄、支出/收入統計、預算、存餘帳戶管理。
- Settings 設定：Firebase 與未來同步設定入口。

## 筆記圖片編輯

- 圖片現在不再放在 `TextField` 的 inline `WidgetSpan` 裡排版，改為 editor flow 中的獨立圖片 block。
- 圖片 block 與文字 block 依序排列，達成類似 Word「上及下」的文繞圖方式。
- 文字只能出現在圖片上方或下方，不會與圖片在同一個 y 範圍重疊。
- 點擊圖片本體會立即選取圖片並顯示圖片 toolbar。
- 圖片 toolbar 包含裁切、縮放、框線線徑、框線顏色、靠左、置中、靠右、刪除與完成。
- 縮放只改變圖片尺寸，不改變對齊；對齊只改變水平位置。
- 選取圖片時八個縮放控制點可見：左上、上、右上、左、右、左下、下、右下。

## Firebase 規劃

- Firebase Auth：使用者登入。
- Cloud Firestore：筆記、行程、訂閱、記帳與待辦資料。
- Firebase Storage：附件與圖片。
- Cloud Functions：背景任務與未來 Google Calendar 同步。
- Firebase Hosting：Flutter Web 部署。
- FCM：手機推播通知。

第一版以地端功能完整為主，Firebase 相關設定已規劃但尚未全面啟用。

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

安裝到 Android 裝置：

```powershell
.\scripts\flutter_project.ps1 install -d <device-id>
```

## 本次驗證

- `dart format lib/main.dart`：成功。
- `dart analyze lib/main.dart`：成功，No issues found。
- `flutter build apk --debug --no-pub`：成功。
- X510 實機安裝：成功。
- X510 實機截圖確認：圖片上方文字、圖片 block、圖片下方文字依序排列，文字不再被圖片遮擋。
- X510 實機截圖確認：點擊圖片本體可立即選取圖片，顯示圖片 toolbar 與八個縮放控制點。
- `flutter build web --debug --no-wasm-dry-run --no-pub`：成功。
- Web 靜態伺服器：`http://127.0.0.1:8080/` 回應 200，已開啟瀏覽器。

## 已知事項

- Android build 仍會顯示 KGP 警告，來源為 `file_picker`、`firebase_storage`、`share_plus` 仍套用 Kotlin Gradle Plugin。此警告不影響本次圖片排版修正，但未來 Flutter 版本可能需要等待外掛更新或替換套件。
- 一般筆記已改為 block flow 編輯器，後續若要完整保留跨 block 的 rich text 選取與格式套用，需再細化文字 block selection 與 toolbar 的整合。

## 維護流程

- 每次功能修正後更新 README。
- 每次成功修改後更新 `.success.bak` 備份。
- 不提交 build output、cache、暫存截圖、裝置 XML/log。
