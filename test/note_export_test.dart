import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/note_editor.dart';
import 'package:my_note/services/note_file_service.dart';

void main() {
  test('plain export replaces rich embed objects with readable labels', () {
    final text = '前文$richNoteEmbedObject後文';
    final marks = [
      RichNoteMark(
        start: 2,
        end: 3,
        attributes: const {
          RichNoteAttribute.embedType: richNoteEmbedTypeAttachment,
          RichNoteAttribute.embedId: 'attachment-1',
        },
      ),
    ];

    expect(richNotePlainExportText(text, marks), '前文[附件]後文');
  });

  test('markdown export preserves supported rich formatting and links', () {
    final text = '粗體與斜體$richNoteEmbedObject';
    final marks = [
      RichNoteMark(
        start: 0,
        end: 2,
        attributes: const {RichNoteAttribute.bold: true},
      ),
      RichNoteMark(
        start: 3,
        end: 5,
        attributes: const {RichNoteAttribute.italic: true},
      ),
      RichNoteMark(
        start: 5,
        end: 6,
        attributes: const {
          RichNoteAttribute.embedType: richNoteEmbedTypeNote,
          RichNoteAttribute.embedId: 'note-7',
        },
      ),
    ];

    expect(
      richNoteMarkdownExportText(text, marks),
      '**粗體**與*斜體*[筆記連結](my-note:note:note-7)',
    );
  });

  testWidgets('PDF export supports Traditional Chinese text', (tester) async {
    final bytes = await NoteFileService.buildNotePdf(
      title: '中文標題',
      body: '這是一段繁體中文筆記。',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
