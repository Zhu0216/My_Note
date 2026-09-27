import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../data/my_note_data.dart';

const _payloadPrefix = 'my_note:';

class LocalReminder {
  const LocalReminder({
    required this.id,
    required this.sourceKey,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final String sourceKey;
  final DateTime scheduledAt;
  final String title;
  final String body;

  String get payload => '$_payloadPrefix$sourceKey';
}

enum ReminderSourceType { todo, schedule, subscription }

class InAppDueReminder {
  const InAppDueReminder({
    required this.sourceType,
    required this.sourceId,
    required this.dueAt,
    required this.title,
    required this.body,
  });

  final ReminderSourceType sourceType;
  final String sourceId;
  final DateTime dueAt;
  final String title;
  final String body;

  String get occurrenceKey =>
      '${sourceType.name}:$sourceId:${dueAt.toIso8601String()}';
}

List<InAppDueReminder> buildInAppDueReminders(AppStore store, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final reminders = <InAppDueReminder>[];

  for (final todo in store.todos) {
    if (todo.done ||
        !todo.reminderEnabled ||
        todo.dueDate == null ||
        todo.reminderTime == null) {
      continue;
    }
    final due = todo.dueDate!;
    final time = todo.reminderTime!;
    final dueAt = DateTime(
      due.year,
      due.month,
      due.day,
      time.hour,
      time.minute,
    );
    if (dueAt.isAfter(current)) continue;
    reminders.add(
      InAppDueReminder(
        sourceType: ReminderSourceType.todo,
        sourceId: todo.id,
        dueAt: dueAt,
        title: todo.title,
        body: '待辦提醒',
      ),
    );
  }

  for (final schedule in store.schedules) {
    final dueAt = schedule.start.subtract(
      Duration(minutes: schedule.remindBeforeMinutes.clamp(0, 525600)),
    );
    if (dueAt.isAfter(current) || schedule.end.isBefore(current)) continue;
    reminders.add(
      InAppDueReminder(
        sourceType: ReminderSourceType.schedule,
        sourceId: schedule.id,
        dueAt: dueAt,
        title: schedule.title,
        body: '行程提醒',
      ),
    );
  }

  for (final subscription in store.subscriptions) {
    if (!subscription.isActive) continue;
    final paymentDate = subscription.nextPaymentDate;
    final paymentDayEnd = DateTime(
      paymentDate.year,
      paymentDate.month,
      paymentDate.day,
      23,
      59,
      59,
      999,
    );
    final reminderDate = paymentDate.subtract(
      Duration(days: subscription.reminderDays.clamp(0, 3650)),
    );
    final dueAt = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
    );
    if (dueAt.isAfter(current) || paymentDayEnd.isBefore(current)) continue;
    reminders.add(
      InAppDueReminder(
        sourceType: ReminderSourceType.subscription,
        sourceId: subscription.id,
        dueAt: dueAt,
        title: subscription.name,
        body: '訂閱扣款提醒',
      ),
    );
  }

  reminders.sort((left, right) => left.dueAt.compareTo(right.dueAt));
  return reminders;
}

class InAppReminderReceiptStore {
  InAppReminderReceiptStore._(this._preferences, this._seen);

  static const _storageKey = 'my_note_in_app_reminder_receipts_v1';
  static const _maximumReceiptCount = 500;

  final SharedPreferences _preferences;
  final Set<String> _seen;

  static Future<InAppReminderReceiptStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    return InAppReminderReceiptStore._(
      preferences,
      (preferences.getStringList(_storageKey) ?? const <String>[]).toSet(),
    );
  }

  List<InAppDueReminder> unseen(Iterable<InAppDueReminder> reminders) =>
      reminders.where((item) => !_seen.contains(item.occurrenceKey)).toList();

  Future<void> markSeen(Iterable<InAppDueReminder> reminders) async {
    for (final reminder in reminders) {
      _seen.add(reminder.occurrenceKey);
    }
    final retained = _seen.toList();
    if (retained.length > _maximumReceiptCount) {
      retained.removeRange(0, retained.length - _maximumReceiptCount);
      _seen
        ..clear()
        ..addAll(retained);
    }
    await _preferences.setStringList(_storageKey, retained);
  }
}

