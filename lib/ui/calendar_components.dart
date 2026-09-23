import 'package:flutter/material.dart';

import '../data/my_note_data.dart';
import 'basic_display.dart';
import 'calendar_helpers.dart';
import 'formatters.dart';
import 'shared_components.dart';

Future<DateTime?> showCalendarMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => CalendarMonthPickerDialog(initialMonth: initialMonth),
  );
}

class ScheduleGroupedList extends StatelessWidget {
  const ScheduleGroupedList({
    super.key,
    required this.events,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ScheduleItem> events;
  final ValueChanged<ScheduleItem> onEdit;
  final ValueChanged<ScheduleItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyState(icon: Icons.event_busy, text: '尚無行程');
    }
    final grouped = <DateTime, List<ScheduleItem>>{};
    for (final event in events) {
      final day = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      grouped.putIfAbsent(day, () => []).add(event);
    }
    final days = grouped.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '行程清單'),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Chip(
              label: Text(
                isSameDate(day, DateTime.now()) ? '今日' : formatDate(day),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          for (final event
              in grouped[day]!..sort((a, b) => a.start.compareTo(b.start)))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ScheduleTile(
                event: event,
                onTap: () => onEdit(event),
                onDelete: () => onDelete(event),
              ),
            ),
        ],
      ],
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.event,
    required this.onTap,
    this.onDelete,
  });

  final ScheduleItem event;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.event_note),
        title: Text(event.title),
        subtitle: Text(
          '${formatDate(event.start)}  ${formatTime(event.start)} - ${formatTime(event.end)}\n${event.location}  提前 ${event.remindBeforeMinutes} 分鐘提醒',
        ),
        isThreeLine: true,
      ),
    );
    if (onDelete == null) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'schedule-${event.id}',
      confirmTitle: '刪除行程？',
      confirmMessage: '確定要刪除這筆行程嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class FinanceTile extends StatelessWidget {
  const FinanceTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  final FinanceEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == EntryType.income;
    final accountLabel = entry.account.trim().isEmpty ? '未指定帳戶' : entry.account;
    final detailParts = [
      if (isIncome) '收入' else entry.category,
      formatTime(entry.date),
    ].where((item) => item.trim().isNotEmpty).toList();
    final tile = Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: isIncome ? Colors.green : Colors.red,
        ),
        title: Text(entry.title),
        subtitle: Text(detailParts.join(' / ')),
        trailing: Text(
          '($accountLabel ${isIncome ? '+' : '-'}${currency(entry.amount)})',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
    if (onDelete == null) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'finance-${entry.id}',
      confirmTitle: '刪除記帳？',
      confirmMessage: '確定要刪除這筆記帳紀錄嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class CalendarPeriodSelector extends StatelessWidget {
  const CalendarPeriodSelector({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: const Color(0xffe4e8f5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一個期間',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: onPickMonth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一個期間',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class CalendarSwipeRegion extends StatefulWidget {
  const CalendarSwipeRegion({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  State<CalendarSwipeRegion> createState() => _CalendarSwipeRegionState();
}

class _CalendarSwipeRegionState extends State<CalendarSwipeRegion> {
  double horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => horizontalDragDistance = 0,
      onHorizontalDragUpdate: (details) {
        horizontalDragDistance += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (horizontalDragDistance <= -48 || velocity <= -150) {
          widget.onNext();
        } else if (horizontalDragDistance >= 48 || velocity >= 150) {
          widget.onPrevious();
        }
        horizontalDragDistance = 0;
      },
      onHorizontalDragCancel: () => horizontalDragDistance = 0,
      child: widget.child,
    );
  }
}

class CalendarMonthPickerDialog extends StatefulWidget {
  const CalendarMonthPickerDialog({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<CalendarMonthPickerDialog> createState() =>
      _CalendarMonthPickerDialogState();
}

class _CalendarMonthPickerDialogState extends State<CalendarMonthPickerDialog> {
  late int visibleYear;

  @override
  void initState() {
    super.initState();
    visibleYear = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Row(
        children: [
          IconButton(
            tooltip: '上一年',
            onPressed: () => setState(() => visibleYear--),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '$visibleYear年',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '下一年',
            onPressed: () => setState(() => visibleYear++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            for (var month = 1; month <= 12; month++)
              Builder(
                builder: (context) {
                  final selected =
                      visibleYear == widget.initialMonth.year &&
                      month == widget.initialMonth.month;
                  return selected
                      ? FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DateTime(visibleYear, month),
                          ),
                          child: Text('$month月'),
                        )
                      : OutlinedButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DateTime(visibleYear, month),
                          ),
                          child: Text('$month月'),
                        );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class MonthStrip extends StatelessWidget {
  const MonthStrip({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<ScheduleItem> events;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(selectedDate.year, selectedDate.month);
    final daysInMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      0,
    ).day;
    final offset = firstDay.weekday % 7;
    final colors = Theme.of(context).colorScheme;
    return InfoCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final label in const ['日', '一', '二', '三', '四', '五', '六'])
                Expanded(
                  child: SizedBox(
                    height: 26,
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxWidth >= 720 ? 86.0 : 70.0;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: cellHeight,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: offset + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < offset) {
                    return const SizedBox.shrink();
                  }
                  final day = index - offset + 1;
                  final date = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    day,
                  );
                  final dayEvents = events
                      .where((event) => isSameDate(event.start, date))
                      .toList(growable: false);
                  final visibleDayEvents = dayEvents
                      .take(3)
                      .toList(growable: false);
                  final selected = isSameDate(date, selectedDate);
                  final today = isSameDate(date, now);
                  final foreground = selected
                      ? colors.primary
                      : colors.onSurface;
                  final eventLabelHeight = cellHeight >= 80 ? 17.0 : 13.0;
                  final eventFontSize = cellHeight >= 80 ? 10.0 : 8.0;
                  return InkWell(
                    onTap: () => onDateSelected(date),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      key: ValueKey(
                        'calendar-day-${date.year}-${date.month}-${date.day}',
                      ),
                      decoration: BoxDecoration(
                        color: !selected && today
                            ? colors.primaryContainer
                            : const Color(0xfff1f3ef),
                        border: Border.all(
                          color: selected ? colors.primary : Colors.transparent,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 5,
                            left: 6,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (visibleDayEvents.isNotEmpty)
                            Positioned.fill(
                              top: 20,
                              left: 3,
                              right: 3,
                              bottom: 3,
                              child: Column(
                                key: ValueKey(
                                  'calendar-events-${date.year}-${date.month}-${date.day}',
                                ),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (
                                    var eventIndex = 0;
                                    eventIndex < visibleDayEvents.length;
                                    eventIndex++
                                  ) ...[
                                    Container(
                                      key: ValueKey(
                                        'calendar-event-${visibleDayEvents[eventIndex].id}',
                                      ),
                                      height: eventLabelHeight,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: 0.09,
                                        ),
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        visibleDayEvents[eventIndex].title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: eventFontSize,
                                          height: 1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (eventIndex <
                                        visibleDayEvents.length - 1)
                                      const SizedBox(height: 1),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<ScheduleItem> events;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekStart = calendarWeekStart(selectedDate);
    return InfoCard(
      child: Row(
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final dayEvents = events
              .where((event) => isSameDate(event.start, date))
              .toList(growable: false);
          final selected = isSameDate(date, selectedDate);
          final isToday = isSameDate(date, today);
          return Expanded(
            child: InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                key: ValueKey(
                  'calendar-week-day-${date.year}-${date.month}-${date.day}',
                ),
                height: 96,
                margin: EdgeInsets.only(right: index == 6 ? 0 : 2),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday && !selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xfff1f3ef),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(
                      weekdayLabel(date.weekday),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (dayEvents.isNotEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            dayEvents.first.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.15,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
