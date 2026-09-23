import 'package:flutter/widgets.dart';

import '../data/my_note_data.dart';

class AppStoreScope extends InheritedNotifier<AppStore> {
  const AppStoreScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStoreScope>();
    assert(scope != null, 'AppStoreScope not found');
    return scope!.notifier!;
  }

  static AppStore read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppStoreScope>();
    final scope = element?.widget as AppStoreScope?;
    assert(scope != null, 'AppStoreScope not found');
    return scope!.notifier!;
  }
}
