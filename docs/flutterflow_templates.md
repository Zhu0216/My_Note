# FlutterFlow Templates

This document tracks FlutterFlow UI templates referenced by the project and how they are applied in `my_note`.

## Sources

| Template | URL | Intended usage | Current status |
| --- | --- | --- | --- |
| Rich Text | https://app.flutterflow.io/project/rich-text-ikif5z | General note content editor | Applied as `GeneralRichTextEditorPanel`, `RichTextTemplateToolbar`, and `RichNoteTextController` in `lib/main.dart`. The toolbar follows the user-provided template screenshot: undo, font size, bold, italic, underline, strike, code, sub/superscript, heading, lists, checkbox, quote, and indent controls. |
| Nav Bars | https://app.flutterflow.io/project/nav-bars-a113t9 | Bottom navigation, style 6 | Applied as `AppNavBarStyle.template6` in `lib/main.dart`, with page-specific icons for Notes, Calendar, Home, Finance, and Settings. |

## Local Integration Notes

- `AppNavBarStyle.template6` is now a named style so future settings can switch among nav styles without replacing the shell.
- `GeneralRichTextEditorPanel` combines the general note text area and a theme-aware rich-text toolbar into one editor surface.
- `RichTextTemplateToolbar` replaces the previous generic style toolbar for general notes. It applies formatting to structured rich-text spans instead of writing Markdown/HTML markers into the visible note body.
- Toolbar format buttons now toggle typing mode when no text is selected, so pressing bold/italic/etc. affects the next typed text without inserting sample words.
- General notes keep `body` as plain text for search/preview compatibility and save formatting under `templateData.richText.spans`.
- Template-specific note data remains separated by `NoteTemplateType` and `templateData`; the four templates are not treated as the same format.
- The FlutterFlow project links are not public download artifacts in the current environment. If export files become available later, place them under `D:\Flutter_Project\flutterflow_project_probe` and update this file with the exported component names.
