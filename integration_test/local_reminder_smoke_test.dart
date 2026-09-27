import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_note/services/local_reminder_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android schedules and cancels a native local reminder', (
    tester,
  ) async {
    final gateway = FlutterLocalReminderGateway();
    await gateway.initialize();
    expect(await gateway.notificationsEnabled(), isTrue);

    final key = 'integration:android-smoke';
    final reminder = LocalReminder(
      id: localReminderId(key),
      sourceKey: key,
      scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      title: 'My Note 測試提醒',
      body: '驗證 Android 本機排程',
    );
    await gateway.replaceAll([reminder]);
    expect(await gateway.managedPendingIds(), contains(reminder.id));

    await gateway.replaceAll(const []);
    expect(await gateway.managedPendingIds(), isNot(contains(reminder.id)));
  });
}
