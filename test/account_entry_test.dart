import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/account/account_controller.dart';
import 'package:my_note/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch offers sync sign-in and remembered local use', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final account = await AccountController.load(firebaseAvailable: false);
    final store = AppStore.seeded();

    await tester.pumpWidget(
      MyNoteApp(store: store, accountController: account),
    );
    await tester.pumpAndSettle();

    expect(find.text('登入並同步'), findsOneWidget);
    expect(find.text('直接使用本機資料'), findsOneWidget);

    await tester.tap(find.text('直接使用本機資料'));
    await tester.pumpAndSettle();

    expect(find.text('My Note'), findsOneWidget);
    expect(account.entryChoice, AccountEntryChoice.localOnly);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('account.local_only_entry'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
