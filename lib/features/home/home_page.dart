import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_navigation.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/basic_display.dart';
import '../../ui/display_components.dart';
import '../../ui/formatters.dart';
import '../../ui/shared_components.dart';
import '../../ui/todo_display.dart';

typedef HomeNoteEditor =
    Future<void> Function(BuildContext context, {NoteItem? note});
typedef HomeTodoEditor =
    Future<void> Function(BuildContext context, {TodoItem? todo});

class HomeFeatureActions {
  const HomeFeatureActions({
    required this.editNote,
    required this.editTodo,
    required this.showTodoActions,
    required this.editFinance,
    required this.editSubscription,
    required this.editSchedule,
  });

  final HomeNoteEditor editNote;
  final HomeTodoEditor editTodo;
  final Future<void> Function(BuildContext context, TodoItem todo)
  showTodoActions;
  final Future<void> Function(BuildContext context) editFinance;
  final Future<void> Function(BuildContext context) editSubscription;
  final Future<void> Function(BuildContext context) editSchedule;
}

class HomeFeatureActionsScope extends InheritedWidget {
  const HomeFeatureActionsScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final HomeFeatureActions actions;

  static HomeFeatureActions of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HomeFeatureActionsScope>();
    assert(scope != null, 'HomeFeatureActionsScope is missing.');
    return scope!.actions;
  }

  @override
  bool updateShouldNotify(HomeFeatureActionsScope oldWidget) =>
      actions != oldWidget.actions;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onNavigate, required this.actions});

  final ValueChanged<int> onNavigate;
  final HomeFeatureActions actions;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController quickAddFabController;
  bool quickAddOpen = false;

  @override
  void initState() {
    super.initState();
    quickAddFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    quickAddFabController.dispose();
    super.dispose();
  }

  void toggleQuickAdd() {
    if (quickAddOpen) {
      closeQuickAdd();
    } else {
      setState(() => quickAddOpen = true);
      quickAddFabController.forward();
    }
  }

  void closeQuickAdd() {
    if (!quickAddOpen) {
      return;
    }
    setState(() => quickAddOpen = false);
    quickAddFabController.reverse();
  }

  bool handleAppBack() {
    if (!quickAddOpen) {
      return false;
    }
    closeQuickAdd();
    return true;
  }

  Future<void> handleQuickAdd(String value) async {
    closeQuickAdd();
    switch (value) {
      case 'note':
        await widget.actions.editNote(context);
        break;
      case 'todo':
        await widget.actions.editTodo(context);
        break;
      case 'finance':
        await widget.actions.editFinance(context);
        break;
      case 'subscription':
        await widget.actions.editSubscription(context);
        break;
      case 'schedule':
        await widget.actions.editSchedule(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);

    return HomeFeatureActionsScope(
      actions: widget.actions,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionMenu(
          isOpen: quickAddOpen,
          controller: quickAddFabController,
          tooltip: '快速新增',
          onToggle: toggleQuickAdd,
          items: [
            FloatingActionMenuItem(
              icon: Icons.notes,
              label: '新增筆記',
              value: 'note',
              onSelected: handleQuickAdd,
            ),
            FloatingActionMenuItem(
              icon: Icons.add_task,
              label: '新增待辦事項',
              value: 'todo',
              onSelected: handleQuickAdd,
            ),
            FloatingActionMenuItem(
              icon: Icons.payments_outlined,
              label: '新增記帳',
              value: 'finance',
              onSelected: handleQuickAdd,
            ),
            FloatingActionMenuItem(
              icon: Icons.subscriptions_outlined,
              label: '新增訂閱費用',
              value: 'subscription',
              onSelected: handleQuickAdd,
            ),
            FloatingActionMenuItem(
              icon: Icons.event_note,
              label: '新增行程',
              value: 'schedule',
              onSelected: handleQuickAdd,
            ),
          ],
        ),
        body: DismissFabMenuLayer(
          isOpen: quickAddOpen,
          onDismiss: closeQuickAdd,
          child: AppPage(
            title: 'My Note',
            subtitle: 'All-in-one 個人管理筆記本',
            actions: [
              IconButton(
                tooltip: '調整首頁',
                onPressed: () => showHomeLayoutSettings(context),
                icon: const Icon(Icons.more_horiz),
              ),
            ],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final section in store.homeSectionOrder)
                  if (!store.hiddenHomeSections.contains(section))
                    HomeSection(
                      section: section,
                      onNavigate: widget.onNavigate,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.section,
    required this.onNavigate,
  });

  final HomeSectionId section;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final collapsed = store.collapsedHomeSections.contains(section);
    final style = store.homeSectionStyles[section] ?? HomeSectionStyle.list;

    if (section == HomeSectionId.todos) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TodoHomeSection(
          style: style,
          collapsed: collapsed,
          onToggleCollapsed: () => store.toggleHomeSection(section),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          SectionHeader(
            title: homeSectionTitle(section),
            count: homeSectionCount(store, section),
            onTap: () => store.toggleHomeSection(section),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                homeSectionAction(context, section, onNavigate),
                Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: collapsed
                ? const SizedBox.shrink(key: ValueKey('collapsed'))
                : KeyedSubtree(
                    key: ValueKey('${section.name}-${style.name}'),
                    child: buildHomeSectionContent(context, section, style),
                  ),
          ),
        ],
      ),
    );
  }
}

