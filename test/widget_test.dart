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

  test('rich toolbar font size applies only to selected content', () {
    final controller = RichNoteTextController(
      text: 'alpha beta',
      marks: const [],
    );

    controller.updateSelectionFromFlow(
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    controller.setInlineAttribute(RichNoteAttribute.fontSize, 28.0);

    final sizeMark = controller.marks.singleWhere(
      (mark) => mark.attributes[RichNoteAttribute.fontSize] == 28.0,
    );
    expect(sizeMark.start, 6);
    expect(sizeMark.end, 10);
    expect(controller.text.substring(sizeMark.start, sizeMark.end), 'beta');
    expect(
      controller.selectionAttributeValue(RichNoteAttribute.fontSize),
      28.0,
    );
  });

  test('rich toolbar font family typing mode styles new content', () {
    final controller = RichNoteTextController(text: 'alpha', marks: const []);

    controller.updateSelectionFromFlow(
      const TextSelection.collapsed(offset: 5),
    );
    controller.setInlineAttribute(RichNoteAttribute.fontFamily, 'NotoSerifTC');
    controller.replaceTextRange(5, 5, ' beta');

    final familyMark = controller.marks.singleWhere(
      (mark) => mark.attributes[RichNoteAttribute.fontFamily] == 'NotoSerifTC',
    );
    expect(controller.text, 'alpha beta');
    expect(
      controller.text.substring(familyMark.start, familyMark.end),
      ' beta',
    );
  });

  test('rich toolbar typing mode toggles off inherited inline styles', () {
    const attributes = [
      RichNoteAttribute.bold,
      RichNoteAttribute.italic,
      RichNoteAttribute.underline,
      RichNoteAttribute.strikethrough,
      RichNoteAttribute.inlineCode,
    ];

    for (final attribute in attributes) {
      final controller = RichNoteTextController(
        text: 'alpha',
        marks: [
          RichNoteMark(start: 0, end: 5, attributes: {attribute: true}),
        ],
      );

      controller.updateSelectionFromFlow(
        const TextSelection.collapsed(offset: 5),
      );
      expect(controller.selectionHasAttribute(attribute, value: true), isTrue);

      controller.applyInlineAttribute(attribute, true);
      expect(controller.selectionHasAttribute(attribute, value: true), isFalse);

      controller.replaceTextRange(5, 5, ' beta');
      final insertedHasAttribute = controller.marks.any(
        (mark) =>
            mark.start <= 5 &&
            mark.end >= 10 &&
            mark.attributes[attribute] == true,
      );
      expect(insertedHasAttribute, isFalse);
    }
  });

  test(
    'rich toolbar switches subscript and superscript typing modes directly',
    () {
      final controller = RichNoteTextController(
        text: 'alpha',
        marks: const [
          RichNoteMark(
            start: 0,
            end: 5,
            attributes: {RichNoteAttribute.subscript: true},
          ),
        ],
      );

      controller.updateSelectionFromFlow(
        const TextSelection.collapsed(offset: 5),
      );
      expect(
        controller.selectionHasAttribute(
          RichNoteAttribute.subscript,
          value: true,
        ),
        isTrue,
      );

      controller.applyInlineAttribute(RichNoteAttribute.superscript, true);

      expect(
        controller.selectionHasAttribute(
          RichNoteAttribute.superscript,
          value: true,
        ),
        isTrue,
      );
      expect(
        controller.selectionHasAttribute(
          RichNoteAttribute.subscript,
          value: true,
        ),
        isFalse,
      );
    },
  );

  test('rich lists continue when typing a new line', () {
    final cases = {
      '1. Alpha': '1. Alpha\n2. ',
      '• Alpha': '• Alpha\n• ',
      '☐ Alpha': '☐ Alpha\n☐ ',
    };

    for (final entry in cases.entries) {
      final controller = RichNoteTextController(
        text: entry.key,
        marks: const [],
      );
      controller.updateSelectionFromFlow(
        TextSelection.collapsed(offset: entry.key.length),
      );

      controller.replaceTextRange(entry.key.length, entry.key.length, '\n');

      expect(controller.text, entry.value);
      expect(controller.selection.extentOffset, entry.value.length);
    }
  });

  test('rich lists remove marker when marker trailing space is deleted', () {
    final cases = {
      '1. ': (2, ''),
      '• ': (1, ''),
      '☐ ': (1, ''),
      '  • ': (3, '  '),
    };

    for (final entry in cases.entries) {
      final controller = RichNoteTextController(
        text: entry.key,
        marks: const [],
      );
      final (spaceIndex, expectedText) = entry.value;

      controller.replaceTextRange(spaceIndex, spaceIndex + 1, '');

      expect(controller.text, expectedText);
      expect(controller.selection.extentOffset, expectedText.length);
    }
  });

  test('rich toolbar font size options cover 10 to 30 by step 2', () {
    expect(RichToolbarFontSizeButton.values, const [
      10,
      12,
      14,
      16,
      18,
      20,
      22,
      24,
      26,
      28,
      30,
    ]);
  });

  testWidgets('rich toolbar font size wheel slides and opens input', (
    tester,
  ) async {
    var currentSize = 16.0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Center(
                child: RichToolbarFontSizeButton(
                  currentSize: currentSize,
                  tooltip: '字級',
                  onSelected: (value) => setState(() {
                    currentSize = value;
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('16'), findsOneWidget);
    expect(find.text('14'), findsNothing);
    expect(find.text('18'), findsNothing);

    await tester.drag(
      find.byType(RichToolbarFontSizeButton),
      const Offset(0, -24),
    );
    await tester.pump();

    expect(currentSize, 18.0);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('14'), findsNothing);
    expect(find.text('16'), findsNothing);
    expect(find.text('20'), findsNothing);
    expect(find.text('22'), findsNothing);

    await tester.drag(
      find.byType(RichToolbarFontSizeButton),
      const Offset(0, 24),
    );
    await tester.pump();

    expect(currentSize, 16.0);

    await tester.tap(find.byType(RichToolbarFontSizeButton));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.byKey(const ValueKey('font-size-input-cancel')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(currentSize, 16.0);

    await tester.tap(find.byType(RichToolbarFontSizeButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('font-size-input-field')),
      '24',
    );
    await tester.tap(find.byKey(const ValueKey('font-size-input-confirm')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(currentSize, 24.0);
  });

  testWidgets('inline font style is applied to text spans', (tester) async {
    late TextStyle style;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            style = richNoteTextStyleForAttributes(
              context,
              const TextStyle(fontSize: 16),
              const {
                RichNoteAttribute.fontFamily: 'NotoSerifTC',
                RichNoteAttribute.fontSize: 28.0,
              },
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.fontFamily, 'NotoSerifTC');
    expect(style.fontSize, 28.0);
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
    expect(tester.testTextInput.isVisible, isTrue);

    final boldMark = controller.marks.singleWhere(
      (mark) => mark.attributes[RichNoteAttribute.bold] == true,
    );
    expect(boldMark.start, 0);
    expect(boldMark.end, 5);
  });

  testWidgets('rich toolbar toggle off updates immediately and keeps focus', (
    tester,
  ) async {
    final controller = RichNoteTextController(
      text: 'alpha',
      marks: const [
        RichNoteMark(
          start: 0,
          end: 5,
          attributes: {RichNoteAttribute.bold: true},
        ),
      ],
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
        text: 'alpha',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();

    final boldFinder = find.widgetWithText(RichToolbarTextButton, 'B');
    expect(tester.widget<RichToolbarTextButton>(boldFinder).active, isTrue);

    await tester.tap(boldFinder);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<RichToolbarTextButton>(boldFinder).active, isFalse);
  });

  testWidgets('rich flow lists keep caret after continued list marker', (
    tester,
  ) async {
    final controller = RichNoteTextController(text: '• Alpha', marks: const []);
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
        text: '• Alpha\n',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    await tester.pump();

    expect(controller.text, '• Alpha\n• ');
    expect(controller.selection.extentOffset, controller.text.length);
    final textField = tester.widget<TextField>(find.byType(TextField).last);
    expect(textField.controller?.text, '• Alpha\n• ');
    expect(textField.controller?.selection.extentOffset, '• Alpha\n• '.length);
  });

  testWidgets('rich flow caret height follows active font size', (
    tester,
  ) async {
    final controller = RichNoteTextController(text: '', marks: const []);
    controller.updateSelectionFromFlow(
      const TextSelection.collapsed(offset: 0),
    );
    controller.setInlineAttribute(RichNoteAttribute.fontSize, 28.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 520,
            child: GeneralRichTextEditorPanel(
              controller: controller,
              readOnly: false,
              style: defaultNoteStyle(),
              images: const [],
              attachments: const [],
              background: defaultNoteBackground(),
              onStyleChanged: (_) {},
              onAddImage: () {},
              onAddAttachment: () {},
              onInsertTodo: () {},
              onImagesChanged: (_) {},
              onAttachmentsChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField).last);
    expect(textField.cursorHeight, closeTo(28.0 * 1.45, 0.001));
  });

  testWidgets(
    'rich flow caret height updates immediately after font size changes',
    (tester) async {
      final controller = RichNoteTextController(text: '', marks: const []);
      controller.updateSelectionFromFlow(
        const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 520,
              child: GeneralRichTextEditorPanel(
                controller: controller,
                readOnly: false,
                style: defaultNoteStyle(),
                images: const [],
                attachments: const [],
                background: defaultNoteBackground(),
                onStyleChanged: (_) {},
                onAddImage: () {},
                onAddAttachment: () {},
                onInsertTodo: () {},
                onImagesChanged: (_) {},
                onAttachmentsChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).last).cursorHeight,
        closeTo(16.0 * 1.45, 0.001),
      );

      controller.setInlineAttribute(RichNoteAttribute.fontSize, 30.0);
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).last).cursorHeight,
        closeTo(30.0 * 1.45, 0.001),
      );
    },
  );

  testWidgets('todo reference renders as a synced read only block', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    store.todos.clear();
    store.addTodo('同步待辦');
    final todo = store.todos.single;
    final controller = RichNoteTextController(
      text: richNoteEmbedObject,
      marks: [
        RichNoteMark(
          start: 0,
          end: 1,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeTodo,
            RichNoteAttribute.embedId: todo.id,
          },
        ),
      ],
    );

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 520,
                child: GeneralRichTextEditorPanel(
                  controller: controller,
                  readOnly: false,
                  style: defaultNoteStyle(),
                  images: const [],
                  attachments: const [],
                  background: defaultNoteBackground(),
                  onStyleChanged: (_) {},
                  onAddImage: () {},
                  onAddAttachment: () {},
                  onInsertTodo: () {},
                  onImagesChanged: (_) {},
                  onAttachmentsChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InlineRichTodoReferenceBlock), findsOneWidget);
      expect(find.text('同步待辦'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(todo.done, isTrue);
      store.toggleTodo(todo);
      await tester.pump();

      expect(todo.done, isFalse);

      await tester.tap(find.byType(InlineRichTodoReferenceBlock));
      await tester.pump();

      expect(find.byType(RichTodoReferenceEditToolbar), findsOneWidget);

      await tester.tap(find.byTooltip('完成'));
      await tester.pump();
      expect(todo.done, isTrue);

      await tester.tap(find.byTooltip('未完成'));
      await tester.pump();
      expect(todo.done, isFalse);

      await tester.tap(find.byTooltip('自本筆記移除'));
      await tester.pump();

      expect(find.byType(InlineRichTodoReferenceBlock), findsNothing);
      expect(store.todos.single.id, todo.id);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('rich image block remains selectable from editor flow', (
    tester,
  ) async {
    final controller = RichNoteTextController(
      text: 'before\n$richNoteEmbedObject\nafter',
      marks: const [
        RichNoteMark(
          start: 7,
          end: 8,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeImage,
            RichNoteAttribute.embedId: 'image-1',
          },
        ),
      ],
    );
    final images = <Map<String, dynamic>>[
      {
        'id': 'image-1',
        'name': 'demo.png',
        'width': 120.0,
        'height': 80.0,
        'alignment': NoteImageAlignment.center.name,
      },
    ];
    var nextImages = images;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 520,
            child: GeneralRichTextEditorPanel(
              controller: controller,
              readOnly: false,
              style: defaultNoteStyle(),
              images: nextImages,
              attachments: const [],
              background: defaultNoteBackground(),
              onStyleChanged: (_) {},
              onAddImage: () {},
              onAddAttachment: () {},
              onInsertTodo: () {},
              onImagesChanged: (value) => nextImages = List.of(value),
              onAttachmentsChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InlineRichImageBlock), findsOneWidget);

    await tester.tap(find.byType(InlineRichImageBlock));
    await tester.pumpAndSettle();

    expect(find.byType(ModernRichImageEditToolbar), findsOneWidget);
  });

  testWidgets('trailing empty image input block remains editable', (
    tester,
  ) async {
    final controller = RichNoteTextController(
      text: 'before\n$richNoteEmbedObject\n',
      marks: const [
        RichNoteMark(
          start: 7,
          end: 8,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeImage,
            RichNoteAttribute.embedId: 'image-1',
          },
        ),
      ],
    );
    final images = <Map<String, dynamic>>[
      {
        'id': 'image-1',
        'name': 'demo.png',
        'width': 120.0,
        'height': 80.0,
        'alignment': NoteImageAlignment.center.name,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 520,
            child: GeneralRichTextEditorPanel(
              controller: controller,
              readOnly: false,
              style: defaultNoteStyle(),
              images: images,
              attachments: const [],
              background: defaultNoteBackground(),
              onStyleChanged: (_) {},
              onAddImage: () {},
              onAddAttachment: () {},
              onInsertTodo: () {},
              onImagesChanged: (_) {},
              onAttachmentsChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InlineRichImageBlock), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('single inserted image keeps an input line below it', (
    tester,
  ) async {
    final controller = RichNoteTextController(
      text: '$richNoteEmbedObject\n',
      marks: const [
        RichNoteMark(
          start: 0,
          end: 1,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeImage,
            RichNoteAttribute.embedId: 'image-1',
          },
        ),
      ],
    );
    final images = <Map<String, dynamic>>[
      {
        'id': 'image-1',
        'name': 'demo.png',
        'width': 120.0,
        'height': 80.0,
        'alignment': NoteImageAlignment.center.name,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 520,
            child: GeneralRichTextEditorPanel(
              controller: controller,
              readOnly: false,
              style: defaultNoteStyle(),
              images: images,
              attachments: const [],
              background: defaultNoteBackground(),
              onStyleChanged: (_) {},
              onAddImage: () {},
              onAddAttachment: () {},
              onInsertTodo: () {},
              onImagesChanged: (_) {},
              onAttachmentsChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InlineRichImageBlock), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('home todo row shows title above due and reminder metadata', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    store.todos.clear();
    store.addTodo(
      '整理筆記',
      dueDate: DateTime(2026, 7, 20),
      reminderEnabled: true,
      reminderTime: const TimeOfDay(hour: 9, minute: 30),
    );
    final todo = store.todos.single;

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: TodoBlock())),
        ),
      );
      await tester.pump();

      final titleTop = tester.getTopLeft(find.text('整理筆記')).dy;
      final dueTop = tester.getTopLeft(find.text(todoDueLabel(todo))).dy;
      final reminderTop = tester
          .getTopLeft(find.text(todoReminderTimeLabel(todo)))
          .dy;

      expect(titleTop, lessThan(dueTop));
      expect(titleTop, lessThan(reminderTop));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
}
