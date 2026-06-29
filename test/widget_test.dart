import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_note/main.dart';

void main() {
  testWidgets('renders the restored app shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MyNoteApp(store: AppStore.seeded()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
  });

  testWidgets('shows note template choices before opening an editor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: NoteTemplatePickerPage()));
    await tester.pump();

    expect(find.byIcon(Icons.notes), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stacked_bar_chart), findsOneWidget);
  });
}