String homeSectionTitle(HomeSectionId section) {
  return switch (section) {
    HomeSectionId.metrics => '月結算',
    HomeSectionId.schedule => '今日行程',
    HomeSectionId.subscriptions => '即將到來',
    HomeSectionId.notes => '最近筆記',
    HomeSectionId.todos => '待辦事項',
  };
}

int? homeSectionCount(AppStore store, HomeSectionId section) {
  return switch (section) {
    HomeSectionId.schedule => homeScheduleEvents(store).length,
    HomeSectionId.subscriptions => upcomingHomeItems(store).length,
    HomeSectionId.todos => store.activeTodos.length,
    HomeSectionId.metrics || HomeSectionId.notes => null,
  };
}

Widget homeSectionAction(
  BuildContext context,
  HomeSectionId section,
  ValueChanged<int> onNavigate,
) {
  return switch (section) {
    HomeSectionId.metrics => const SizedBox.shrink(),
    HomeSectionId.schedule => TextButton.icon(
      onPressed: () {
        final store = AppStoreScope.read(context);
        AppNavigationScope.maybeOf(
          context,
        )?.onOpenCalendarDailySchedule(homeScheduleTargetDate(store));
      },
      icon: const Icon(Icons.chevron_right),
      label: const Text('查看'),
    ),
    HomeSectionId.subscriptions => TextButton.icon(
      onPressed: () => showUpcomingManager(context),
      icon: const Icon(Icons.open_in_new),
      label: const Text('管理'),
    ),
    HomeSectionId.notes => TextButton.icon(
      onPressed: () => onNavigate(0),
      icon: const Icon(Icons.chevron_right),
      label: const Text('查看'),
    ),
    HomeSectionId.todos => IconButton(
      tooltip: '新增待辦事項',
      onPressed: () => HomeFeatureActionsScope.of(context).editTodo(context),
      icon: const Icon(Icons.add_task),
    ),
  };
}

DateTime homeScheduleTargetDate(AppStore store) {
  final now = DateTime.now();
  final hasTodayEvent = store.schedules.any(
    (event) => isSameDate(event.start, now),
  );
  if (hasTodayEvent) {
    return now;
  }
  return store.upcomingSchedules.firstOrNull?.start ?? now;
}

List<ScheduleItem> homeScheduleEvents(AppStore store) {
  final targetDate = homeScheduleTargetDate(store);
  return store.schedules
      .where((event) => isSameDate(event.start, targetDate))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

Widget buildHomeSectionContent(
  BuildContext context,
  HomeSectionId section,
  HomeSectionStyle style,
) {
  return switch (section) {
    HomeSectionId.metrics => MetricsHomeSection(style: style),
    HomeSectionId.schedule => ScheduleHomeSection(style: style),
    HomeSectionId.subscriptions => UpcomingHomeSection(style: style),
    HomeSectionId.notes => NotesHomeSection(style: style),
    HomeSectionId.todos => TodoHomeSection(style: style),
  };
}

class MetricsHomeSection extends StatelessWidget {
  const MetricsHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = [
      MetricInfo(
        title: '本月收入',
        value: currency(store.monthlyIncome),
        icon: Icons.payments_outlined,
        color: const Color(0xffb5533d),
      ),
      MetricInfo(
        title: '本月支出',
        value: currency(store.monthlyExpense),
        icon: Icons.subscriptions_outlined,
        color: const Color(0xff3f5f99),
      ),
    ];

    return MetricSummaryRow(items: items, style: style);
  }
}

