import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_note/main.dart';

void main() {
  testWidgets('renders the restored app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();

    try {
      await tester.pumpWidget(MyNoteApp(store: store));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('首頁'), findsOneWidget);
      expect(find.text('記帳'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('shows note template choices before opening an editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: NoteTemplatePickerPage()));
    await tester.pump();

    expect(find.byIcon(Icons.notes), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stacked_bar_chart), findsOneWidget);
  });

  test('rich toolbar applies inline style to selected content', () {
    final controller = RichNoteTextController(
      text: 'alpha beta',
      marks: const [],
    );

    controller.updateSelectionFromFlow(
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    controller.applyInlineAttribute(RichNoteAttribute.bold, true);

    expect(controller.marks, hasLength(1));
    expect(controller.marks.single.start, 0);
    expect(controller.marks.single.end, 5);
    expect(controller.marks.single.attributes[RichNoteAttribute.bold], true);
  });

  test('rich toolbar typing mode styles newly inserted content', () {
    final controller = RichNoteTextController(text: 'alpha', marks: const []);

    controller.updateSelectionFromFlow(
      const TextSelection.collapsed(offset: 5),
    );
    controller.applyInlineAttribute(RichNoteAttribute.bold, true);
    controller.replaceTextRange(5, 5, ' beta');

    final boldMark = controller.marks.singleWhere(
      (mark) => mark.attributes[RichNoteAttribute.bold] == true,
    );
    expect(controller.text, 'alpha beta');
    expect(controller.text.substring(boldMark.start, boldMark.end), ' beta');
  });

  testWidgets('rich toolbar formats selected text from editor field', (
    tester,
  ) async {
    final controller = RichNoteTextController(
      text: 'alpha beta',
      marks: const [],
    );
    var style = defaultNoteStyle();
    var images = <Map<String, dynamic>>[];
    var attachments = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 520,
            child: StatefulBuilder(
              builder: (context, setState) => GeneralRichTextEditorPanel(
                controller: controller,
                readOnly: false,
                style: style,
                images: images,
                attachments: attachments,
                background: defaultNoteBackground(),
                onStyleChanged: (value) => setState(() => style = value),
                onAddImage: () {},
                onAddAttachment: () {},
                onInsertTodo: () {},
                onImagesChanged: (value) =>
                    setState(() => images = List.of(value)),
                onAttachmentsChanged: (value) =>
                    setState(() => attachments = List.of(value)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.showKeyboard(find.byType(TextField).last);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'alpha beta',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(RichToolbarTextButton, 'B'));
    await tester.pump();

    final boldMark = controller.marks.singleWhere(
      (mark) => mark.attributes[RichNoteAttribute.bold] == true,
    );
    expect(boldMark.start, 0);
    expect(boldMark.end, 5);
  });
}
