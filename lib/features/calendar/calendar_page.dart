part of '../../main.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewMode mode = CalendarViewMode.month;
  DateTime selectedDate = DateTime.now();
  DateTime? lastExplicitlySelectedDate;
  bool reserveDailyScheduleScrollSpace = false;
  final calendarScrollController = ScrollController();
  final dailyScheduleKey = GlobalKey();

  @override
  void dispose() {
    calendarScrollController.dispose();
    super.dispose();
  }

  void shiftVisiblePeriod(int direction) {
    setState(() {
      lastExplicitlySelectedDate = null;
      reserveDailyScheduleScrollSpace = false;
      selectedDate = mode == CalendarViewMode.week
          ? selectedDate.add(Duration(days: 7 * direction))
          : shiftCalendarMonth(selectedDate, direction);
    });
  }

  Future<void> pickVisibleMonth() async {
    final picked = await showCalendarMonthPicker(
      context,
      initialMonth: selectedDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      lastExplicitlySelectedDate = null;
      reserveDailyScheduleScrollSpace = false;
      selectedDate = dateInCalendarMonth(picked, selectedDate.day);
    });
  }

  void selectCalendarDate(DateTime date) {
    final repeatedSelection =
        lastExplicitlySelectedDate != null &&
        isSameDate(lastExplicitlySelectedDate!, date) &&
        isSameDate(selectedDate, date);
    if (repeatedSelection) {
      setState(() {
        reserveDailyScheduleScrollSpace = true;
      });
      scrollToDailySchedule();
      return;
    }
    setState(() {
      selectedDate = date;
      lastExplicitlySelectedDate = date;
      reserveDailyScheduleScrollSpace = false;
    });
  }

  void openDailySchedule(DateTime date) {
    setState(() {
      mode = CalendarViewMode.month;
      selectedDate = DateTime(date.year, date.month, date.day);
      lastExplicitlySelectedDate = selectedDate;
      reserveDailyScheduleScrollSpace = true;
    });
    scrollToDailySchedule();
  }

  void scrollToDailySchedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = dailyScheduleKey.currentContext;
      if (!mounted || targetContext == null) {
        return;
      }
      final targetRenderObject = targetContext.findRenderObject();
      final viewport = targetRenderObject == null
          ? null
          : RenderAbstractViewport.maybeOf(targetRenderObject);
      if (targetRenderObject == null || viewport == null) {
        return;
      }
      // Keep the action clear of the fixed page header.
      final targetOffset =
          (viewport.getOffsetToReveal(targetRenderObject, 0).offset - 12).clamp(
            calendarScrollController.position.minScrollExtent,
            calendarScrollController.position.maxScrollExtent,
          );
      calendarScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final events = store.schedules.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final selectedEvents = events
        .where((event) => isSameDate(event.start, selectedDate))
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AddBubbleButton(
        tooltip: '新增行程',
        onPressed: () => showScheduleEditor(context, initialDate: selectedDate),
        heroTag: 'calendar-add',
      ),
      body: AppPage(
        title: '行程',
        subtitle: '月曆、週曆與清單檢視',
        child: ListView(
          controller: calendarScrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            reserveDailyScheduleScrollSpace
                ? MediaQuery.sizeOf(context).height
                : 96,
          ),
          children: [
            SegmentedButton<CalendarViewMode>(
              segments: const [
                ButtonSegment(
                  value: CalendarViewMode.month,
                  label: Text('月曆'),
                  icon: Icon(Icons.calendar_view_month),
                ),
                ButtonSegment(
                  value: CalendarViewMode.week,
                  label: Text('週曆'),
                  icon: Icon(Icons.view_week),
                ),
                ButtonSegment(
                  value: CalendarViewMode.list,
                  label: Text('清單'),
                  icon: Icon(Icons.list),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => setState(() {
                mode = value.first;
                lastExplicitlySelectedDate = null;
                reserveDailyScheduleScrollSpace = false;
              }),
            ),
            if (mode != CalendarViewMode.list) ...[
              const SizedBox(height: 10),
              CalendarPeriodSelector(
                label: calendarPeriodLabel(mode, selectedDate),
                onPrevious: () => shiftVisiblePeriod(-1),
                onNext: () => shiftVisiblePeriod(1),
                onPickMonth: pickVisibleMonth,
              ),
              const SizedBox(height: 10),
              CalendarSwipeRegion(
                key: const ValueKey('calendar-visible-period-block'),
                onPrevious: () => shiftVisiblePeriod(-1),
                onNext: () => shiftVisiblePeriod(1),
                child: mode == CalendarViewMode.month
                    ? MonthStrip(
                        events: events,
                        selectedDate: selectedDate,
                        onDateSelected: selectCalendarDate,
                      )
                    : WeekStrip(
                        events: events,
                        selectedDate: selectedDate,
                        onDateSelected: selectCalendarDate,
                      ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              ScheduleGroupedList(events: events),
            ],
            if (mode != CalendarViewMode.list) ...[
              const SizedBox(height: 12),
              Align(
                key: dailyScheduleKey,
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('calendar-add-selected-date'),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () =>
                        showScheduleEditor(context, initialDate: selectedDate),
                    icon: const Icon(Icons.add),
                    label: const Text('新增行程'),
                  ),
                ),
              ),
            ],
            if (mode != CalendarViewMode.list) ...[
              const SizedBox(height: 16),
              SectionHeader(title: '當日行程 · ${formatDate(selectedDate)}'),
              if (selectedEvents.isEmpty)
                const EmptyState(icon: Icons.event_busy, text: '當日沒有行程')
              else
                for (final event in selectedEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ScheduleTile(
                      event: event,
                      onTap: () => showScheduleEditor(context, event: event),
                      onDelete: () => store.deleteSchedule(event),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            InfoCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('提醒通知'),
                subtitle: const Text('提醒已開啟'),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
