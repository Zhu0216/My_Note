import 'package:flutter/material.dart';

import '../data/my_note_data.dart';

String currency(double value) {
  final rounded = value.round();
  return 'NT\$${rounded.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}

String formatCurrency(double value) => currency(value);

String formatPercent(double value) {
  if (value.isNaN || value.isInfinite) {
    return '0%';
  }
  return '${(value * 100).round()}%';
}

String formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String formatTimeOfDayValue(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String weekdayLabel(int weekday) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[weekday - 1];
}

String cycleLabel(SubscriptionCycle cycle) {
  return switch (cycle) {
    SubscriptionCycle.monthly => '月',
    SubscriptionCycle.yearly => '年費',
    SubscriptionCycle.custom => '自訂',
  };
}

bool isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

bool isSameMinute(DateTime a, DateTime b) {
  return isSameDate(a, b) && a.hour == b.hour && a.minute == b.minute;
}