class ScheduleHomeSection extends StatelessWidget {
  const ScheduleHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final allEvents = homeScheduleEvents(store);
    final shownEvents = allEvents.take(2).toList();
    final eventLabel =
        allEvents.any((event) => isSameDate(event.start, DateTime.now()))
        ? '今日'
        : shownEvents.isEmpty
        ? '今日'
        : formatDate(shownEvents.first.start);

    if (shownEvents.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.event_available, text: '尚無行程'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final event in shownEvents)
            SizedBox(
              width: homeGridTileWidth(context),
              child: CompactInfoTile(
                icon: Icons.schedule,
                title: event.title,
                subtitle:
                    '$eventLabel\n${formatTime(event.start)} - ${formatTime(event.end)}',
                onTap: () => AppNavigationScope.maybeOf(
                  context,
                )?.onOpenCalendarDailySchedule(event.start),
              ),
            ),
        ],
      );
    }

    return InfoCard(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(eventLabel),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 4),
          for (final event in shownEvents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(event.title),
              subtitle: Text(
                '${formatTime(event.start)} - ${formatTime(event.end)}  ${event.location}',
              ),
              onTap: () => AppNavigationScope.maybeOf(
                context,
              )?.onOpenCalendarDailySchedule(event.start),
            ),
        ],
      ),
    );
  }
}

class UpcomingHomeSection extends StatelessWidget {
  const UpcomingHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = upcomingHomeItems(store).take(6).toList();
    if (items.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.event_available, text: '7 日內沒有即將到來的項目'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final item in items)
            SizedBox(
              width: homeGridTileWidth(context),
              child: CompactInfoTile(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                onTap: () => showUpcomingDetails(context, item),
              ),
            ),
        ],
      );
    }

    return InfoCard(
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: item.trailing == null
                    ? null
                    : Text(
                        item.trailing!,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                onTap: () => showUpcomingDetails(context, item),
              ),
            ),
        ],
      ),
    );
  }
}

class UpcomingHomeItem {
  const UpcomingHomeItem({
    required this.key,
    required this.date,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.details,
    required this.hidden,
    this.trailing,
    this.sourceNote,
  });

  final String key;
  final DateTime date;
  final IconData icon;
  final String title;
  final String subtitle;
  final String typeLabel;
  final String details;
  final bool hidden;
  final String? trailing;
  final NoteItem? sourceNote;
}

