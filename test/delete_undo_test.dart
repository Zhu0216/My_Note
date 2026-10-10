import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/data/my_note_data.dart';
import 'package:my_note/ui/app_store_scope.dart';
import 'package:my_note/ui/shared_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodoItem _todo(String id, {List<RelatedItemLink>? links}) =>
    TodoItem(id: id, title: '待辦 $id', sortOrder: 1000, links: links);

ScheduleItem _schedule(String id) => ScheduleItem(
  id: id,
  title: '行程 $id',
  start: DateTime(2026, 10, 10, 9),
  end: DateTime(2026, 10, 10, 10),
  location: '',
  notes: '',
  remindBeforeMinutes: 30,
);

NoteItem _note(String id, {List<RelatedItemLink>? links}) => NoteItem(
  id: id,
  title: '筆記 $id',
  body: '內容',
  category: '專案',
  tags: const [],
  createdAt: DateTime(2026, 10, 10),
  updatedAt: DateTime(2026, 10, 10),
  links: links,
);

void main() {
  testWidgets('mixed consecutive deletes undo together in original order', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final first = _todo('t1');
    final second = _todo('t2');
    final event = _schedule('s1');
    final note = _note(
      'n1',
      links: const [
        RelatedItemLink(type: RelatedItemType.todo, targetId: 't2'),
      ],
    );
    store
      ..upsertTodo(first)
      ..upsertTodo(second)
      ..upsertSchedule(event)
      ..upsertNote(note);

    store.deleteTodo(first);
    await tester.pump(const Duration(seconds: 4));
    store
      ..deleteSchedule(event)
      ..deleteNoteFolder('專案');

    expect(store.pendingDeleteCount, 3);
    expect(store.todos.map((item) => item.id), ['t2']);
    expect(store.schedules, isEmpty);
    expect(store.noteFolders, isNot(contains('專案')));
    await tester.pump(const Duration(seconds: 2));
    expect(store.pendingDeleteCount, 3, reason: '第二次刪除必須重算五秒');

    store.undoPendingDeletes();
    expect(store.pendingDeleteCount, 0);
    expect(store.todos.map((item) => item.id), ['t1', 't2']);
    expect(store.schedules.single.id, 's1');
    expect(note.deletedAt, isNull);
    expect(note.category, '專案');
    expect(note.links.single.targetId, 't2');
    expect(store.noteFolders, contains('專案'));
    store.dispose();
  });

  testWidgets('expiry cleans incoming links after the latest five seconds', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = _todo('t1');
    final event = _schedule('s1');
    final note = _note(
      'n1',
      links: const [
        RelatedItemLink(type: RelatedItemType.todo, targetId: 't1'),
        RelatedItemLink(type: RelatedItemType.schedule, targetId: 's1'),
      ],
    );
    store
      ..upsertTodo(todo)
      ..upsertSchedule(event)
      ..upsertNote(note);

    store.deleteTodo(todo);
    await tester.pump(const Duration(seconds: 4));
    store.deleteSchedule(event);
    await tester.pump(const Duration(seconds: 4));
    expect(note.links, hasLength(2));

    await tester.pump(const Duration(seconds: 1));
    expect(store.pendingDeleteCount, 0);
    expect(note.links, isEmpty);
    store.dispose();
  });

  testWidgets('trashed note keeps links until permanent deletion', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final target = _note('target');
    final source = _note(
      'source',
      links: const [
        RelatedItemLink(type: RelatedItemType.note, targetId: 'target'),
      ],
    );
    store
      ..upsertNote(target)
      ..upsertNote(source);

    store.deleteNote(target);
    await tester.pump(AppStore.deleteUndoDuration);
    expect(source.links, hasLength(1));

    store.permanentlyDeleteNotesById({'target'});
    expect(source.links, isEmpty);
    store.dispose();
  });

  test('permanent deletion closes a pending note undo batch', () {
    final store = AppStore.seeded(persistenceLocked: true);
    final target = _note('target');
    final source = _note(
      'source',
      links: const [
        RelatedItemLink(type: RelatedItemType.note, targetId: 'target'),
      ],
    );
    store
      ..upsertNote(target)
      ..upsertNote(source)
      ..deleteNote(target);

    expect(store.pendingDeleteCount, 1);
    store.permanentlyDeleteNotesById({'target'});

    expect(store.pendingDeleteCount, 0);
    store.undoPendingDeletes();
    expect(store.notes.where((note) => note.id == 'target'), isEmpty);
    expect(source.links, isEmpty);
    store.dispose();
  });

  testWidgets('expiry clears typed links inside structured templates', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = _todo('t1');
    final plan = PlanDocument(
      nodes: [
        PlanNode(
          id: 'task-1',
          title: '關聯任務',
          type: PlanNodeType.task,
          linkedTodoId: 't1',
          links: const [
            RelatedItemLink(type: RelatedItemType.todo, targetId: 't1'),
          ],
        ),
      ],
    );
    final planNote = _note('plan')
      ..templateType = NoteTemplateType.plan
      ..templateData = plan.toJson();
    store
      ..upsertTodo(todo)
      ..upsertNote(planNote)
      ..deleteTodo(todo);

    await tester.pump(AppStore.deleteUndoDuration);

    final restored = PlanDocument.fromJson(planNote.templateData);
    expect(restored.nodes.single.linkedTodoId, isNull);
    expect(restored.nodes.single.links, isEmpty);
    store.dispose();
  });

  test(
    'startup finishes relationship cleanup after interrupted delete',
    () async {
      final source = AppStore.seeded(persistenceLocked: true)
        ..upsertNote(
          _note(
            'source',
            links: const [
              RelatedItemLink(type: RelatedItemType.todo, targetId: 'missing'),
            ],
          ),
        );
      SharedPreferences.setMockInitialValues({
        'my_note_local_v1': jsonEncode(source.toJson()),
      });
      source.dispose();

      final loaded = await AppStore.load(
        attachmentBlobStore: MemoryAttachmentBlobStore(),
      );
      expect(loaded.notes.single.links, isEmpty);
      loaded.dispose();
    },
  );

  testWidgets('swipe delete skips confirmation and exposes undo action', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final todo = _todo('t1');
    store.upsertTodo(todo);
    await tester.pumpWidget(
      AppStoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SwipeDeleteTile(
              itemKey: 'todo-t1',
              onDelete: () => store.deleteTodo(todo),
              child: const SizedBox(
                key: ValueKey('swipe-child'),
                width: 320,
                height: 72,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(
      tester.getCenter(find.byType(SwipeDeleteTile)),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('已刪除'), findsOneWidget);
    expect(find.text('復原'), findsOneWidget);
    expect(store.todos, isEmpty);

    tester.widget<SnackBar>(find.byType(SnackBar)).action!.onPressed();
    await tester.pump();
    expect(store.todos.single.id, 't1');
    expect(find.text('已復原刪除項目'), findsOneWidget);
    store.dispose();
  });

  testWidgets(
    'delete undo prompt expires and stale action cannot report undo',
    (tester) async {
      final store = AppStore.seeded(persistenceLocked: true);
      final todo = _todo('t1');
      store.upsertTodo(todo);
      await tester.pumpWidget(
        AppStoreScope(
          store: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPendingDeleteUndo(
                    context,
                    () => store.deleteTodo(todo),
                  ),
                  child: const Text('刪除'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('刪除'));
      await tester.pump();
      final staleUndo = tester.widget<SnackBar>(find.byType(SnackBar)).action!;
      expect(find.text('復原'), findsOneWidget);

      await tester.pump(AppStore.deleteUndoDuration);
      await tester.pump();
      expect(find.text('復原'), findsNothing);
      expect(store.pendingDeleteCount, 0);

      staleUndo.onPressed();
      await tester.pump();
      expect(find.textContaining('已復原'), findsNothing);
      expect(store.todos, isEmpty);
      store.dispose();
    },
  );

  testWidgets('consecutive delete replaces prompt before extending batch', (
    tester,
  ) async {
    final store = AppStore.seeded(persistenceLocked: true);
    final first = _todo('t1');
    final second = _todo('t2');
    store
      ..upsertTodo(first)
      ..upsertTodo(second);
    var next = 0;
    await tester.pumpWidget(
      AppStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPendingDeleteUndo(context, () {
                  store.deleteTodo(next++ == 0 ? first : second);
                }),
                child: const Text('刪除'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('刪除'));
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('刪除'));
    await tester.pump();

    expect(find.text('已刪除 2 個項目'), findsOneWidget);
    expect(find.text('復原'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('復原'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('復原'), findsNothing);
    expect(store.pendingDeleteCount, 0);
    store.dispose();
  });
}
