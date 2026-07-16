import 'dart:convert';

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

  testWidgets('dismisses expanded FAB menu when tapping page body', (
    tester,
  ) async {
    var dismissed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DismissFabMenuLayer(
          isOpen: true,
          onDismiss: () => dismissed++,
          child: const Scaffold(body: Center(child: Text('頁面內容'))),
        ),
      ),
    );

    await tester.tap(find.text('頁面內容'));
    await tester.pump();

    expect(dismissed, 1);
  });

  testWidgets('folder name dialog recovers after length warning', (
    tester,
  ) async {
    String? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  picked = await promptForFolderName(
                    context,
                    title: '新增資料夾',
                    label: '資料夾名稱',
                  );
                },
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abcdefghijklmnopqrs');
    await tester.pump();

    expect(find.text('資料夾名稱已達長度上限'), findsOneWidget);
    await tester.tap(find.text('確認'));
    await tester.pump();
    expect(picked, isNull);
    expect(find.byType(StableFolderNamePromptDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), '專案資料夾');
    await tester.pump();

    expect(find.text('資料夾名稱已達長度上限'), findsNothing);
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();

    expect(picked, '專案資料夾');
  });

  test('new note without user content is not considered savable', () {
    expect(
      newNoteHasSavableContent(
        title: '',
        body: '',
        tags: const [],
        templateType: NoteTemplateType.general,
        templateData: defaultNoteTemplateData(NoteTemplateType.general),
        style: defaultNoteStyle(),
        images: const [],
        attachments: const [],
        background: defaultNoteBackground(),
      ),
      isFalse,
    );
    expect(
      newNoteHasSavableContent(
        title: '只有標題',
        body: '',
        tags: const ['重要'],
        templateType: NoteTemplateType.general,
        templateData: defaultNoteTemplateData(NoteTemplateType.general),
        style: defaultNoteStyle(),
        images: const [],
        attachments: const [],
        background: defaultNoteBackground(),
      ),
      isFalse,
    );
    expect(
      newNoteHasSavableContent(
        title: '',
        body: '',
        tags: const [],
        templateType: NoteTemplateType.plan,
        templateData: defaultNoteTemplateData(NoteTemplateType.plan),
        style: defaultNoteStyle(),
        images: const [],
        attachments: const [],
        background: defaultNoteBackground(),
      ),
      isFalse,
    );
  });

  test('new note with real content is considered savable', () {
    expect(
      newNoteHasSavableContent(
        title: '',
        body: '今天的想法',
        tags: const [],
        templateType: NoteTemplateType.general,
        templateData: defaultNoteTemplateData(NoteTemplateType.general),
        style: defaultNoteStyle(),
        images: const [],
        attachments: const [],
        background: defaultNoteBackground(),
      ),
      isTrue,
    );
    expect(
      newNoteHasSavableContent(
        title: '',
        body: '',
        tags: const [],
        templateType: NoteTemplateType.general,
        templateData: defaultNoteTemplateData(NoteTemplateType.general),
        style: defaultNoteStyle(),
        images: const [
          {'id': 'img-1'},
        ],
        attachments: const [],
        background: defaultNoteBackground(),
      ),
      isTrue,
    );
  });

  testWidgets('blank new note closes without creating a note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(
            home: NoteEditorPage(
              initialFolder: '測試資料夾',
              initialTemplateType: NoteTemplateType.plan,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pump();

      expect(store.notes, isEmpty);
      expect(find.text('內容為空，不儲存'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
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

  testWidgets('system note font resolves to device system family', (
    tester,
  ) async {
    final previousDeviceFont = loadedDeviceSystemFontFamily;
    final previousDeviceFontName = loadedDeviceSystemFontDisplayName;
    final previousFontOptions = Map<String, DeviceFontOption>.from(
      loadedDeviceFontOptions,
    );
    addTearDown(() {
      loadedDeviceSystemFontFamily = previousDeviceFont;
      loadedDeviceSystemFontDisplayName = previousDeviceFontName;
      loadedDeviceFontOptions
        ..clear()
        ..addAll(previousFontOptions);
    });
    late TextStyle style;
    late TextStyle inlineOverrideStyle;

    loadedDeviceSystemFontFamily = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            style = noteBodyTextStyle({
              'fontFamily': 'System',
              'fontSize': 16.0,
            }, context: context);
            inlineOverrideStyle = richNoteTextStyleForAttributes(
              context,
              const TextStyle(fontFamily: 'NotoSansTC', fontSize: 16),
              const {RichNoteAttribute.fontFamily: 'System'},
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.fontFamily, isNull);
    expect(inlineOverrideStyle.fontFamily, isNull);
    expect(noteFontFamilyLabel('System'), '裝置字體');

    loadedDeviceSystemFontFamily = noteRuntimeDeviceFontFamily;
    loadedDeviceSystemFontDisplayName = 'Samsung One';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            style = noteBodyTextStyle({
              'fontFamily': 'System',
              'fontSize': 16.0,
            }, context: context);
            inlineOverrideStyle = richNoteTextStyleForAttributes(
              context,
              const TextStyle(fontFamily: 'NotoSansTC', fontSize: 16),
              const {RichNoteAttribute.fontFamily: 'System'},
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.fontFamily, noteRuntimeDeviceFontFamily);
    expect(inlineOverrideStyle.fontFamily, noteRuntimeDeviceFontFamily);
    expect(noteFontFamilyLabel('System'), '裝置(Samsung One)');
  });

  test('installed device fonts are available as note font options', () {
    final previousFontOptions = Map<String, DeviceFontOption>.from(
      loadedDeviceFontOptions,
    );
    addTearDown(() {
      loadedDeviceFontOptions
        ..clear()
        ..addAll(previousFontOptions);
    });

    loadedDeviceFontOptions
      ..clear()
      ..addAll({
        'com.monotype.android.font.samsungone': const DeviceFontOption(
          packageName: 'com.monotype.android.font.samsungone',
          displayName: 'Samsung One',
          fontFamily: 'MyNoteInstalledDeviceFont0',
        ),
        'com.monotype.android.font.shaonv': const DeviceFontOption(
          packageName: 'com.monotype.android.font.shaonv',
          displayName: '少女體',
          fontFamily: 'MyNoteInstalledDeviceFont1',
        ),
      });

    final shaonvValue = noteDeviceFontValue('com.monotype.android.font.shaonv');

    expect(noteFontFamilyValues, contains(shaonvValue));
    expect(noteFontFamilyLabel(shaonvValue), '少女體');
    expect(noteResolvedFontFamily(shaonvValue), 'MyNoteInstalledDeviceFont1');
  });

  test(
    'app store restores backup when primary local data cannot be parsed',
    () async {
      final backupNote = NoteItem(
        id: 'n-backup',
        title: '備份筆記',
        body: '不可遺失',
        category: '',
        tags: const [],
        createdAt: DateTime(2026, 7, 15),
        updatedAt: DateTime(2026, 7, 15),
      );
      final backupRaw = jsonEncode({
        'notes': [noteToJson(backupNote)],
        'schedules': [],
        'subscriptions': [],
        'financeEntries': [],
        'savingsAccounts': [],
        'todos': [],
        'noteFolders': [],
      });
      SharedPreferences.setMockInitialValues({
        'my_note_local_v1': '{broken-json',
        'my_note_local_v1_backup': backupRaw,
      });

      final store = await AppStore.load();
      final prefs = await SharedPreferences.getInstance();

      try {
        expect(store.notes, hasLength(1));
        expect(store.notes.single.title, '備份筆記');
        expect(prefs.getString('my_note_local_v1'), backupRaw);
      } finally {
        store.dispose();
      }
    },
  );

  test(
    'app store does not overwrite existing raw data after load failure',
    () async {
      const brokenRaw = '{broken-json';
      SharedPreferences.setMockInitialValues({'my_note_local_v1': brokenRaw});

      final store = await AppStore.load();
      final prefs = await SharedPreferences.getInstance();

      try {
        store.addTodo('不應覆寫舊資料');
        await Future<void>.delayed(const Duration(milliseconds: 450));

        expect(prefs.getString('my_note_local_v1'), brokenRaw);
        expect(prefs.getString('my_note_local_v1_recovery'), brokenRaw);
      } finally {
        store.dispose();
      }
    },
  );

  test('app store ignores legacy seed backup during recovery', () async {
    final legacyRaw = jsonEncode({
      'notes': [
        {
          'id': 'n1',
          'title': '產品發想：All-in-one 個人管理筆記本',
          'body': '第一版先完成地端功能',
          'category': '專案',
          'tags': ['flutter'],
          'createdAt': DateTime(2026, 7, 15).toIso8601String(),
          'updatedAt': DateTime(2026, 7, 15).toIso8601String(),
          'isPinned': true,
        },
        {
          'id': 'n2',
          'title': '專案規劃',
          'body': '建立筆記、行程、訂閱與記帳的第一版資料模型。',
          'category': '專案',
          'tags': ['shopping'],
          'createdAt': DateTime(2026, 7, 15).toIso8601String(),
          'updatedAt': DateTime(2026, 7, 15).toIso8601String(),
        },
      ],
      'schedules': [
        {
          'id': 's2',
          'title': '週末採買',
          'start': DateTime(2026, 7, 18, 9).toIso8601String(),
          'end': DateTime(2026, 7, 18, 10).toIso8601String(),
          'location': '',
          'notes': '',
          'remindBeforeMinutes': 60,
        },
      ],
      'subscriptions': [
        {
          'id': 'sub1',
          'name': 'ChatGPT',
          'amount': 20,
          'cycle': 'monthly',
          'nextPaymentDate': DateTime(2026, 7, 20).toIso8601String(),
          'paymentMethod': '信用卡',
          'category': '專案',
          'reminderDays': 3,
          'isActive': true,
        },
      ],
      'financeEntries': [],
      'savingsAccounts': [],
      'todos': [
        {'id': 't1', 'title': '完成筆記模板整理', 'done': false},
      ],
      'noteFolders': ['專案', '學習'],
    });
    SharedPreferences.setMockInitialValues({
      'my_note_local_v1': '{broken-json',
      'my_note_local_v1_backup': legacyRaw,
    });

    final store = await AppStore.load();
    final prefs = await SharedPreferences.getInstance();

    try {
      expect(store.notes, isEmpty);
      expect(store.schedules, isEmpty);
      expect(store.subscriptions, isEmpty);
      expect(store.todos, isEmpty);
      expect(prefs.getString('my_note_local_v1'), '{broken-json');
      expect(prefs.getString('my_note_local_v1_recovery'), '{broken-json');
    } finally {
      store.dispose();
    }
  });

  test(
    'app store treats mixed legacy seed and user data as recoverable',
    () async {
      final mixedRaw = jsonEncode({
        'notes': [
          {
            'id': 'n1',
            'title': '產品發想：All-in-one 個人管理筆記本',
            'body': '第一版先完成地端功能',
            'category': '專案',
            'tags': ['flutter'],
            'createdAt': DateTime(2026, 7, 15).toIso8601String(),
            'updatedAt': DateTime(2026, 7, 15).toIso8601String(),
          },
          {
            'id': 'n-user',
            'title': '我的真實筆記',
            'body': '',
            'category': '',
            'tags': [],
            'createdAt': DateTime(2026, 7, 16).toIso8601String(),
            'updatedAt': DateTime(2026, 7, 16).toIso8601String(),
          },
        ],
        'schedules': [],
        'subscriptions': [],
        'financeEntries': [],
        'savingsAccounts': [],
        'todos': [],
        'noteFolders': [],
      });
      SharedPreferences.setMockInitialValues({
        'my_note_local_v1': '{broken-json',
        'my_note_local_v1_backup': mixedRaw,
      });

      final store = await AppStore.load();

      try {
        expect(store.notes.map((note) => note.title), contains('我的真實筆記'));
      } finally {
        store.dispose();
      }
    },
  );

  test(
    'app store writes the latest successful state into backup snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await AppStore.load();
      final prefs = await SharedPreferences.getInstance();

      try {
        store.createNoteFolder('測試資料夾');
        await Future<void>.delayed(const Duration(milliseconds: 180));

        final backupRaw = prefs.getString('my_note_local_v1_backup');
        expect(backupRaw, isNotNull);
        final backup = jsonDecode(backupRaw!) as Map<String, dynamic>;
        expect(backup['noteFolders'], contains('測試資料夾'));

        final historyRaw = prefs.getString('my_note_local_v1_backup_history');
        expect(historyRaw, isNotNull);
        expect(historyRaw, contains('測試資料夾'));
      } finally {
        store.dispose();
      }
    },
  );

  test(
    'app store recovers user data from backup history when latest backup is seed',
    () async {
      final legacyRaw = jsonEncode({
        'notes': [
          {
            'id': 'n1',
            'title': '產品發想：All-in-one 個人管理筆記本',
            'body': '第一版先完成地端功能',
            'category': '專案',
            'tags': ['flutter'],
            'createdAt': DateTime(2026, 7, 15).toIso8601String(),
            'updatedAt': DateTime(2026, 7, 15).toIso8601String(),
          },
        ],
        'schedules': [],
        'subscriptions': [],
        'financeEntries': [],
        'savingsAccounts': [],
        'todos': [],
        'noteFolders': ['專案'],
      });
      final userRaw = jsonEncode({
        'notes': [],
        'schedules': [],
        'subscriptions': [],
        'financeEntries': [],
        'savingsAccounts': [],
        'todos': [],
        'noteFolders': ['新資料夾', '連續測試'],
      });
      SharedPreferences.setMockInitialValues({
        'my_note_local_v1': '{broken-json',
        'my_note_local_v1_backup': legacyRaw,
        'my_note_local_v1_backup_history': jsonEncode([
          {
            'savedAt': DateTime(2026, 7, 15, 10).toIso8601String(),
            'raw': legacyRaw,
          },
          {
            'savedAt': DateTime(2026, 7, 15, 11).toIso8601String(),
            'raw': userRaw,
          },
        ]),
      });

      final store = await AppStore.load();

      try {
        expect(store.noteFolders, containsAll(['新資料夾', '連續測試']));
        expect(store.noteFolders, isNot(contains('專案')));
      } finally {
        store.dispose();
      }
    },
  );

  test('folder names are limited by fullwidth and halfwidth length', () {
    expect(
      limitFolderNameForStorage('abcdefghijklmnopqrst'),
      'abcdefghijklmnopqr',
    );
    expect(limitFolderNameForStorage('資料夾名稱超過十二個全形字元'), '資料夾名稱超過十二個全形');
    expect(
      limitedFolderNameForDisplay('abcdefghijklmnopqrst'),
      'abcdefghijklmnopq…',
    );
    expect(folderNameForPathTitle('資料夾名稱很長'), '資料夾名稱…');
    expect(folderNameForPathTitle('abcdefghi'), 'abcde…');
    expect(folderNameForPathTitle('短名'), '短名');
  });

  test('folder name formatter rejects input beyond the length limit', () {
    var exceeded = false;
    final formatter = FolderNameLengthInputFormatter(
      onLimitExceeded: () => exceeded = true,
      onWithinLimit: () => exceeded = false,
    );
    const oldValue = TextEditingValue(text: 'abcdefghijklmnopqr');

    final result = formatter.formatEditUpdate(
      oldValue,
      const TextEditingValue(text: 'abcdefghijklmnopqrs'),
    );

    expect(result.text, oldValue.text);
    expect(exceeded, isTrue);

    final recovered = formatter.formatEditUpdate(
      oldValue,
      const TextEditingValue(text: 'valid-folder'),
    );

    expect(recovered.text, 'valid-folder');
    expect(exceeded, isFalse);
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
