# Editor Refactor Gap

Updated: 2026-07-02

## 已直接套用

- `appflowy_editor 6.2.0`
  - 已加入依賴。
  - 一般筆記儲存時新增 `templateData.appflowy`。
  - `templateData.appflowy.document` 會用 AppFlowy 相容 JSON 儲存文字段落與圖片 block。
  - runtime widget 暫不 import，因為 6.2.0 在 Flutter 3.44 Web build 會缺 `TextInputClient.onFocusReceived` 實作。
- `flutter_box_transform 0.4.7`
  - 筆記內選取圖片後，縮放/自由移動改由 `TransformableBox` 接管。
  - 固定左/中/右對齊的圖片只開右下角縮放，避免不小心拖離排版。
  - 自由移動圖片可以在圖片 block 範圍內拖移與縮放。
- `image_cropper 12.2.1`
  - 保留既有裁切流程，繼續由圖片 toolbar 呼叫。
- `file_picker 10.3.3`
  - 因 AppFlowy 6.2.0 與 file_picker 11.x 衝突，已改到相容版本。
  - 呼叫方式改為 `FilePicker.platform.pickFiles/saveFile`。

## 和原本功能的差別

- 原本圖片是 `TextField + WidgetSpan + 自製 resize handle`。
- 現在圖片仍在現有 editor 中顯示，但：
  - 圖片 `WidgetSpan` 改為上緣對齊。
  - 圖片互動由 `TransformableBox` 控制。
  - 儲存時會同步產生 AppFlowy 文件鏡像。
- 目前可見 editor 尚未完全替換為 AppFlowy Editor widget，因為套件 runtime 與目前 Flutter Web 編譯有相容錯誤；先保留現有 toolbar、待辦、圖片與附件互動。

## 需求對照

- 有：圖片插入以圖片上邊界對齊行上方。
- 有：圖片以獨立 block 高度佔位，文字不應覆蓋圖片所在行。
- 有：圖片與圖片之間依各自 block 高度排列，不再共用同一行中心對齊。
- 有：圖片縮放/拖移改用 `flutter_box_transform`。
- 有：圖片裁切維持 `image_cropper`。
- 有：AppFlowy document JSON 鏡像，圖片轉成 AppFlowy image block。

## 沒有，但可以做

- 沒有完整替換成可視 AppFlowy editor widget；可以做，前提是等待 AppFlowy 修正 Flutter 3.44 Web 相容性，或在專案內維護一份 patched package。
- 沒有 AppFlowy 自訂 attachment block；可以做，需要新增 custom block component，處理開啟、下載、刪除。
- 沒有把舊 `RichNoteMark` 完整轉成 AppFlowy inline styles；可以做，需要把粗體、斜體、顏色、行距、清單、待辦全部轉成 Delta/Node。
- 沒有讓 AppFlowy image block 直接讀寫現有 `noteImages` 陣列；可以做，需要自訂 image block builder 並同步 node attributes。

## 還沒做

- AppFlowy Editor widget 全面取代 `RichNoteTextController`。
- AppFlowy toolbar 與目前主題 UI 完整整合。
- 自訂 AppFlowy 圖片 block 的裁切、框線、自由移動、對齊 toolbar。
- 自訂 AppFlowy 附件 block。
- 舊資料一次性 migration tool 與 rollback 工具。