List<UpcomingHomeItem> upcomingHomeItems(
  AppStore store, {
  bool includeHidden = false,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final inSevenDays = today.add(const Duration(days: 8));
  final planItems = <UpcomingHomeItem>[];
  final linkedPlanTodoIds = <String>{};
  for (final note in store.notes.where(
    (note) =>
        note.deletedAt == null && note.templateType == NoteTemplateType.plan,
  )) {
    final document = PlanDocument.fromJson(note.templateData);
    for (final task in document.nodes.where(
      (node) =>
          node.type == PlanNodeType.task &&
          !node.completed &&
          node.dueDate != null &&
          isInUpcomingWindow(node.dueDate!, today, inSevenDays),
    )) {
      if (task.linkedTodoId != null) {
        linkedPlanTodoIds.add(task.linkedTodoId!);
      }
      final key = upcomingPlanTaskKey(note, task);
      if (includeHidden || !store.hiddenUpcomingItems.contains(key)) {
        planItems.add(
          UpcomingHomeItem(
            key: key,
            date: task.dueDate!,
            icon: Icons.flag_outlined,
            title: task.title,
            subtitle: '${formatDate(task.dueDate!)}  ${note.title}',
            typeLabel: '計畫任務',
            details:
                '所屬計畫：${note.title}\n期限：${formatDate(task.dueDate!)}\n優先級：${task.priority}',
            hidden: store.hiddenUpcomingItems.contains(key),
            sourceNote: note,
          ),
        );
      }
    }
  }
  final items = <UpcomingHomeItem>[
    for (final sub in store.upcomingSubscriptions.where(
      (sub) =>
          isInUpcomingWindow(sub.nextPaymentDate, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(
                upcomingSubscriptionKey(sub),
              )),
    ))
      UpcomingHomeItem(
        key: upcomingSubscriptionKey(sub),
        date: sub.nextPaymentDate,
        icon: Icons.autorenew,
        title: sub.name,
        subtitle:
            '${formatDate(sub.nextPaymentDate)}  ${cycleLabel(sub.cycle)}',
        typeLabel: '訂閱',
        details:
            '下次付款日: ${formatDate(sub.nextPaymentDate)}\n週期: ${cycleLabel(sub.cycle)}\n金額: ${currency(sub.amount)}\n付款方式: ${sub.paymentMethod}\n分類: ${sub.category}\n提醒: 前 ${sub.reminderDays} 天',
        hidden: store.hiddenUpcomingItems.contains(
          upcomingSubscriptionKey(sub),
        ),
        trailing: currency(sub.amount),
      ),
    for (final event in store.upcomingSchedules.where(
      (event) =>
          isInUpcomingWindow(event.start, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(upcomingScheduleKey(event))),
    ))
      UpcomingHomeItem(
        key: upcomingScheduleKey(event),
        date: event.start,
        icon: Icons.event_note,
        title: event.title,
        subtitle: '${formatDate(event.start)}  ${formatTime(event.start)}',
        typeLabel: '行程',
        details:
            '地點：${event.location.isEmpty ? '未設定' : event.location}\n提醒：提前 ${event.remindBeforeMinutes} 分鐘\n備註：${event.notes.isEmpty ? '無' : event.notes}',
        hidden: store.hiddenUpcomingItems.contains(upcomingScheduleKey(event)),
      ),
    ...planItems,
    for (final todo in store.todos.where(
      (todo) =>
          !todo.done &&
          !linkedPlanTodoIds.contains(todo.id) &&
          todo.dueDate != null &&
          isInUpcomingWindow(todo.dueDate!, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(upcomingTodoKey(todo))),
    ))
      UpcomingHomeItem(
        key: upcomingTodoKey(todo),
        date: todo.dueDate!,
        icon: todo.reminderEnabled
            ? Icons.notifications_active_outlined
            : Icons.task_alt,
        title: todo.title,
        subtitle: todoSubtitle(todo),
        typeLabel: '待辦',
        details:
            '期限：${formatDate(todo.dueDate!)}\n提醒：${todo.reminderEnabled ? (todo.reminderTime == null ? '已開啟' : '${todo.reminderTime!.hour.toString().padLeft(2, '0')}:${todo.reminderTime!.minute.toString().padLeft(2, '0')}') : '未開啟'}',
        hidden: store.hiddenUpcomingItems.contains(upcomingTodoKey(todo)),
      ),
  ];
  items.sort((a, b) => a.date.compareTo(b.date));
  return items;
}

bool isInUpcomingWindow(DateTime value, DateTime start, DateTime end) {
  return !value.isBefore(start) && value.isBefore(end);
}

String upcomingSubscriptionKey(SubscriptionItem item) => 'sub-${item.id}';

String upcomingScheduleKey(ScheduleItem item) => 'schedule-${item.id}';

String upcomingTodoKey(TodoItem item) => 'todo-${item.id}';

String upcomingPlanTaskKey(NoteItem note, PlanNode task) {
  return 'plan-task-${note.id}-${task.id}';
}

Future<void> showUpcomingDetails(
  BuildContext context,
  UpcomingHomeItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(item.icon),
          const SizedBox(width: 8),
          Expanded(child: Text(item.title)),
        ],
      ),
      content: Text('${item.typeLabel}\n${item.details}'),
      actions: [
        if (item.sourceNote != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              HomeFeatureActionsScope.of(
                context,
              ).editNote(context, note: item.sourceNote);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('開啟計畫'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('確認'),
        ),
      ],
    ),
  );
}

Future<void> showUpcomingManager(BuildContext context) async {
  final store = AppStoreScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = upcomingHomeItems(store, includeHidden: true);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '即將到來管理',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const EmptyState(icon: Icons.event_available, text: '尚無行程')
              else
                for (final item in items)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(item.icon),
                    value: !item.hidden,
                    title: Text(item.title),
                    subtitle: Text('${item.typeLabel}  ${item.subtitle}'),
                    onChanged: (visible) =>
                        store.setUpcomingItemHidden(item.key, !visible),
                  ),
            ],
          ),
        );
      },
    ),
  );
}

