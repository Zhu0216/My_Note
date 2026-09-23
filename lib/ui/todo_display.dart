import 'package:flutter/material.dart';

import '../data/my_note_data.dart';
import 'formatters.dart';

String todoSubtitle(TodoItem todo) {
  final parts = <String>[];
  parts.add(todo.dueDate == null ? '無限期' : formatDate(todo.dueDate!));
  if (todo.reminderEnabled) {
    final time = todo.reminderTime == null
        ? '已提醒'
        : formatTimeOfDayValue(todo.reminderTime!);
    parts.add('提醒 $time');
  }
  return parts.join('  ');
}

String todoDueLabel(TodoItem todo) {
  return todo.dueDate == null ? '無限期' : formatDate(todo.dueDate!);
}

String todoCompletedLabel(TodoItem todo) {
  final completedAt = todo.completedAt;
  if (completedAt == null) {
    return '已完成';
  }
  return '完成 ${formatTime(completedAt)}';
}

String todoReminderTimeLabel(TodoItem todo) {
  final time = todo.reminderTime;
  if (time == null) {
    return '已開啟';
  }
  return formatTimeOfDayValue(time);
}

TextStyle todoTitleStyle(TodoItem todo) {
  return TextStyle(
    decoration: todo.done ? TextDecoration.lineThrough : null,
    color: todo.done ? Colors.black45 : null,
    fontWeight: FontWeight.w700,
  );
}

String formatTodoReminderTime(BuildContext context, TimeOfDay time) {
  return formatTimeOfDayValue(time);
}
