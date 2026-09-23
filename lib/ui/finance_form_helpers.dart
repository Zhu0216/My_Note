import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/my_note_data.dart';

List<TextInputFormatter> moneyInputFormatters() {
  return [FilteringTextInputFormatter.digitsOnly];
}

List<String> financeAccountOptions(
  AppStore store, {
  String? currentAccount,
  bool includeCurrent = false,
}) {
  final values = <String>[];
  for (final account in store.savingsAccounts) {
    final name = account.name.trim();
    if (name.isNotEmpty && !values.contains(name)) {
      values.add(name);
    }
  }
  final current = currentAccount?.trim() ?? '';
  if (includeCurrent && current.isNotEmpty && !values.contains(current)) {
    values.insert(0, current);
  }
  if (values.isEmpty) {
    values.add('未指定帳戶');
  }
  return values;
}

bool savingsAccountNameExists(AppStore store, String name, {String? exceptId}) {
  final target = name.trim().toLowerCase();
  if (target.isEmpty) {
    return false;
  }
  return store.savingsAccounts.any(
    (account) =>
        account.id != exceptId && account.name.trim().toLowerCase() == target,
  );
}

void showDuplicateSavingsAccountNotice(BuildContext context, String name) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('已存在名為「$name」的存餘帳戶。')));
}
