import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'v1 records survive restart and portable export import as one workflow',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month, now.day + 2);
      final source = AppStore.seeded();
      const todoLink = RelatedItemLink(
        type: RelatedItemType.todo,
        targetId: 'audit-todo',
      );

      source.upsertSavingsAccount(
        SavingsAccount(id: 'audit-account', name: '專案基金', openingBalance: 1000),
      );
      source.upsertFinanceEntry(
        FinanceEntry(
          id: 'audit-finance',
          type: EntryType.income,
          title: '儲蓄',
          amount: 500,
          category: '薪資',
          accountId: 'audit-account',
          date: now,
          note: '稽核記錄',
        ),
      );
      source.upsertTodo(
        TodoItem(
          id: 'audit-todo',
          title: '完成 v1 驗收',
          dueDate: dueDate,
          reminderEnabled: true,
          reminderTime: const TimeOfDay(hour: 18, minute: 30),
        ),
      );
      source.upsertSchedule(
        ScheduleItem(
          id: 'audit-schedule',
          title: '驗收會議',
          start: dueDate.add(const Duration(hours: 14)),
          end: dueDate.add(const Duration(hours: 15)),
          location: '線上',
          notes: '確認全功能',
          remindBeforeMinutes: 30,
        ),
      );
      source.upsertSubscription(
        SubscriptionItem(
          id: 'audit-subscription',
          name: '雲端工具',
          amount: 120,
          cycle: SubscriptionCycle.monthly,
          nextPaymentDate: dueDate.add(const Duration(days: 1)),
          paymentMethod: '信用卡',
          category: '工具',
          reminderDays: 1,
        ),
      );

      final plan = PlanDocument(
        goal: '完成 v1',
        nodes: [
          PlanNode(id: 'audit-phase', title: '驗收', type: PlanNodeType.phase),
          PlanNode(
            id: 'audit-task',
            title: '功能驗收',
            type: PlanNodeType.task,
            parentId: 'audit-phase',
            dueDate: dueDate,
            linkedTodoId: 'audit-todo',
            showOnHome: true,
          ),
        ],
      );
      final mindMap = MindMapDocument(
        rootNodeId: 'audit-root',
        nodes: [
          MindMapNode(id: 'audit-root', title: '記憶網'),
          MindMapNode(
            id: 'audit-child',
            title: '驗收資料',
            parentId: 'audit-root',
            x: 180,
          ),
        ],
        connections: [
          MindMapConnection(
            id: 'audit-line',
            fromNodeId: 'audit-root',
            toNodeId: 'audit-child',
            directed: true,
          ),
        ],
      );
      final lifeProject = LifeProjectDocument(
        notes: '離線 v1 目標',
        linkedPlanIds: ['audit-plan'],
        items: [
          LifeProjectItem(
            id: 'audit-money',
            name: '專案基金',
            targetAmount: 2000,
            accountIds: ['audit-account'],
          ),
        ],
      );
      for (final note in [
        NoteItem(
          id: 'audit-general',
          title: '一般筆記',
          body: '繁體中文內容',
          category: '驗收',
          tags: const ['v1'],
          createdAt: now,
          updatedAt: now,
          links: const [todoLink],
        ),
        NoteItem(
          id: 'audit-plan',
          title: '計畫',
          body: '',
          category: '驗收',
          tags: const ['v1'],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.plan,
          templateData: plan.toJson(),
        ),
        NoteItem(
          id: 'audit-mind',
          title: '心智圖',
          body: '',
          category: '驗收',
          tags: const ['v1'],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.mindMap,
          templateData: mindMap.toJson(),
        ),
        NoteItem(
          id: 'audit-life',
          title: '人生試算表',
          body: '',
          category: '驗收',
          tags: const ['v1'],
          createdAt: now,
          updatedAt: now,
          templateType: NoteTemplateType.lifeSheet,
          templateData: lifeProject.toJson(),
        ),
      ]) {
        source.upsertNote(note);
      }
      source.updateBudget(24000);
      source.toggleHomeSection(HomeSectionId.notes);
      source.setHomeSectionStyle(HomeSectionId.todos, HomeSectionStyle.grid);
      await source.flushPersistence();

      final restarted = await AppStore.load();
      expect(restarted.notes, hasLength(4));
      expect(
        restarted.notes.map((note) => note.templateType).toSet(),
        NoteTemplateType.values.toSet(),
      );
      expect(restarted.schedules.single.title, '驗收會議');
      expect(restarted.todos.single.title, '完成 v1 驗收');
      expect(restarted.subscriptions.single.name, '雲端工具');
      expect(restarted.accountBalance(restarted.savingsAccounts.single), 1500);
      expect(restarted.monthlyBudget, 24000);
      expect(restarted.collapsedHomeSections, contains(HomeSectionId.notes));
      expect(
        restarted.homeSectionStyles[HomeSectionId.todos],
        HomeSectionStyle.grid,
      );
      expect(buildLocalReminders(restarted, now: now), hasLength(3));
      expect(upcomingHomeItems(restarted), hasLength(3));
      expect(
        restarted
            .relatedItemsFrom(
              const RelatedItemLink(
                type: RelatedItemType.note,
                targetId: 'audit-general',
              ),
            )
            .single
            .id,
        'audit-todo',
      );

      final portable = await restarted.exportBundle();
      final imported = AppStore.seeded(persistenceLocked: true);
      final result = await imported.importBundle(portable);
      expect(result.noteCount, 4);
      expect(
        imported.notes.map((note) => note.title),
        containsAll(['一般筆記', '計畫', '心智圖', '人生試算表']),
      );
      expect(imported.accountBalance(imported.savingsAccounts.single), 1500);
      expect(buildLocalReminders(imported, now: now), hasLength(3));
      expect(imported.relatedItemCandidates(), hasLength(9));

      source.dispose();
      restarted.dispose();
      imported.dispose();
    },
  );
}