class NotesHomeSection extends StatelessWidget {
  const NotesHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes.take(3).toList();
    if (notes.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.note_alt_outlined, text: '尚無筆記'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final note in notes)
            SwipeDeleteTile(
              itemKey: 'home-note-${note.id}',
              confirmTitle: '刪除筆記？',
              confirmMessage: '確定要刪除這則筆記嗎？',
              onDelete: () => store.deleteNote(note),
              child: SizedBox(
                width: homeGridTileWidth(context),
                child: CompactInfoTile(
                  icon: note.isPinned ? Icons.push_pin : Icons.notes,
                  title: note.title,
                  subtitle: note.category,
                  onTap: () => HomeFeatureActionsScope.of(
                    context,
                  ).editNote(context, note: note),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NoteTile(
              note: note,
              onTap: () => HomeFeatureActionsScope.of(
                context,
              ).editNote(context, note: note),
              onDelete: () => store.deleteNote(note),
            ),
          ),
      ],
    );
  }
}

class TodoHomeSection extends StatefulWidget {
  const TodoHomeSection({
    super.key,
    required this.style,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final HomeSectionStyle style;

  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  State<TodoHomeSection> createState() => _TodoHomeSectionState();
}

class _TodoHomeSectionState extends State<TodoHomeSection> {
  bool showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final itemCount = showCompleted
        ? store.completedTodayTodos.length
        : store.activeTodos.length;

    return Column(
      children: [
        SectionHeader(
          title: showCompleted ? '已完成事項' : '待辦事項',
          count: itemCount,
          onTap: widget.onToggleCollapsed,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => showCompleted = !showCompleted),
                icon: Icon(
                  showCompleted ? Icons.checklist : Icons.task_alt_outlined,
                ),
                label: Text(showCompleted ? '待辦事項' : '已完成'),
              ),
              IconButton(
                tooltip: '新增待辦事項',
                onPressed: () =>
                    HomeFeatureActionsScope.of(context).editTodo(context),
                icon: const Icon(Icons.add_task),
              ),
              Icon(widget.collapsed ? Icons.expand_more : Icons.expand_less),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: widget.collapsed
              ? const SizedBox.shrink(key: ValueKey('todo-collapsed'))
              : TodoBlock(
                  key: ValueKey(
                    'todo-${showCompleted ? 'completed' : 'active'}-${widget.style.name}',
                  ),
                  compact: widget.style == HomeSectionStyle.grid,
                  showCompleted: showCompleted,
                ),
        ),
      ],
    );
  }
}

class TodoBlock extends StatelessWidget {
  const TodoBlock({
    super.key,
    this.compact = false,
    this.showCompleted = false,
  });

  final bool compact;
  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final todos = showCompleted ? store.completedTodayTodos : store.activeTodos;
    if (todos.isEmpty) {
      return InfoCard(
        child: EmptyState(
          icon: showCompleted ? Icons.task_alt : Icons.checklist,
          text: showCompleted ? '今日沒有已完成項目' : '尚無待辦事項',
        ),
      );
    }

    return InfoCard(
      child: showCompleted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '今日已完成項目',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < todos.length; index++) ...[
                  EditableTodoRow(todo: todos[index], compact: compact),
                  if (index != todos.length - 1)
                    const Divider(height: 8, thickness: 0.6),
                ],
              ],
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: todos.length,
              onReorderItem: store.reorderActiveTodo,
              itemBuilder: (context, index) => Column(
                key: ValueKey(todos[index].id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  EditableTodoRow(
                    todo: todos[index],
                    compact: compact,
                    reorderIndex: index,
                  ),
                  if (index != todos.length - 1)
                    const Divider(height: 8, thickness: 0.6),
                ],
              ),
            ),
    );
  }
}

class EditableTodoRow extends StatefulWidget {
  const EditableTodoRow({
    super.key,
    required this.todo,
    this.compact = false,
    this.reorderIndex,
  });

  final TodoItem todo;
  final bool compact;
  final int? reorderIndex;

  @override
  State<EditableTodoRow> createState() => _EditableTodoRowState();
}