int localReminderId(String sourceKey) {
  var hash = 0x811c9dc5;
  for (final unit in sourceKey.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

List<LocalReminder> buildLocalReminders(AppStore store, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final reminders = <LocalReminder>[];

  for (final todo in store.todos) {
    if (todo.done ||
        !todo.reminderEnabled ||
        todo.dueDate == null ||
        todo.reminderTime == null) {
      continue;
    }
    final due = todo.dueDate!;
    final time = todo.reminderTime!;
    final scheduledAt = DateTime(
      due.year,
      due.month,
      due.day,
      time.hour,
      time.minute,
    );
    if (!scheduledAt.isAfter(current)) continue;
    final key = 'todo:${todo.id}';
    reminders.add(
      LocalReminder(
        id: localReminderId(key),
        sourceKey: key,
        scheduledAt: scheduledAt,
        title: '待辦提醒',
        body: todo.title,
      ),
    );
  }

  for (final schedule in store.schedules) {
    final scheduledAt = schedule.start.subtract(
      Duration(minutes: schedule.remindBeforeMinutes.clamp(0, 525600)),
    );
    if (!scheduledAt.isAfter(current)) continue;
    final key = 'schedule:${schedule.id}';
    reminders.add(
      LocalReminder(
        id: localReminderId(key),
        sourceKey: key,
        scheduledAt: scheduledAt,
        title: '行程提醒',
        body: schedule.title,
      ),
    );
  }

  for (final subscription in store.subscriptions) {
    if (!subscription.isActive) continue;
    final paymentDate = subscription.nextPaymentDate;
    final reminderDate = paymentDate.subtract(
      Duration(days: subscription.reminderDays.clamp(0, 3650)),
    );
    final scheduledAt = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
    );
    if (!scheduledAt.isAfter(current)) continue;
    final key = 'subscription:${subscription.id}';
    reminders.add(
      LocalReminder(
        id: localReminderId(key),
        sourceKey: key,
        scheduledAt: scheduledAt,
        title: '訂閱扣款提醒',
        body: subscription.name,
      ),
    );
  }

  reminders.sort(
    (left, right) => left.scheduledAt.compareTo(right.scheduledAt),
  );
  return reminders;
}

abstract class LocalReminderGateway {
  Future<void> initialize();

  Future<bool> notificationsEnabled();

  Future<bool> requestPermission();

  Future<void> replaceAll(List<LocalReminder> reminders);

  Future<List<int>> managedPendingIds();
}

class NoopLocalReminderGateway implements LocalReminderGateway {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<LocalReminder> reminders) async {}

  @override
  Future<List<int>> managedPendingIds() async => const [];
}

class FlutterLocalReminderGateway implements LocalReminderGateway {
  FlutterLocalReminderGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'my_note_reminders',
      'My Note 提醒',
      channelDescription: '待辦、行程與訂閱扣款提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      final location =
          timezone.timeZoneDatabase.locations[deviceTimezone.identifier];
      if (location != null) timezone.setLocalLocation(location);
    } catch (_) {
      // The timezone package defaults to UTC if the platform cannot resolve it.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  @override
  Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> replaceAll(List<LocalReminder> reminders) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending.where(
      (item) => item.payload?.startsWith(_payloadPrefix) == true,
    )) {
      await _plugin.cancel(id: notification.id);
    }
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: timezone.TZDateTime.from(
          reminder.scheduledAt,
          timezone.local,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.payload,
      );
    }
  }

  @override
  Future<List<int>> managedPendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .where((item) => item.payload?.startsWith(_payloadPrefix) == true)
          .map((item) => item.id)
          .toList();
}

LocalReminderGateway createLocalReminderGateway() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return NoopLocalReminderGateway();
  }
  return FlutterLocalReminderGateway();
}

class LocalReminderCoordinator {
  LocalReminderCoordinator(
    this._store,
    this._gateway, {
    this.debounce = const Duration(milliseconds: 250),
  });

  final AppStore _store;
  final LocalReminderGateway _gateway;
  final Duration debounce;
  Timer? _timer;
  Map<int, DateTime> _lastSchedule = const {};
  Future<void> _queue = Future.value();
  bool _started = false;

  bool get isSupported => _gateway is! NoopLocalReminderGateway;

  Future<void> start() async {
    if (_started) return;
    await _gateway.initialize();
    final reminders = buildLocalReminders(_store);
    _lastSchedule = {for (final item in reminders) item.id: item.scheduledAt};
    if (await _gateway.notificationsEnabled()) {
      await _gateway.replaceAll(reminders);
    }
    _store.addListener(_scheduleReconcile);
    _started = true;
  }

  void _scheduleReconcile() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _queue = _queue.then((_) => _reconcile()).catchError((Object error) {
        debugPrint('Local reminder reconciliation failed: $error');
      });
    });
  }

  Future<void> _reconcile() async {
    final reminders = buildLocalReminders(_store);
    final schedule = {for (final item in reminders) item.id: item.scheduledAt};
    final addsOrChanges = schedule.entries.any(
      (entry) => _lastSchedule[entry.key] != entry.value,
    );
    var enabled = await _gateway.notificationsEnabled();
    if (!enabled && addsOrChanges) {
      enabled = await _gateway.requestPermission();
    }
    await _gateway.replaceAll(enabled ? reminders : const []);
    _lastSchedule = schedule;
  }

  Future<void> reconcileNow() async {
    _timer?.cancel();
    await _queue;
    await _reconcile();
  }

  Future<bool> notificationsEnabled() => _gateway.notificationsEnabled();

  Future<bool> requestPermissionAndReconcile() async {
    final enabled = await _gateway.requestPermission();
    final reminders = buildLocalReminders(_store);
    await _gateway.replaceAll(enabled ? reminders : const []);
    _lastSchedule = {for (final item in reminders) item.id: item.scheduledAt};
    return enabled;
  }

  void dispose() {
    _timer?.cancel();
    if (_started) _store.removeListener(_scheduleReconcile);
  }
}
