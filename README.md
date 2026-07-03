# My Note

All-in-one 個人管理筆記本，使用 Flutter 開發，目標支援 Android、Flutter Web，後續接上 Firebase Auth、Cloud Firestore、Firebase Storage、FCM、Firebase Hosting。

## 目前功能

- Home 首頁：今日行程、即將到來、本月收支、最近筆記、待辦事項、可調整首頁區塊順序與顯示樣式。
- Notes 筆記：資料夾、標籤、搜尋、排序、檢視模式、批量編輯、垃圾桶、置頂、四種模板入口。
- 筆記編輯：Rich text toolbar、待辦核取方塊、圖片、附件、背景設定、另存為、返回自動儲存。
- Calendar 行程：日期點選、當日行程、新增行程、時間選擇、左滑刪除。
- Finance 記帳：收入、支出、存餘帳戶、月預算、支出與收入圖表、近期紀錄、訂閱管理。
- Settings 設定：Firebase 狀態與後續同步設定預留。

## 最新更新

- 所有 rich editor 的資產工具列改成可水平捲動，當工具超出顯示區域時會出現左右箭頭。
- 圖片改為 editor document flow 內的獨立 ImageBlock，不再用 floating overlay 疊在文字上。
- ImageBlock 會佔用真實 layout 高度與整個文字行寬，文字只能位於圖片上方或下方，避免 caret 或輸入行出現在圖片遮住的位置。
- 點擊圖片本體會直接選取圖片並顯示圖片 toolbar，不需要先點插入行。
- 圖片 toolbar 已改為：裁切、縮放、框線線徑、框線顏色、靠左、置中、靠右、刪除圖片、完成。
- 框線線徑改為輸入式對話框，框線顏色改為子 toolbar，提供 9 種基礎色。

## Firebase 進度

- Firebase Auth：已預留登入架構。
- Cloud Firestore：已規劃筆記、行程、記帳、訂閱資料模型。
- Firebase Storage：已預留圖片與附件用途。
- Cloud Functions：預留背景任務與 Google Calendar 同步。
- Firebase Hosting：可用 Flutter Web build 部署。
- FCM：預留提醒通知。

## 測試紀錄

- `dart format lib/main.dart`：通過。
- `dart analyze lib/main.dart`：通過，No issues found。
- `flutter build apk --debug --no-pub`：通過。
- X510 實機安裝：成功。
- X510 圖片點擊驗證：點圖片本體只出現 `IMAGE_VISUAL_TAP`，未出現 `PARAGRAPH_TAP` 或 `CARET_CHANGED`。
- X510 圖片 layout 驗證：圖片 block 實際佔用完整行寬與高度，log 顯示 `nextParagraph.y>=imageBlock.height`。
- `flutter build web --debug --no-wasm-dry-run --no-pub`：通過。
- Web 本機檢查：`http://127.0.0.1:8080/` 回應 `200`，已開啟瀏覽器。

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
- 每次成功修改後更新 `.success.bak` 備份。
- 不提交 build output、cache、暫存測試 XML/log/png。
- Firebase 專案金鑰與個人憑證不得提交到 repo。
