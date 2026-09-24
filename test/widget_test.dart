import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_note/main.dart';
import 'package:my_note/features/notes/mind_map_canvas_editor.dart';
import 'package:my_note/features/notes/plan_tree_editor.dart';

class _FakeImageFilePicker extends FilePicker {
  _FakeImageFilePicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'picked.png', size: bytes.length, bytes: bytes),
  ]);
}

void main() {
  test('template documents migrate legacy data into structured v2 records', () {
    final plan = PlanDocument.fromJson({
      'schema': 'plan.v1',
      'goal': '完成產品第一版',
      'phase': '第一階段',
      'tasks': [
        {'title': '已完成任務', 'done': true},
        {'title': '未完成任務', 'done': false},
      ],
      'startDate': '2026-09-01T00:00:00.000',
      'dueDate': '2026-10-01T00:00:00.000',
      'spentHours': 12.5,
      'notes': '保留舊備註',
    });
    expect(plan.nodes, hasLength(3));
    expect(plan.childrenOf('legacy-phase'), hasLength(2));
    expect(plan.progressOf('legacy-phase'), closeTo(0.5, 0.001));
    expect(plan.goal, '完成產品第一版');
    expect(plan.startDate, DateTime(2026, 9));
    expect(plan.dueDate, DateTime(2026, 10));
    expect(plan.spentHours, 12.5);
    expect(plan.notes, '保留舊備註');

    final migrated = plan.toJson();
    expect(migrated['schema'], PlanDocument.schema);
    expect(migrated, isNot(contains('phase')));
    expect(migrated, isNot(contains('tasks')));
    expect(PlanDocument.fromJson(migrated).nodes, hasLength(3));

    final mindMap = MindMapDocument.fromJson({
      'schema': 'mind_map.v1',
      'topic': '中心主題',
      'nodes': [
        {
          'title': '分支',
          'subtitle': '次標',
          'description': '舊說明',
          'x': 100,
          'y': 10,
          'color': '#235A93',
          'expanded': false,
        },
        {'title': '中心主題', 'x': 0, 'y': 0},
      ],
    });
    expect(mindMap.rootNodeId, mindMap.nodes.last.id);
    expect(mindMap.nodes.last.title, '中心主題');
    expect(mindMap.nodes.first.subtitle, '次標');
    expect(mindMap.nodes.first.description, '舊說明');
    expect(mindMap.nodes.first.x, 100);
    expect(mindMap.nodes.first.y, 10);
    expect(mindMap.nodes.first.color, '#235A93');
    expect(mindMap.nodes.first.expanded, isFalse);
    expect(mindMap.toJson()['schema'], MindMapDocument.schema);

    final lifeProject = LifeProjectDocument.fromJson({
      'items': [
        {'name': '基金', 'targetAmount': 1000, 'currentAmount': 250},
        {'name': '閱讀', 'progress': 0.5, 'displayMode': 'progress'},
      ],
    });
    expect(lifeProject.items, hasLength(2));
    expect(lifeProject.weightedProgress, closeTo(0.375, 0.001));
    expect(lifeProject.toJson()['schema'], LifeProjectDocument.schema);
    expect(lifeProject.items.first.manualCurrentAmount, 250);
  });

  test('plan tree reorders siblings and removes a complete subtree', () {
    final document = PlanDocument(
      nodes: [
        PlanNode(id: 'root', title: '主階段', type: PlanNodeType.phase),
        PlanNode(
          id: 'child',
          title: '子階段',
          type: PlanNodeType.phase,
          parentId: 'root',
        ),
        PlanNode(
          id: 'task-a',
          title: '任務 A',
          type: PlanNodeType.task,
          parentId: 'child',
        ),
        PlanNode(
          id: 'task-b',
          title: '任務 B',
          type: PlanNodeType.task,
          parentId: 'child',
        ),
      ],
    );

    document.reorderChild('child', 0, 1);
    expect(document.childrenOf('child').map((node) => node.id), [
      'task-b',
      'task-a',
    ]);
    expect(document.subtreeIds('child'), {'child', 'task-a', 'task-b'});

    document.removeSubtree('child');
    expect(document.nodes.map((node) => node.id), ['root']);
  });

  testWidgets('plan tree creates nested phases and terminal tasks', (
    tester,
  ) async {
    var document = PlanDocument(
      nodes: [PlanNode(id: 'root', title: '主階段', type: PlanNodeType.phase)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlanTreeEditor(
              document: document,
              onChanged: (value) => setState(() => document = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('項目選項').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增子階段'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '執行階段');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();

    final child = document.nodes.singleWhere((node) => node.title == '執行階段');
    expect(child.type, PlanNodeType.phase);
    expect(child.parentId, 'root');

    await tester.tap(find.byTooltip('項目選項').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增任務'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '完成驗收');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();

    final task = document.nodes.singleWhere((node) => node.title == '完成驗收');
    expect(task.type, PlanNodeType.task);
    expect(task.parentId, child.id);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(task.completed, isTrue);

    await tester.tap(find.byTooltip('項目選項').last);
    await tester.pumpAndSettle();
    expect(find.text('新增子階段'), findsNothing);
    expect(find.text('新增任務'), findsNothing);
    expect(find.text('重新命名'), findsOneWidget);
  });

  test('nested plan tree survives restart and export import', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final document = PlanDocument(
      nodes: [
        PlanNode(id: 'phase-1', title: '第一階段', type: PlanNodeType.phase),
        PlanNode(
          id: 'phase-2',
          title: '子階段',
          type: PlanNodeType.phase,
          parentId: 'phase-1',
        ),
        PlanNode(
          id: 'task-1',
          title: '驗收任務',
          type: PlanNodeType.task,
          parentId: 'phase-2',
          completed: true,
        ),
      ],
    );
    store.upsertNote(
      NoteItem(
        id: 'nested-plan',
        title: '巢狀計畫',
        body: '',
        category: '',
        tags: const [],
        createdAt: DateTime(2026, 9, 24),
        updatedAt: DateTime(2026, 9, 24),
        templateType: NoteTemplateType.plan,
        templateData: document.toJson(),
      ),
    );
    await store.flushPersistence();
    final exported = await store.exportBundle();
    store.dispose();

    final reloaded = await AppStore.load();
    final imported = AppStore.seeded(persistenceLocked: true);
    try {
      final restoredDocument = PlanDocument.fromJson(
        reloaded.notes.single.templateData,
      );
      expect(restoredDocument.childrenOf('phase-1').single.id, 'phase-2');
      expect(restoredDocument.childrenOf('phase-2').single.id, 'task-1');
      expect(restoredDocument.childrenOf('phase-2').single.completed, isTrue);

      await imported.importBundle(exported);
      final importedDocument = PlanDocument.fromJson(
        imported.notes.single.templateData,
      );
      expect(importedDocument.childrenOf('phase-1').single.id, 'phase-2');
      expect(importedDocument.childrenOf('phase-2').single.id, 'task-1');
    } finally {
      reloaded.dispose();
      imported.dispose();
    }
  });

  test('nested plan progress uses task and phase weights recursively', () {
    final document = PlanDocument(
      nodes: [
        PlanNode(
          id: 'phase-a',
          title: '階段 A',
          type: PlanNodeType.phase,
          weight: 3,
        ),
        PlanNode(
          id: 'phase-b',
          title: '階段 B',
          type: PlanNodeType.phase,
          weight: 1,
        ),
        PlanNode(
          id: 'task-a1',
          title: 'A1',
          type: PlanNodeType.task,
          parentId: 'phase-a',
          completed: true,
          weight: 1,
        ),
        PlanNode(
          id: 'task-a2',
          title: 'A2',
          type: PlanNodeType.task,
          parentId: 'phase-a',
          weight: 3,
        ),
        PlanNode(
          id: 'task-b1',
          title: 'B1',
          type: PlanNodeType.task,
          parentId: 'phase-b',
          completed: true,
        ),
      ],
    );

    expect(document.progressOf('phase-a'), closeTo(0.25, 0.001));
    expect(document.progressOf('phase-b'), 1);
    expect(document.progressOf(null), closeTo(0.4375, 0.001));
  });

  testWidgets('plan task metadata updates weight priority and home choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    var document = PlanDocument(
      nodes: [
        PlanNode(id: 'metadata-task', title: '設定任務', type: PlanNodeType.task),
      ],
    );
    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => PlanTreeEditor(
                  document: document,
                  onChanged: (value) => setState(() => document = value),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('設定任務'));
      await tester.pumpAndSettle();
      expect(find.text('任務設定'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '2.5');
      await tester.tap(find.text('高'));
      await tester.tap(find.text('顯示於首頁待辦'));
      await tester.tap(find.byTooltip('儲存'));
      await tester.pumpAndSettle();

      final task = document.nodes.single;
      expect(task.weight, 2.5);
      expect(task.priority, 3);
      expect(task.showOnHome, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  test('home plan tasks are derived and toggle the source node', () {
    final store = AppStore.seeded(persistenceLocked: true);
    final note = NoteItem(
      id: 'home-plan',
      title: '首頁計畫',
      body: '',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      templateType: NoteTemplateType.plan,
      templateData: PlanDocument(
        nodes: [
          PlanNode(
            id: 'shown-task',
            title: '首頁顯示',
            type: PlanNodeType.task,
            showOnHome: true,
          ),
          PlanNode(id: 'hidden-task', title: '不顯示', type: PlanNodeType.task),
        ],
      ).toJson(),
    );
    try {
      store.upsertNote(note);
      final tasks = activePlanHomeTasks(store);
      expect(tasks.map((item) => item.task.title), ['首頁顯示']);

      togglePlanHomeTask(store, tasks.single);
      expect(activePlanHomeTasks(store), isEmpty);
      expect(
        PlanDocument.fromJson(
          store.notes.single.templateData,
        ).nodes.first.completed,
        isTrue,
      );
    } finally {
      store.dispose();
    }
  });

  test('local export validates and restores a complete snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final source = AppStore.seeded(persistenceLocked: true);
    source.upsertTodo(TodoItem(id: 'export-todo', title: '匯出待辦'));
    source.upsertSchedule(
      ScheduleItem(
        id: 'export-schedule',
        title: '匯出行程',
        start: DateTime(2026, 9, 22, 9),
        end: DateTime(2026, 9, 22, 10),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      ),
    );
    final raw = await source.exportBundle();
    final decoded = LocalDataBundle.decode(raw);
    expect(decoded.schema, LocalDataBundle.schemaName);

    final restored = AppStore.seeded(persistenceLocked: true);
    final result = await restored.importBundle(raw);
    expect(result.todoCount, 1);
    expect(result.scheduleCount, 1);
    expect(restored.todos.single.title, '匯出待辦');
    expect(restored.schedules.single.title, '匯出行程');

    source.dispose();
    restored.dispose();
  });

  test('web downloads are treated as successful when picker returns null', () {
    expect(
      resolveSavedFileLocation(
        isWeb: true,
        fileName: 'my_note.json',
        platformLocation: null,
      ),
      'my_note.json',
    );
    expect(
      resolveSavedFileLocation(
        isWeb: false,
        fileName: 'my_note.json',
        platformLocation: null,
      ),
      isNull,
    );
  });

  test(
    'invalid local import leaves the current in-memory data unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore.seeded(persistenceLocked: true);
      store.upsertTodo(TodoItem(id: 'keep-todo', title: '保留原有待辦'));

      await expectLater(
        store.importBundle('{"schema":"unsupported","data":{}}'),
        throwsA(isA<FormatException>()),
      );

      expect(store.todos, hasLength(1));
      expect(store.todos.single.title, '保留原有待辦');
      store.dispose();
    },
  );

  group('local import integrity validation', () {
    String bundle(Map<String, dynamic> changes) {
      final data = <String, dynamic>{
        'notes': <Object?>[],
        'schedules': <Object?>[],
        'subscriptions': <Object?>[],
        'financeEntries': <Object?>[],
        'savingsAccounts': <Object?>[],
        'todos': <Object?>[],
        'noteFolders': <Object?>[],
        ...changes,
      };
      return jsonEncode({
        'schema': LocalDataBundle.schemaName,
        'createdAt': DateTime(2026, 9, 23).toIso8601String(),
        'data': data,
      });
    }

    test('rejects duplicate IDs, invalid folders, dates, and numbers', () {
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'todos': [
              {'id': 'same'},
              {'id': 'same'},
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'noteFolders': ['valid', 'bad//child'],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'schedules': [
              {
                'id': 'schedule-1',
                'start': 'not-a-date',
                'end': '2026-09-23T11:00:00.000',
              },
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'financeEntries': [
              {
                'id': 'finance-1',
                'date': '2026-09-23T11:00:00.000',
                'amount': 'not-a-number',
              },
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects broken plan references and cycles', () {
      Map<String, dynamic> plan(List<Map<String, dynamic>> nodes) => {
        'id': 'plan-note',
        'templateType': 'plan',
        'templateData': {'schema': PlanDocument.schema, 'nodes': nodes},
      };

      expect(
        () => LocalDataBundle.decode(
          bundle({
            'notes': [
              plan([
                {'id': 'phase-a', 'type': 'phase', 'parentId': 'phase-b'},
                {'id': 'phase-b', 'type': 'phase', 'parentId': 'phase-a'},
              ]),
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'notes': [
              plan([
                {
                  'id': 'task-a',
                  'type': 'task',
                  'linkedTodoId': 'missing-todo',
                },
              ]),
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects mind-map canvas links to missing nodes', () {
      expect(
        () => LocalDataBundle.decode(
          bundle({
            'notes': [
              {
                'id': 'mind-note',
                'templateType': 'mindMap',
                'templateData': {
                  'schema': MindMapDocument.schema,
                  'rootNodeId': 'root',
                  'nodes': [
                    {'id': 'root', 'x': 0, 'y': 0},
                  ],
                  'connections': [
                    {
                      'id': 'line-1',
                      'fromNodeId': 'root',
                      'toNodeId': 'missing',
                    },
                  ],
                },
              },
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects a missing life-sheet account without changing live data',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = AppStore.seeded(persistenceLocked: true);
        store.upsertTodo(TodoItem(id: 'keep', title: '保留'));

        await expectLater(
          store.importBundle(
            bundle({
              'notes': [
                {
                  'id': 'life-note',
                  'templateType': 'lifeSheet',
                  'templateData': {
                    'schema': LifeProjectDocument.schema,
                    'items': [
                      {
                        'id': 'item-1',
                        'accountIds': ['missing-account'],
                      },
                    ],
                  },
                },
              ],
            }),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(store.todos.single.id, 'keep');
        store.dispose();
      },
    );
  });

  test(
    'typed record links deduplicate and round-trip through export',
    () async {
      SharedPreferences.setMockInitialValues({});
      final source = AppStore.seeded(persistenceLocked: true);
      final now = DateTime(2026, 9, 23, 9);
      const noteLink = RelatedItemLink(
        type: RelatedItemType.note,
        targetId: 'note-general',
      );
      for (final note in <NoteItem>[
        NoteItem(
          id: 'note-general',
          title: '筆記',
          body: '',
          category: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
          links: const [noteLink, noteLink],
        ),
        NoteItem(
          id: 'note-plan',
          title: '計畫',
          body: '',
          category: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.plan,
        ),
        NoteItem(
          id: 'note-mind',
          title: '心智圖',
          body: '',
          category: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.mindMap,
        ),
        NoteItem(
          id: 'note-life',
          title: '人生試算表',
          body: '',
          category: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.lifeSheet,
        ),
      ]) {
        source.upsertNote(note);
      }
      source.upsertSchedule(
        ScheduleItem(
          id: 'schedule',
          title: '行程',
          start: now,
          end: now.add(const Duration(hours: 1)),
          location: '',
          notes: '',
          remindBeforeMinutes: 10,
          links: const [noteLink],
        ),
      );
      source.upsertSubscription(
        SubscriptionItem(
          id: 'subscription',
          name: '訂閱',
          amount: 100,
          cycle: SubscriptionCycle.monthly,
          nextPaymentDate: now,
          paymentMethod: '',
          category: '',
          reminderDays: 3,
          links: const [noteLink],
        ),
      );
      source.upsertFinanceEntry(
        FinanceEntry(
          id: 'finance',
          type: EntryType.expense,
          title: '記帳',
          amount: 10,
          category: '',
          account: 'account',
          date: now,
          note: '',
          links: const [noteLink],
        ),
      );
      source.upsertSavingsAccount(
        SavingsAccount(
          id: 'account',
          name: '帳戶',
          amount: 1000,
          links: const [noteLink],
        ),
      );
      source.upsertTodo(
        TodoItem(
          id: 'todo',
          title: '待辦',
          links: const [
            noteLink,
            RelatedItemLink(type: RelatedItemType.plan, targetId: 'note-plan'),
            RelatedItemLink(
              type: RelatedItemType.mindMap,
              targetId: 'note-mind',
            ),
            RelatedItemLink(
              type: RelatedItemType.lifeProject,
              targetId: 'note-life',
            ),
            RelatedItemLink(type: RelatedItemType.todo, targetId: 'todo'),
            RelatedItemLink(
              type: RelatedItemType.schedule,
              targetId: 'schedule',
            ),
            RelatedItemLink(type: RelatedItemType.finance, targetId: 'finance'),
            RelatedItemLink(
              type: RelatedItemType.subscription,
              targetId: 'subscription',
            ),
            RelatedItemLink(type: RelatedItemType.account, targetId: 'account'),
          ],
        ),
      );

      final restored = AppStore.seeded(persistenceLocked: true);
      await restored.importBundle(await source.exportBundle());

      expect(
        restored.notes.firstWhere((note) => note.id == 'note-general').links,
        hasLength(1),
      );
      expect(restored.schedules.single.links.single.targetId, 'note-general');
      expect(
        restored.subscriptions.single.links.single.targetId,
        'note-general',
      );
      expect(
        restored.financeEntries.single.links.single.targetId,
        'note-general',
      );
      expect(
        restored.savingsAccounts.single.links.single.targetId,
        'note-general',
      );
      expect(
        restored.todos.single.links,
        hasLength(RelatedItemType.values.length),
      );

      source.dispose();
      restored.dispose();
    },
  );

  test('related item index searches records and resolves reverse links', () {
    final store = AppStore.seeded();
    final todo = TodoItem(id: 'todo-index', title: '預約牙醫');
    final note = NoteItem(
      id: 'note-index',
      title: '健康計畫',
      body: '',
      category: '生活',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      links: const [
        RelatedItemLink(type: RelatedItemType.todo, targetId: 'todo-index'),
      ],
    );
    store.upsertTodo(todo);
    store.upsertNote(note);

    try {
      final matches = store.relatedItemCandidates(query: '牙醫');
      expect(matches, hasLength(1));
      expect(matches.single.link.type, RelatedItemType.todo);
      expect(
        store
            .relatedItemCandidates(
              exclude: const RelatedItemLink(
                type: RelatedItemType.note,
                targetId: 'note-index',
              ),
            )
            .map((item) => item.id),
        isNot(contains('note-index')),
      );
      const todoLink = RelatedItemLink(
        type: RelatedItemType.todo,
        targetId: 'todo-index',
      );
      expect(store.reverseLinksTo(todoLink).single.title, '健康計畫');
      expect(store.describeRelatedItem(todoLink)?.title, '預約牙醫');
      const noteLink = RelatedItemLink(
        type: RelatedItemType.note,
        targetId: 'note-index',
      );
      expect(store.relatedItemsFrom(noteLink).single.title, '預約牙醫');
    } finally {
      store.dispose();
    }
  });

  test('recovery history lists a valid snapshot and restores it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.upsertTodo(TodoItem(id: 'backup-todo', title: '備份待辦'));
    await store.flushPersistence();

    final snapshots = await store.recoverySnapshots();
    expect(snapshots, isNotEmpty);
    expect(snapshots.first.todoCount, 1);

    store.todos.clear();
    final restored = await store.restoreRecoverySnapshot(snapshots.first);
    expect(restored.todoCount, 1);
    expect(store.todos.single.title, '備份待辦');
    store.dispose();
  });

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

  testWidgets('system back closes the home FAB before leaving home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();

    try {
      await tester.pumpWidget(MyNoteApp(store: store));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('快速新增'));
      await tester.pumpAndSettle();
      expect(find.text('新增筆記'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('新增筆記'), findsNothing);
      expect(find.text('是否退出？'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('system back returns a main section to home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();

    try {
      await tester.pumpWidget(MyNoteApp(store: store));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('筆記').last);
      await tester.pumpAndSettle();
      expect(find.text('所有筆記'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  test('notes fixed back route follows folder parents', () {
    expect(notesBackTarget('A/B/C'), 'A/B');
    expect(notesBackTarget('A/B'), 'A');
    expect(notesBackTarget('A'), '所有筆記');
    expect(notesBackTarget(''), '所有筆記');
    expect(notesBackTarget('所有筆記'), isNull);
    expect(notesBackTarget('A/B', showingTrash: true), '所有筆記');
  });

  test('notes only appear in their directly assigned folder', () {
    expect(noteBelongsToFolder('A', 'A'), isTrue);
    expect(noteBelongsToFolder('A/B', 'A/B'), isTrue);
    expect(noteBelongsToFolder('A/B', 'A'), isFalse);
    expect(noteBelongsToFolder('A/B/C', 'A'), isFalse);
    expect(noteBelongsToFolder('', ''), isTrue);
    expect(noteBelongsToFolder('A', ''), isFalse);
  });

  test('calendar period helpers preserve valid dates and week boundaries', () {
    expect(shiftCalendarMonth(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(
      shiftCalendarMonth(DateTime(2026, 12, 15), 1),
      DateTime(2027, 1, 15),
    );
    expect(calendarWeekStart(DateTime(2026, 7, 28)), DateTime(2026, 7, 26));
    expect(
      calendarPeriodLabel(CalendarViewMode.week, DateTime(2026, 7, 28)),
      '2026/7/26–2026/8/1',
    );
  });

  testWidgets('calendar arrows and horizontal swipe change visible month', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    final now = DateTime.now();
    final nextMonth = shiftCalendarMonth(now, 1);
    final followingMonth = shiftCalendarMonth(now, 2);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
      await tester.tap(find.byTooltip('下一個期間'));
      await tester.pumpAndSettle();
      expect(
        find.text('${nextMonth.year}年${nextMonth.month}月'),
        findsOneWidget,
      );

      await tester.drag(find.byType(MonthStrip), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(
        find.text('${followingMonth.year}年${followingMonth.month}月'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('${followingMonth.year}年${followingMonth.month}月'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CalendarMonthPickerDialog), findsOneWidget);

      final pickedMonth = followingMonth.month == 1 ? 2 : 1;
      await tester.tap(find.text('$pickedMonth月'));
      await tester.pumpAndSettle();
      expect(find.text('${followingMonth.year}年$pickedMonth月'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('calendar list shows all events without a period selector', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    final now = DateTime.now();
    final nextMonth = shiftCalendarMonth(now, 1);
    store.upsertSchedule(
      ScheduleItem(
        id: 'list-current-month',
        title: '本月行程',
        start: DateTime(now.year, now.month, 2, 10),
        end: DateTime(now.year, now.month, 2, 11),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      ),
    );
    store.upsertSchedule(
      ScheduleItem(
        id: 'list-next-month',
        title: '下月行程',
        start: DateTime(nextMonth.year, nextMonth.month, 2, 10),
        end: DateTime(nextMonth.year, nextMonth.month, 2, 11),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      ),
    );

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('清單'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPeriodSelector), findsNothing);
      expect(find.text('本月行程'), findsOneWidget);
      expect(find.text('下月行程'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('tapping the selected day again scrolls to daily schedule', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    final now = DateTime.now();
    final targetDay = now.day == 1 ? 2 : 1;
    final targetDate = DateTime(now.year, now.month, targetDay);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();

      final dayCell = find.byKey(
        ValueKey(
          'calendar-day-${targetDate.year}-${targetDate.month}-${targetDate.day}',
        ),
      );
      await tester.tap(dayCell);
      await tester.pumpAndSettle();

      await tester.tap(dayCell);
      await tester.pumpAndSettle();
      final addButton = find.byKey(
        const ValueKey('calendar-add-selected-date'),
      );
      final dailySchedule = find.text('當日行程 · ${formatDate(targetDate)}');
      final calendarBlock = find.byKey(
        const ValueKey('calendar-visible-period-block'),
      );
      final addButtonTop = tester.getTopLeft(addButton).dy;
      final dailyScheduleTop = tester.getTopLeft(dailySchedule).dy;

      expect(dayCell, findsNothing);
      expect(calendarBlock, findsNothing);
      expect(addButtonTop, greaterThanOrEqualTo(110));
      expect(addButtonTop, lessThan(220));
      expect(addButtonTop, lessThan(dailyScheduleTop));
      expect(dailySchedule, findsOneWidget);
      expect(dailyScheduleTop, lessThan(320));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('month calendar shows weekdays and event title inside day cell', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 7, 14);
    final events = List.generate(
      4,
      (index) => ScheduleItem(
        id: 'calendar-event-$index',
        title: ['專案進度會議', '需求確認', '設計審查', '不應顯示的第四項'][index],
        start: DateTime(2026, 7, 14, 10 + index),
        end: DateTime(2026, 7, 14, 11 + index),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: MonthStrip(
              events: events,
              selectedDate: selectedDate,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final weekday in const ['日', '一', '二', '三', '四', '五', '六']) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(find.text('專案進度會議'), findsOneWidget);
    expect(find.text('需求確認'), findsOneWidget);
    expect(find.text('設計審查'), findsOneWidget);
    expect(find.text('不應顯示的第四項'), findsNothing);
    expect(find.text('14'), findsOneWidget);

    final selectedCell = tester.widget<Container>(
      find.byKey(const ValueKey('calendar-day-2026-7-14')),
    );
    final selectedDecoration = selectedCell.decoration! as BoxDecoration;
    final selectedBorder = selectedDecoration.border! as Border;
    expect(selectedBorder.top.width, 2);

    final firstEventLabel = tester.widget<Container>(
      find.byKey(const ValueKey('calendar-event-calendar-event-0')),
    );
    final eventDecoration = firstEventLabel.decoration! as BoxDecoration;
    expect(eventDecoration.color, isNotNull);
    expect(eventDecoration.border, isNotNull);
    expect(tester.widget<Text>(find.text('專案進度會議')).maxLines, 1);

    final eventColumn = tester.widget<Column>(
      find.byKey(const ValueKey('calendar-events-2026-7-14')),
    );
    expect(eventColumn.mainAxisAlignment, MainAxisAlignment.center);
  });

  testWidgets('week calendar selected date uses an outline without a fill', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 7, 14);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekStrip(
            events: const [],
            selectedDate: selectedDate,
            onDateSelected: (_) {},
          ),
        ),
      ),
    );

    final selectedCell = tester.widget<Container>(
      find.byKey(const ValueKey('calendar-week-day-2026-7-14')),
    );
    final decoration = selectedCell.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(decoration.color, const Color(0xfff1f3ef));
    expect(border.top.width, 2);
    expect(
      border.top.color,
      Theme.of(tester.element(find.byType(WeekStrip))).colorScheme.primary,
    );
  });

  testWidgets('home schedule view opens the matching daily schedule section', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final eventDate = DateTime.now().add(const Duration(days: 1));
    store.upsertSchedule(
      ScheduleItem(
        id: 'home-jump-event',
        title: '首頁跳轉測試',
        start: DateTime(eventDate.year, eventDate.month, eventDate.day, 9),
        end: DateTime(eventDate.year, eventDate.month, eventDate.day, 10),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(MyNoteApp(store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '查看').first);
      await tester.pumpAndSettle();

      expect(find.text('當日行程 · ${formatDate(eventDate)}'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-add-selected-date')),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('home section counters use complete item totals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      9,
    );

    for (var index = 0; index < 5; index++) {
      store.upsertSchedule(
        ScheduleItem(
          id: 'count-event-$index',
          title: '計數行程 $index',
          start: start.add(Duration(minutes: index * 30)),
          end: start.add(Duration(minutes: index * 30 + 20)),
          location: '',
          notes: '',
          remindBeforeMinutes: 10,
        ),
      );
    }
    for (var index = 0; index < 2; index++) {
      store.upsertSubscription(
        SubscriptionItem(
          id: 'count-subscription-$index',
          name: '計數訂閱 $index',
          amount: 100,
          cycle: SubscriptionCycle.monthly,
          nextPaymentDate: targetDate,
          paymentMethod: '信用卡',
          category: '服務',
          reminderDays: 3,
        ),
      );
    }
    for (var index = 0; index < 3; index++) {
      store.upsertTodo(TodoItem(id: 'count-todo-$index', title: '計數待辦 $index'));
    }

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(MyNoteApp(store: store));
      await tester.pumpAndSettle();

      expect(homeSectionCount(store, HomeSectionId.schedule), 5);
      expect(homeSectionCount(store, HomeSectionId.subscriptions), 7);
      expect(homeSectionCount(store, HomeSectionId.todos), 3);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('section-count-今日行程')))
            .data,
        '5',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('section-count-即將到來')))
            .data,
        '7',
      );
      final scheduleSection = find.byType(ScheduleHomeSection);
      expect(
        find.descendant(of: scheduleSection, matching: find.text('計數行程 0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: scheduleSection, matching: find.text('計數行程 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: scheduleSection, matching: find.text('計數行程 2')),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('section-count-待辦事項')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('section-count-待辦事項')))
            .data,
        '3',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  test('upcoming aggregation follows source edits and hidden state', () {
    final store = AppStore.seeded(persistenceLocked: true);
    final now = DateTime.now();
    final dueDate = DateTime(now.year, now.month, now.day + 2, 9);
    final todo = TodoItem(
      id: 'upcoming-source-todo',
      title: '原始待辦標題',
      dueDate: dueDate,
    );
    final schedule = ScheduleItem(
      id: 'upcoming-source-schedule',
      title: '近期行程',
      start: dueDate.add(const Duration(hours: 1)),
      end: dueDate.add(const Duration(hours: 2)),
      location: '',
      notes: '',
      remindBeforeMinutes: 10,
    );
    final subscription = SubscriptionItem(
      id: 'upcoming-source-subscription',
      name: '近期訂閱',
      amount: 199,
      cycle: SubscriptionCycle.monthly,
      nextPaymentDate: dueDate,
      paymentMethod: '信用卡',
      category: '服務',
      reminderDays: 3,
    );

    try {
      store.upsertTodo(todo);
      store.upsertSchedule(schedule);
      store.upsertSubscription(subscription);

      expect(upcomingHomeItems(store), hasLength(3));
      expect(homeSectionCount(store, HomeSectionId.subscriptions), 3);

      store.upsertTodo(
        TodoItem(id: todo.id, title: '修改後待辦標題', dueDate: dueDate),
      );
      expect(
        upcomingHomeItems(
          store,
        ).singleWhere((item) => item.key == upcomingTodoKey(todo)).title,
        '修改後待辦標題',
      );

      store.setUpcomingItemHidden(upcomingScheduleKey(schedule), true);
      expect(upcomingHomeItems(store), hasLength(2));
      final allItems = upcomingHomeItems(store, includeHidden: true);
      expect(allItems, hasLength(3));
      expect(
        allItems
            .singleWhere((item) => item.key == upcomingScheduleKey(schedule))
            .hidden,
        isTrue,
      );

      store.deleteSubscription(subscription);
      expect(upcomingHomeItems(store, includeHidden: true), hasLength(2));
    } finally {
      store.dispose();
    }
  });

  test(
    'upcoming aggregation includes each dated incomplete plan task once',
    () {
      final store = AppStore.seeded(persistenceLocked: true);
      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month, now.day + 3, 9);
      final linkedTodo = TodoItem(
        id: 'linked-plan-todo',
        title: '相同的連結待辦',
        dueDate: dueDate,
      );
      final plan = NoteItem(
        id: 'upcoming-plan',
        title: '旅行計畫',
        body: '',
        category: '',
        tags: const [],
        createdAt: now,
        updatedAt: now,
        templateType: NoteTemplateType.plan,
        templateData: PlanDocument(
          nodes: [
            PlanNode(
              id: 'dated-task',
              title: '預訂住宿',
              type: PlanNodeType.task,
              dueDate: dueDate,
              linkedTodoId: linkedTodo.id,
            ),
            PlanNode(
              id: 'completed-task',
              title: '已完成',
              type: PlanNodeType.task,
              completed: true,
              dueDate: dueDate,
            ),
            PlanNode(
              id: 'undated-task',
              title: '沒有期限',
              type: PlanNodeType.task,
            ),
          ],
        ).toJson(),
      );

      try {
        store.upsertTodo(linkedTodo);
        store.upsertNote(plan);

        final items = upcomingHomeItems(store);
        expect(items, hasLength(1));
        expect(
          items.single.key,
          upcomingPlanTaskKey(
            plan,
            PlanDocument.fromJson(plan.templateData).nodes.first,
          ),
        );
        expect(items.single.title, '預訂住宿');
        expect(items.single.typeLabel, '計畫任務');
        expect(items.single.sourceNote, same(plan));
      } finally {
        store.dispose();
      }
    },
  );

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

  testWidgets('editing a legacy plan saves v2 without losing legacy values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final legacyPlan = NoteItem(
      id: 'legacy-plan-editor',
      title: '舊計畫',
      body: '',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      templateType: NoteTemplateType.plan,
      templateData: {
        'schema': 'plan.v1',
        'goal': '完成遷移',
        'phase': '準備階段',
        'tasks': [
          {'title': '盤點舊資料', 'done': true},
          {'title': '寫入新版', 'done': false},
        ],
        'startDate': '2026-09-01T00:00:00.000',
        'dueDate': '2026-10-01T00:00:00.000',
        'spentHours': 6.5,
        'notes': '這段不能消失',
      },
    );
    store.upsertNote(legacyPlan);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: legacyPlan)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('完成遷移'), findsOneWidget);
      expect(find.text('準備階段'), findsOneWidget);
      expect(find.textContaining('盤點舊資料'), findsOneWidget);
      expect(find.text('這段不能消失'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '舊計畫（已編輯）');
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      final saved = store.notes.single;
      expect(saved.templateData['schema'], PlanDocument.schema);
      final migrated = PlanDocument.fromJson(saved.templateData);
      expect(migrated.goal, '完成遷移');
      expect(
        migrated.nodes.map((node) => node.title),
        containsAll(<String>['準備階段', '盤點舊資料', '寫入新版']),
      );
      expect(
        migrated.nodes.singleWhere((node) => node.title == '盤點舊資料').completed,
        isTrue,
      );
      expect(migrated.startDate, DateTime(2026, 9));
      expect(migrated.dueDate, DateTime(2026, 10));
      expect(migrated.spentHours, 6.5);
      expect(migrated.notes, '這段不能消失');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('editing a legacy mind map saves v2 without losing nodes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final legacyMindMap = NoteItem(
      id: 'legacy-mind-map-editor',
      title: '舊心智圖',
      body: '',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      templateType: NoteTemplateType.mindMap,
      templateData: {
        'schema': 'mind_map.v1',
        'topic': '產品中心',
        'nodes': [
          {
            'title': '產品中心',
            'subtitle': '核心',
            'description': '中心說明',
            'x': 25.0,
            'y': 30.0,
            'color': '#7C8B5F',
            'expanded': true,
          },
          {
            'title': '分支節點',
            'subtitle': '細節',
            'description': '分支說明',
            'x': 180.0,
            'y': 80.0,
            'color': '#8B2F2F',
            'expanded': false,
          },
        ],
      },
    );
    store.upsertNote(legacyMindMap);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: legacyMindMap)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('產品中心'), findsWidgets);
      expect(find.textContaining('分支節點'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '舊心智圖（已編輯）');
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      final saved = store.notes.single;
      expect(saved.templateData['schema'], MindMapDocument.schema);
      final migrated = MindMapDocument.fromJson(saved.templateData);
      expect(migrated.nodes, hasLength(2));
      expect(migrated.nodes.first.subtitle, '核心');
      expect(migrated.nodes.last.description, '分支說明');
      expect(migrated.nodes.last.x, 180);
      expect(migrated.nodes.last.y, 80);
      expect(migrated.nodes.last.color, '#8B2F2F');
      expect(migrated.nodes.last.expanded, isFalse);
      expect(
        migrated.nodes
            .singleWhere((node) => node.id == migrated.rootNodeId)
            .title,
        '產品中心',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('editing a legacy life sheet saves v2 without losing values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final legacyLifeSheet = NoteItem(
      id: 'legacy-life-sheet-editor',
      title: '舊人生試算表',
      body: '',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      templateType: NoteTemplateType.lifeSheet,
      templateData: {
        'schema': 'life_sheet.v1',
        'completed': true,
        'linkedPlanIds': ['plan-a'],
        'items': [
          {
            'name': '專案基金',
            'targetAmount': 100000,
            'currentAmount': 25000,
            'actualCost': 6000,
          },
          {'name': '整理作品集', 'displayMode': 'progress', 'progress': 0.6},
        ],
        'startDate': '2026-09-01T00:00:00.000',
        'dueDate': '2027-03-01T00:00:00.000',
        'spentHours': 18.5,
        'notes': '保留舊人生專案備註',
      },
    );
    store.upsertNote(legacyLifeSheet);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: legacyLifeSheet)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('專案基金 | 金錢'), findsOneWidget);
      expect(find.textContaining('整理作品集 | 完成率'), findsOneWidget);
      expect(find.text('保留舊人生專案備註'), findsOneWidget);
      expect(store.notes.single.templateData['schema'], 'life_sheet.v1');

      await tester.enterText(find.byType(TextField).first, '舊人生試算表（已編輯）');
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      final saved = store.notes.single;
      expect(saved.templateData['schema'], LifeProjectDocument.schema);
      expect(jsonEncode(saved.templateData), isNot(contains('actualCost')));
      final migrated = LifeProjectDocument.fromJson(saved.templateData);
      expect(migrated.status, LifeProjectStatus.completed);
      expect(migrated.linkedPlanIds, ['plan-a']);
      expect(migrated.startDate, DateTime(2026, 9));
      expect(migrated.targetDate, DateTime(2027, 3));
      expect(migrated.spentHours, 18.5);
      expect(migrated.notes, '保留舊人生專案備註');
      expect(migrated.items, hasLength(2));
      expect(migrated.items.first.targetAmount, 100000);
      expect(migrated.items.first.manualCurrentAmount, 25000);
      expect(migrated.items.last.displayMode, LifeItemDisplayMode.progress);
      expect(migrated.items.last.progress, 0.6);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('mind map canvas adds moves locks and collapses nodes', (
    tester,
  ) async {
    var document = MindMapDocument(
      rootNodeId: 'root',
      nodes: [MindMapNode(id: 'root', title: '中心', x: 20, y: 20)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MindMapCanvasEditor(
              document: document,
              onChanged: (value) => setState(() => document = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('新增子節點'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '分支');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();

    final child = document.nodes.singleWhere((node) => node.title == '分支');
    expect(child.parentId, 'root');
    final originalPosition = Offset(child.x, child.y);

    await tester.tap(find.byTooltip('鎖定節點'));
    await tester.pump();
    expect(child.locked, isTrue);
    await tester.drag(find.text('分支'), const Offset(80, 60));
    await tester.pump();
    expect(Offset(child.x, child.y), originalPosition);

    await tester.tap(find.byTooltip('解除鎖定'));
    await tester.pump();
    await tester.drag(find.text('分支'), const Offset(80, 60));
    await tester.pump();
    expect(child.x, greaterThan(originalPosition.dx));
    expect(child.y, greaterThan(originalPosition.dy));

    await tester.tap(find.text('中心'));
    await tester.pump();
    await tester.tap(find.byTooltip('收合子節點'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('分支'), findsNothing);
    expect(
      document.nodes.singleWhere((node) => node.id == 'root').expanded,
      isFalse,
    );
  });

  testWidgets('mind map free connections edit and clean up with nodes', (
    tester,
  ) async {
    var document = MindMapDocument(
      rootNodeId: 'root',
      nodes: [
        MindMapNode(id: 'root', title: '中心', x: 20, y: 20),
        MindMapNode(
          id: 'branch',
          title: '分支',
          parentId: 'root',
          x: 260,
          y: 160,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MindMapCanvasEditor(
              document: document,
              onChanged: (value) => setState(() => document = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('建立自由連線'));
    await tester.pump();
    expect(find.text('請點選另一個節點以建立自由連線'), findsOneWidget);
    await tester.tap(find.text('分支'));
    await tester.pump();
    expect(document.connections, hasLength(1));
    expect(
      find.byKey(const ValueKey('mind-map-connection-toolbar')),
      findsOneWidget,
    );

    await tester.tap(find.text('虛線'));
    await tester.pump();
    await tester.tap(find.byTooltip('顯示方向箭頭'));
    await tester.pump();
    await tester.tap(find.byTooltip('連線顏色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('藍色'));
    await tester.pumpAndSettle();
    expect(document.connections.single.style, MindMapLineStyle.dashed);
    expect(document.connections.single.directed, isTrue);
    expect(document.connections.single.color, '#2563EB');

    await tester.tap(find.byTooltip('完成連線編輯'));
    await tester.pump();
    await tester.tap(find.byTooltip('管理自由連線'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中心 → 分支'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mind-map-connection-toolbar')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('刪除自由連線'));
    await tester.pump();
    expect(document.connections, isEmpty);
    await tester.tap(find.text('中心'));
    await tester.pump();
    await tester.tap(find.byTooltip('建立自由連線'));
    await tester.pump();
    await tester.tap(find.text('分支'));
    await tester.pump();
    await tester.tap(find.byTooltip('刪除節點'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(document.nodes.where((node) => node.id == 'branch'), isEmpty);
    expect(document.connections, isEmpty);
  });

  test('mind map auto layout preserves root and locked nodes', () {
    final document = MindMapDocument(
      rootNodeId: 'root',
      nodes: [
        MindMapNode(id: 'root', title: '中心', x: 120, y: 220),
        MindMapNode(
          id: 'locked',
          title: '鎖定',
          parentId: 'root',
          x: 430,
          y: 510,
          locked: true,
        ),
        MindMapNode(id: 'child', title: '子節點', parentId: 'root', x: 10, y: 10),
        MindMapNode(id: 'free', title: '未連接', x: 20, y: 20),
      ],
    );

    autoLayoutMindMap(document);

    final root = document.nodes.singleWhere((node) => node.id == 'root');
    final locked = document.nodes.singleWhere((node) => node.id == 'locked');
    final child = document.nodes.singleWhere((node) => node.id == 'child');
    final free = document.nodes.singleWhere((node) => node.id == 'free');
    expect(Offset(root.x, root.y), const Offset(120, 220));
    expect(Offset(locked.x, locked.y), const Offset(430, 510));
    expect(Offset(child.x, child.y), isNot(const Offset(10, 10)));
    expect(Offset(free.x, free.y), isNot(const Offset(20, 20)));
    expect(child.x, free.x);
    expect(child.y, isNot(free.y));
  });

  test('mind map canvas state survives persistence reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final document = MindMapDocument(
      rootNodeId: 'root',
      nodes: [
        MindMapNode(id: 'root', title: '中心', x: 15, y: 25, expanded: false),
        MindMapNode(
          id: 'locked-child',
          title: '鎖定分支',
          parentId: 'root',
          x: 320,
          y: 180,
          locked: true,
        ),
      ],
      connections: [
        MindMapConnection(
          id: 'saved-line',
          fromNodeId: 'root',
          toNodeId: 'locked-child',
          color: '#2563EB',
          style: MindMapLineStyle.dashed,
          directed: true,
        ),
      ],
    );
    store.upsertNote(
      NoteItem(
        id: 'canvas-state',
        title: '畫布狀態',
        body: '',
        category: '',
        tags: const [],
        createdAt: DateTime(2026, 9, 24),
        updatedAt: DateTime(2026, 9, 24),
        templateType: NoteTemplateType.mindMap,
        templateData: document.toJson(),
      ),
    );
    await store.flushPersistence();
    store.dispose();

    final reloaded = await AppStore.load();
    try {
      final restored = MindMapDocument.fromJson(
        reloaded.notes.single.templateData,
      );
      final child = restored.nodes.singleWhere(
        (node) => node.id == 'locked-child',
      );
      expect(child.x, 320);
      expect(child.y, 180);
      expect(child.locked, isTrue);
      expect(restored.nodes.first.expanded, isFalse);
      expect(restored.connections, hasLength(1));
      expect(restored.connections.single.color, '#2563EB');
      expect(restored.connections.single.style, MindMapLineStyle.dashed);
      expect(restored.connections.single.directed, isTrue);
    } finally {
      reloaded.dispose();
    }
  });

  testWidgets('note editor selects and saves a related item', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = TodoItem(id: 'todo-related-ui', title: '預約牙醫');
    final note = NoteItem(
      id: 'note-related-ui',
      title: '健康筆記',
      body: '追蹤健康安排',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
    );
    store.upsertTodo(todo);
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('關聯項目'));
      await tester.pumpAndSettle();
      expect(find.text('預約牙醫'), findsOneWidget);

      await tester.tap(find.text('預約牙醫'));
      await tester.pump();
      await tester.tap(find.byTooltip('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(store.notes.single.links, hasLength(1));
      expect(store.notes.single.links.single.type, RelatedItemType.todo);
      expect(store.notes.single.links.single.targetId, todo.id);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('related item details navigate through outgoing links', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = TodoItem(id: 'todo-details', title: '預約牙醫');
    final note = NoteItem(
      id: 'note-details',
      title: '健康計畫',
      body: '健康安排',
      category: '生活',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      links: const [
        RelatedItemLink(type: RelatedItemType.todo, targetId: 'todo-details'),
      ],
    );
    store.upsertTodo(todo);
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(
            home: RelatedItemDetailsPage(
              link: RelatedItemLink(
                type: RelatedItemType.note,
                targetId: 'note-details',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('關聯項目 (1)'), findsOneWidget);
      expect(find.text('引用此項目 (0)'), findsOneWidget);
      await tester.tap(find.text('預約牙醫'));
      await tester.pumpAndSettle();
      expect(find.text('引用此項目 (1)'), findsOneWidget);
      expect(find.text('健康計畫'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('relationship picker creates and selects a linked item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(
            home: RelatedItemPickerPage(initialLinks: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增並連結'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '繳交報告');
      await tester.tap(find.byTooltip('建立'));
      await tester.pumpAndSettle();

      expect(store.todos.single.title, '繳交報告');
      expect(find.text('繳交報告'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('relationship picker removes an existing link', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    store.upsertTodo(TodoItem(id: 'todo-remove-link', title: '取消關聯'));

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: const MaterialApp(
            home: RelatedItemPickerPage(
              initialLinks: [
                RelatedItemLink(
                  type: RelatedItemType.todo,
                  targetId: 'todo-remove-link',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('取消關聯'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('todo editor selects and saves a related note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = TodoItem(id: 'todo-editor-link', title: '安排回診');
    final note = NoteItem(
      id: 'note-editor-link',
      title: '健康紀錄',
      body: '回診資訊',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
    );
    store.upsertTodo(todo);
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: TodoEditorPage(todo: todo)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('關聯項目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('健康紀錄'));
      await tester.pump();
      await tester.tap(find.byTooltip('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('完成'));
      await tester.pumpAndSettle();

      expect(store.todos.single.links, hasLength(1));
      expect(store.todos.single.links.single.type, RelatedItemType.note);
      expect(store.todos.single.links.single.targetId, note.id);
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

  test('general rich note survives persistence and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = RichNoteTextController(
      text: '格式化內容$richNoteEmbedObject$richNoteEmbedObject',
      marks: const [
        RichNoteMark(
          start: 0,
          end: 3,
          attributes: {RichNoteAttribute.bold: true},
        ),
        RichNoteMark(
          start: 5,
          end: 6,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeImage,
            RichNoteAttribute.embedId: 'image-reload',
          },
        ),
        RichNoteMark(
          start: 6,
          end: 7,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeAttachment,
            RichNoteAttribute.embedId: 'attachment-reload',
          },
        ),
      ],
    );
    final images = <Map<String, dynamic>>[
      {'id': 'image-reload', 'name': 'photo.png', 'bytesBase64': 'AA=='},
    ];
    final attachments = <Map<String, dynamic>>[
      {'id': 'attachment-reload', 'name': 'notes.txt', 'bytesBase64': 'QQ=='},
    ];
    final store = await AppStore.load();
    final note = NoteItem(
      id: store.newId('n'),
      title: '重啟後保留格式',
      body: controller.text,
      category: '驗收',
      tags: const ['rich'],
      createdAt: DateTime(2026, 9, 24, 9),
      updatedAt: DateTime(2026, 9, 24, 9),
      templateData: generalNoteTemplateData(
        defaultNoteTemplateData(NoteTemplateType.general),
        controller,
        images,
        attachments,
      ),
      images: images,
      attachments: attachments,
    );

    store.upsertNote(note);
    await store.flushPersistence();
    store.dispose();
    controller.dispose();

    final reloaded = await AppStore.load();
    try {
      final restored = reloaded.notes.single;
      final seed = richNoteSeedFromTemplateData(
        restored.body,
        restored.templateData,
      );
      expect(restored.title, '重啟後保留格式');
      expect(restored.images.single['id'], 'image-reload');
      expect(restored.attachments.single['id'], 'attachment-reload');
      expect(seed.text, contains(richNoteEmbedObject));
      expect(
        seed.marks.any(
          (mark) => mark.attributes[RichNoteAttribute.bold] == true,
        ),
        isTrue,
      );
      expect(
        seed.marks.map((mark) => mark.attributes[RichNoteAttribute.embedType]),
        containsAll([richNoteEmbedTypeImage, richNoteEmbedTypeAttachment]),
      );
    } finally {
      reloaded.dispose();
    }
  });

  test('built-in note appearance themes meet text contrast requirements', () {
    for (final palette in builtInNoteAppearanceThemes.values) {
      expect(
        noteAppearanceContrastRatio(
          palette.foregroundHex,
          palette.backgroundHex,
        ),
        greaterThanOrEqualTo(4.5),
        reason: palette.label,
      );
    }
  });

  testWidgets('note appearance theme persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final note = NoteItem(
      id: 'note-appearance',
      title: '外觀測試',
      body: '有內容的筆記',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
    );
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外觀與背景'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '柔紙'));
      await tester.pump();
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(store.notes.single.background['appearanceTheme'], 'paper');
      expect(store.notes.single.background['color'], '#FFFDF5');
      expect(store.notes.single.style['color'], '#2D2923');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('clean appearance theme removes the background image', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final note = NoteItem(
      id: 'note-appearance-reset',
      title: '重設外觀',
      body: '有內容的筆記',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      style: {...defaultNoteStyle(), 'color': '#FFFFFF'},
      background: {
        ...defaultNoteBackground(),
        'appearanceTheme': 'custom',
        'type': 'image',
        'image': 'background.png',
        'imageBytesBase64':
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      },
    );
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外觀與背景'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '純白'));
      await tester.pump();
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(store.notes.single.background['appearanceTheme'], 'clean');
      expect(store.notes.single.background['imageBytesBase64'], isEmpty);
      expect(store.notes.single.style['color'], '#202522');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('optional cover and background images render and can be removed', (
    tester,
  ) async {
    const imageBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final note = NoteItem(
      id: 'note-images',
      title: '圖片外觀',
      body: '文字保持可讀',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
      background: {
        ...defaultNoteBackground(),
        'appearanceTheme': 'custom',
        'type': 'image',
        'image': 'background.png',
        'imageBytesBase64': imageBase64,
        'coverImage': 'cover.png',
        'coverImageBytesBase64': imageBase64,
      },
    );
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-cover-image')), findsOneWidget);
      final backgroundImage = effectiveNoteBackgroundImage(note.background);
      expect(backgroundImage, isNotNull);
      expect(backgroundImage!.opacity, lessThanOrEqualTo(0.2));

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外觀與背景'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('移除封面圖片'));
      await tester.tap(find.byTooltip('移除背景圖片'));
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-cover-image')), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(store.notes.single.background['imageBytesBase64'], isEmpty);
      expect(store.notes.single.background['coverImageBytesBase64'], isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('image picker selects and persists cover and background images', (
    tester,
  ) async {
    const imageBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    FilePicker.platform = _FakeImageFilePicker(base64Decode(imageBase64));
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded(persistenceLocked: true);
    final note = NoteItem(
      id: 'note-image-picker',
      title: '選擇圖片',
      body: '保留可讀文字',
      category: '',
      tags: const [],
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
    );
    store.upsertNote(note);

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外觀與背景'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('選擇封面圖片'));
      await tester.pump();
      await tester.tap(find.text('圖片'));
      await tester.pump();
      await tester.tap(find.text('選擇背景圖片'));
      await tester.pump();
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(store.notes.single.background['coverImage'], 'picked.png');
      expect(
        store.notes.single.background['coverImageBytesBase64'],
        imageBase64,
      );
      expect(store.notes.single.background['image'], 'picked.png');
      expect(store.notes.single.background['imageBytesBase64'], imageBase64);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
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

  test('rich toolbar font size wheel starts at 16', () {
    final values = RichToolbarFontSizeButton.wheelValuesFor(16);
    expect(values.first, 16);
    expect(values.where((value) => value <= 14), isEmpty);
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
    expect(find.text('14'), findsNothing);
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
        expect(prefs.getString('my_note_local_v1'), jsonEncode(store.toJson()));
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

  test(
    'app store prefers a newer checkpoint over a valid old primary',
    () async {
      Map<String, dynamic> state({
        required String folder,
        required int revision,
        required DateTime changedAt,
      }) {
        return {
          'notes': [],
          'schedules': [],
          'subscriptions': [],
          'financeEntries': [],
          'savingsAccounts': [],
          'todos': [],
          'noteFolders': [folder],
          '_persistence': {
            'revision': revision,
            'changedAt': changedAt.toIso8601String(),
            'action': 'folder.create:$folder',
          },
        };
      }

      final oldRaw = jsonEncode(
        state(folder: '舊資料夾', revision: 7, changedAt: DateTime(2026, 7, 28, 9)),
      );
      final checkpointRaw = jsonEncode(
        state(
          folder: '最新資料夾',
          revision: 8,
          changedAt: DateTime(2026, 7, 28, 10),
        ),
      );
      SharedPreferences.setMockInitialValues({
        'my_note_local_v1': oldRaw,
        'my_note_local_v1_checkpoint': checkpointRaw,
      });

      final store = await AppStore.load();
      final prefs = await SharedPreferences.getInstance();

      try {
        expect(store.noteFolders, ['最新資料夾']);
        expect(prefs.getString('my_note_local_v1'), jsonEncode(store.toJson()));
        expect(prefs.getString('my_note_local_v1'), contains('最新資料夾'));
      } finally {
        store.dispose();
      }
    },
  );

  test(
    'app store journals rapid mutations and reloads the latest revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await AppStore.load();
      final note = NoteItem(
        id: store.newId('n'),
        title: '立即保存筆記',
        body: '不能遺失',
        category: '重要資料',
        tags: const ['保存'],
        createdAt: DateTime(2026, 7, 28, 10),
        updatedAt: DateTime(2026, 7, 28, 10),
      );
      final schedule = ScheduleItem(
        id: store.newId('s'),
        title: '立即保存行程',
        start: DateTime(2026, 7, 29, 9),
        end: DateTime(2026, 7, 29, 10),
        location: '',
        notes: '',
        remindBeforeMinutes: 10,
      );

      store.createNoteFolder('重要資料');
      store.upsertNote(note);
      store.upsertSchedule(schedule);
      await store.flushPersistence();

      final prefs = await SharedPreferences.getInstance();
      final journal =
          jsonDecode(prefs.getString('my_note_local_v1_change_journal')!)
              as List;
      final actions = journal
          .whereType<Map>()
          .map((entry) => entry['action']?.toString())
          .toList();
      final reloaded = await AppStore.load();

      try {
        expect(actions.first, contains('schedule.upsert'));
        expect(actions, contains('folder.create:重要資料'));
        expect(
          actions.any((action) => action?.contains('note.upsert') ?? false),
          isTrue,
        );
        expect(reloaded.noteFolders, contains('重要資料'));
        expect(reloaded.notes.single.title, '立即保存筆記');
        expect(reloaded.schedules.single.title, '立即保存行程');
        final primary =
            jsonDecode(prefs.getString('my_note_local_v1')!)
                as Map<String, dynamic>;
        final persistence = primary['_persistence'] as Map<String, dynamic>;
        expect(persistence['revision'], 3);
      } finally {
        reloaded.dispose();
        store.dispose();
      }
    },
  );

  test(
    'a newer intentionally empty revision does not restore old content',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await AppStore.load();

      store.createNoteFolder('稍後刪除');
      store.deleteNoteFolder('稍後刪除');
      await store.flushPersistence();

      final reloaded = await AppStore.load();
      final prefs = await SharedPreferences.getInstance();
      try {
        expect(reloaded.noteFolders, isEmpty);
        final primary =
            jsonDecode(prefs.getString('my_note_local_v1')!)
                as Map<String, dynamic>;
        final persistence = primary['_persistence'] as Map<String, dynamic>;
        expect(persistence['revision'], 2);
        expect(persistence['action'], 'folder.delete:稍後刪除');
      } finally {
        reloaded.dispose();
        store.dispose();
      }
    },
  );

  test('legacy backup timestamp can outrank an older valid primary', () async {
    Map<String, dynamic> state(String folder) => {
      'notes': [],
      'schedules': [],
      'subscriptions': [],
      'financeEntries': [],
      'savingsAccounts': [],
      'todos': [],
      'noteFolders': [folder],
    };

    final primaryRaw = jsonEncode(state('舊主資料'));
    final newerHistoryRaw = jsonEncode(state('稍後新增的資料夾'));
    SharedPreferences.setMockInitialValues({
      'my_note_local_v1': primaryRaw,
      'my_note_local_v1_backup_history': jsonEncode([
        {
          'savedAt': DateTime(2026, 7, 28, 11).toIso8601String(),
          'raw': newerHistoryRaw,
        },
      ]),
    });

    final store = await AppStore.load();
    try {
      expect(store.noteFolders, ['稍後新增的資料夾']);
    } finally {
      store.dispose();
    }
  });

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
    expect(textField.cursorHeight, closeTo(28.0 * 1.5, 0.001));
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
        closeTo(16.0 * 1.5, 0.001),
      );

      controller.setInlineAttribute(RichNoteAttribute.fontSize, 30.0);
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).last).cursorHeight,
        closeTo(30.0 * 1.5, 0.001),
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

  testWidgets('note back closes image subtools before leaving the editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    final controller = RichNoteTextController(
      text: 'before\n$richNoteEmbedObject\nafter',
      marks: const [
        RichNoteMark(
          start: 7,
          end: 8,
          attributes: {
            RichNoteAttribute.embedType: richNoteEmbedTypeImage,
            RichNoteAttribute.embedId: 'image-back-test',
          },
        ),
      ],
    );
    final images = <Map<String, dynamic>>[
      {
        'id': 'image-back-test',
        'name': 'back-test.png',
        'width': 120.0,
        'height': 80.0,
        'alignment': NoteImageAlignment.center.name,
      },
    ];
    final note = NoteItem(
      id: 'note-back-test',
      title: '返回測試',
      body: controller.text,
      category: 'A/B',
      tags: const [],
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 19),
      templateData: generalNoteTemplateData(
        defaultNoteTemplateData(NoteTemplateType.general),
        controller,
        images,
        const [],
      ),
      images: images,
    );
    controller.dispose();

    try {
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(home: NoteEditorPage(note: note)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InlineRichImageBlock));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('框線顏色'));
      await tester.pumpAndSettle();
      expect(find.byType(RichToolbarColorChoiceButton), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ModernRichImageEditToolbar), findsOneWidget);
      expect(find.byType(RichToolbarColorChoiceButton), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ModernRichImageEditToolbar), findsNothing);
      expect(find.byType(RichTextTemplateToolbar), findsOneWidget);
      expect(find.byType(NoteEditorPage), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
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
