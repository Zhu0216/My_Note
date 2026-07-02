# FlutterFlow Templates

This document tracks FlutterFlow UI templates referenced by the project and how they are applied in `my_note`.

## Sources

| Template | URL | Intended usage | Current status |
| --- | --- | --- | --- |
| Rich Text | https://app.flutterflow.io/project/rich-text-ikif5z | General note content editor | Applied as `GeneralRichTextEditorPanel`, `RichTextTemplateToolbar`, and `RichNoteTextController` in `lib/main.dart`. The toolbar follows the user-provided template screenshot while adapting controls for this app: undo, font size, bold, italic, underline, strike, code, sub/superscript, line height, lists, checkbox, quote, indent, image, attachment, and todo insertion. |
| Nav Bars | https://app.flutterflow.io/project/nav-bars-a113t9 | Bottom navigation, style 6 | Applied as `AppNavBarStyle.template6` in `lib/main.dart`, with page-specific icons for Notes, Calendar, Home, Finance, and Settings. |

## Local Integration Notes

- `AppNavBarStyle.template6` is now a named style so future settings can switch among nav styles without replacing the shell.
- `GeneralRichTextEditorPanel` separates the toolbar from the general note text area; the text pane fills the remaining editor height so the note surface reads like an endless page.
- `RichTextTemplateToolbar` replaces the previous generic style toolbar for general notes. It applies formatting to structured rich-text spans instead of writing Markdown/HTML markers into the visible note body.
- Toolbar format buttons now toggle typing mode when no text is selected, so pressing bold/italic/etc. affects the next typed text without inserting sample words.
- Toolbar overflow shows left/right arrow buttons; line height replaced the previous heading dropdown and updates the displayed toolbar value.
- Subscript and superscript typing modes are mutually exclusive and switch directly when the opposite mode is tapped.
- Numbered, bullet, and checkbox todo lines continue automatically on newline; pressing enter on an empty marker line removes the marker and exits the list.
- Checkbox markers inside note content can be tapped to toggle between unchecked and checked states.
- Checkbox markers are rendered as real Flutter `Checkbox` widgets in the editor instead of text-only symbols.
- Images and attachments are inserted into the editable note surface through rich-text embed placeholders, so they appear at the insertion position instead of in a separate attachment strip.
- Selecting an inline image switches the toolbar to image controls for crop, drag resize, border width/color, alignment, and delete; selecting an inline attachment switches the toolbar to open, download, and delete controls.
- Note tags are edited in `#tag #tag2` format instead of comma-separated text.
- Image and attachment uploads use the platform file picker and render inside the rich editor area without adding placeholder text to the note body.
- The note editor header is now the editable note title and tags area; back saves and closes directly.
- General notes keep `body` as plain text for search/preview compatibility and save formatting under `templateData.richText.spans`.
- Template-specific note data remains separated by `NoteTemplateType` and `templateData`; the four templates are not treated as the same format.
- The FlutterFlow project links are not public download artifacts in the current environment. If export files become available later, place them under `D:\Flutter_Project\flutterflow_project_probe` and update this file with the exported component names.
