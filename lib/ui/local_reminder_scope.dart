import 'package:flutter/widgets.dart';

import '../services/local_reminder_service.dart';

class LocalReminderScope extends InheritedWidget {
  const LocalReminderScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final LocalReminderCoordinator coordinator;

  static LocalReminderCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocalReminderScope>()
      ?.coordinator;

  @override
  bool updateShouldNotify(LocalReminderScope oldWidget) =>
      coordinator != oldWidget.coordinator;
}
