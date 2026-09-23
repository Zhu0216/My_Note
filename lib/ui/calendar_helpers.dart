import '../data/my_note_data.dart';

DateTime dateInCalendarMonth(DateTime month, int preferredDay) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, preferredDay.clamp(1, lastDay));
}

DateTime shiftCalendarMonth(DateTime date, int monthDelta) {
  final target = DateTime(date.year, date.month + monthDelta);
  return dateInCalendarMonth(target, date.day);
}

DateTime calendarWeekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday % 7));
}

String calendarPeriodLabel(CalendarViewMode mode, DateTime date) {
  if (mode != CalendarViewMode.week) {
    return '${date.year}年${date.month}月';
  }
  final start = calendarWeekStart(date);
  final end = start.add(const Duration(days: 6));
  if (start.year == end.year && start.month == end.month) {
    return '${start.year}年${start.month}月 ${start.day}–${end.day}日';
  }
  return '${start.year}/${start.month}/${start.day}–'
      '${end.year}/${end.month}/${end.day}';
}