class _EditableTodoRowState extends State<EditableTodoRow> {
  late final TextEditingController controller;
  late final FocusNode focusNode;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.todo.title);
    focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        commitTitle();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EditableTodoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id && !editing) {
      controller.text = widget.todo.title;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void startEditing() {
    setState(() => editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      focusNode.requestFocus();
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    });
  }

  void commitTitle() {
    if (!editing) {
      return;
    }
    final nextTitle = controller.text.trim();
    if (nextTitle.isNotEmpty && nextTitle != widget.todo.title) {
      widget.todo.title = nextTitle;
      AppStoreScope.of(context).upsertTodo(widget.todo);
    } else {
      controller.text = widget.todo.title;
    }
    if (mounted) {
      setState(() => editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final metaStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.black54);
    return InkWell(
      onLongPress: () => HomeFeatureActionsScope.of(
        context,
      ).showTodoActions(context, widget.todo),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: widget.todo.done,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => store.toggleTodo(widget.todo),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: editing
                              ? TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  minLines: 1,
                                  maxLines: widget.compact ? 2 : null,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: todoTitleStyle(widget.todo),
                                  onSubmitted: (_) => commitTitle(),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: startEditing,
                                  child: Text(
                                    widget.todo.title,
                                    maxLines: widget.compact ? 2 : null,
                                    overflow: widget.compact
                                        ? TextOverflow.ellipsis
                                        : null,
                                    style: todoTitleStyle(widget.todo),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.todo.done
                                ? todoCompletedLabel(widget.todo)
                                : todoDueLabel(widget.todo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                        if (widget.todo.reminderEnabled) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.notifications_active,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            todoReminderTimeLabel(widget.todo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.reorderIndex != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ReorderableDragStartListener(
                  index: widget.reorderIndex!,
                  child: const Icon(Icons.drag_handle, color: Colors.black45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TodoCard extends StatelessWidget {
  const TodoCard({super.key, required this.todo, this.compact = true});

  final TodoItem todo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final metaStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.black54);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => store.toggleTodo(todo),
        onLongPress: () =>
            HomeFeatureActionsScope.of(context).showTodoActions(context, todo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: todo.done,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => store.toggleTodo(todo),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: todoTitleStyle(todo),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              todo.done
                                  ? todoCompletedLabel(todo)
                                  : todoDueLabel(todo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                          ),
                          if (todo.reminderEnabled) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_active,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              todoReminderTimeLabel(todo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactInfoTile extends StatelessWidget {
  const CompactInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionSummaryTile extends StatelessWidget {
  const SubscriptionSummaryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: SubscriptionSummaryContent(
        icon: icon,
        title: title,
        subtitle: subtitle,
        amount: amount,
      ),
    );
  }
}

class SubscriptionSummaryContent extends StatelessWidget {
  const SubscriptionSummaryContent({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

Future<void> showHomeLayoutSettings(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => const HomeLayoutSettingsPage(),
    ),
  );
}

class HomeLayoutSettingsPage extends StatelessWidget {
  const HomeLayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '調整首頁',
          subtitle: '排序、顯示與版面樣式',
          leading: const PageBackButton(),
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: store.homeSectionOrder.length,
                  onReorderItem: store.reorderHomeSectionsToIndex,
                  itemBuilder: (context, index) {
                    final section = store.homeSectionOrder[index];
                    return HomeLayoutSettingsCard(
                      key: ValueKey(section),
                      section: section,
                      index: index,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1 + animation.value * 0.03,
                          child: child,
                        ),
                      ),
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '拖曳右側三條線調整順序，顯示設定會立即更新。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showHomeLayoutSettingsSheet(BuildContext context) async {
  final store = AppStoreScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '返回',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: store.homeSectionOrder.length,
                  onReorderItem: store.reorderHomeSectionsToIndex,
                  itemBuilder: (context, index) {
                    final section = store.homeSectionOrder[index];
                    return HomeLayoutSettingsCard(
                      key: ValueKey(section),
                      section: section,
                      index: index,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1 + animation.value * 0.03,
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '首頁標題可點擊收合各區塊。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class HomeLayoutSettingsCard extends StatelessWidget {
  const HomeLayoutSettingsCard({
    super.key,
    required this.section,
    required this.index,
  });

  final HomeSectionId section;
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final style = store.homeSectionStyles[section] ?? HomeSectionStyle.list;
    final visible = !store.hiddenHomeSections.contains(section);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: visible,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => store.toggleHomeSectionVisible(section),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    homeSectionTitle(section),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: IconButton(
                    tooltip: '拖曳排序',
                    onPressed: null,
                    icon: const Icon(Icons.drag_handle),
                    disabledColor: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<HomeSectionStyle>(
                    segments: const [
                      ButtonSegment(
                        value: HomeSectionStyle.list,
                        label: Text('條列'),
                        icon: Icon(Icons.view_list),
                      ),
                      ButtonSegment(
                        value: HomeSectionStyle.grid,
                        label: Text('方塊'),
                        icon: Icon(Icons.grid_view),
                      ),
                    ],
                    selected: {style},
                    onSelectionChanged: (value) =>
                        store.setHomeSectionStyle(section, value.first),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
