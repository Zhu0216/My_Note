import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart' as fbt;
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'firebase_options.dart';
import 'data/my_note_data.dart';

export 'data/my_note_data.dart';

part 'note_editor.dart';
part 'features/home/home_page.dart';
part 'features/notes/notes_page.dart';
part 'features/calendar/calendar_page.dart';
part 'features/finance/finance_page.dart';

const appLocale = Locale('zh', 'TW');
const deviceFontChannel = MethodChannel('my_note/device_font');
const noteRuntimeDeviceFontFamily = 'MyNoteDeviceSystemFont';
const noteRuntimeDeviceFontPrefix = 'MyNoteInstalledDeviceFont';
const noteDeviceFontValuePrefix = 'DeviceFont:';

String? loadedDeviceSystemFontFamily;
String loadedDeviceSystemFontDisplayName = '';
final Map<String, DeviceFontOption> loadedDeviceFontOptions = {};

class DeviceFontOption {
  const DeviceFontOption({
    required this.packageName,
    required this.displayName,
    required this.fontFamily,
  });

  final String packageName;
  final String displayName;
  final String fontFamily;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDeviceSystemFontIfAvailable();
  final store = await AppStore.load();
  runApp(MyNoteApp(store: store));
  unawaited(_initializeFirebaseIfConfigured());
}

Future<void> loadDeviceSystemFontIfAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    final rawCatalog = await deviceFontChannel
        .invokeMethod<Map<Object?, Object?>>('loadFontCatalog');
    if (rawCatalog == null) {
      return;
    }
    final currentPackage = rawCatalog['currentPackage']?.toString() ?? '';
    final rawFonts = rawCatalog['fonts'];
    if (rawFonts is! List) {
      return;
    }
    var index = 0;
    for (final rawFont in rawFonts) {
      if (rawFont is! Map) {
        continue;
      }
      final packageName = rawFont['packageName']?.toString() ?? '';
      final displayName = rawFont['displayName']?.toString() ?? '';
      final bytes = rawFont['bytes'];
      if (packageName.isEmpty ||
          displayName.isEmpty ||
          bytes is! Uint8List ||
          bytes.isEmpty) {
        continue;
      }
      final fontFamily = packageName == currentPackage
          ? noteRuntimeDeviceFontFamily
          : '$noteRuntimeDeviceFontPrefix$index';
      final loader = FontLoader(fontFamily)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      loadedDeviceFontOptions[packageName] = DeviceFontOption(
        packageName: packageName,
        displayName: displayName,
        fontFamily: fontFamily,
      );
      if (packageName == currentPackage) {
        loadedDeviceSystemFontFamily = fontFamily;
        loadedDeviceSystemFontDisplayName = displayName;
      }
      index++;
    }
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

Future<void> _initializeFirebaseIfConfigured() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class MyNoteApp extends StatefulWidget {
  const MyNoteApp({super.key, required this.store});

  final AppStore store;

  @override
  State<MyNoteApp> createState() => _MyNoteAppState();
}

class _MyNoteAppState extends State<MyNoteApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.store.flushPersistence());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.store.flushPersistence());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStoreScope(
      store: widget.store,
      child: ShadApp.custom(
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadZincColorScheme.light(),
        ),
        appBuilder: (context) {
          return MaterialApp(
            title: 'My Note',
            debugShowCheckedModeBanner: false,
            locale: appLocale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalShadLocalizations.delegate,
            ],
            supportedLocales: const [appLocale, Locale('en')],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) {
                return appLocale;
              }
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode &&
                    (supportedLocale.countryCode == null ||
                        supportedLocale.countryCode == locale.countryCode)) {
                  return supportedLocale;
                }
              }
              return appLocale;
            },
            theme: ThemeData(
              useMaterial3: true,
              colorScheme:
                  ColorScheme.fromSeed(
                    seedColor: const Color(0xff5967d8),
                    brightness: Brightness.light,
                  ).copyWith(
                    primary: const Color(0xff5967d8),
                    secondary: const Color(0xffff8f70),
                    tertiary: const Color(0xff2fbf9b),
                    surface: const Color(0xffffffff),
                    surfaceContainerHighest: const Color(0xfff0f2fb),
                    onSurface: const Color(0xff19202a),
                  ),
              scaffoldBackgroundColor: const Color(0xfff6f7fb),
              appBarTheme: const AppBarTheme(centerTitle: false),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xffdde2f2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xffdde2f2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xff5967d8),
                    width: 1.6,
                  ),
                ),
              ),
              cardTheme: const CardThemeData(
                elevation: 0,
                color: Colors.white,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xff5967d8),
                foregroundColor: Colors.white,
                elevation: 8,
              ),
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

class ShadcnDesignTokens {
  const ShadcnDesignTokens._();

  static const radius = 12.0;
  static const background = Color(0xfffafafa);
  static const foreground = Color(0xff18181b);
  static const muted = Color(0xfff4f4f5);
  static const mutedForeground = Color(0xff71717a);
  static const border = Color(0xffe4e4e7);
  static const primary = Color(0xff18181b);
  static const primaryForeground = Color(0xfffafafa);
  static const accent = Color(0xfff4f4f5);
  static const destructive = Color(0xffef4444);
}

class ShadcnSurface extends StatelessWidget {
  const ShadcnSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShadcnDesignTokens.background,
        border: Border.all(color: ShadcnDesignTokens.border),
        borderRadius: BorderRadius.circular(ShadcnDesignTokens.radius),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ShadcnActionButton extends StatelessWidget {
  const ShadcnActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
  }
}

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

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Widget appPickerBuilder(BuildContext context, Widget? child) {
  final mediaQuery = MediaQuery.of(context);
  return Localizations.override(
    context: context,
    locale: appLocale,
    child: MediaQuery(
      data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    locale: appLocale,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: '選擇日期',
    cancelText: '取消',
    confirmText: '確定',
    fieldLabelText: '輸入日期',
    fieldHintText: '年/月/日',
    errorFormatText: '請輸入有效日期',
    errorInvalidText: '日期超出範圍',
    builder: appPickerBuilder,
  );
}

Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String helpText = '選擇時間',
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.dial,
    helpText: helpText,
    cancelText: '取消',
    confirmText: '確定',
    hourLabelText: '小時',
    minuteLabelText: '分鐘',
    errorInvalidText: '請輸入有效時間',
    builder: appPickerBuilder,
  );
}

TimeOfDay timeOfDate(DateTime value) {
  return TimeOfDay(hour: value.hour, minute: value.minute);
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime combinePickedDateWithCurrentTime(
  DateTime pickedDate,
  DateTime current,
) {
  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    current.hour,
    current.minute,
  );
}

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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int homeIndex = 2;

  final notesPageKey = GlobalKey<_NotesPageState>();
  final calendarPageKey = GlobalKey<_CalendarPageState>();
  final homePageKey = GlobalKey<_HomePageState>();
  int selectedIndex = homeIndex;

  void selectPage(int index) {
    if (index == selectedIndex) {
      return;
    }
    setState(() => selectedIndex = index);
  }

  void openNotesLocation(String folder, {bool showTrash = false}) {
    void applyLocation() {
      notesPageKey.currentState?.openBackTarget(folder, showTrash: showTrash);
    }

    if (selectedIndex == 0 && notesPageKey.currentState != null) {
      applyLocation();
      return;
    }
    setState(() => selectedIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => applyLocation());
  }

  void openCalendarDailySchedule(DateTime date) {
    void applyDate() {
      calendarPageKey.currentState?.openDailySchedule(date);
    }

    if (selectedIndex == 1 && calendarPageKey.currentState != null) {
      applyDate();
      return;
    }
    setState(() => selectedIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => applyDate());
  }

  Future<void> handleSystemBack() async {
    if (selectedIndex == 0 &&
        (notesPageKey.currentState?.handleAppBack() ?? false)) {
      return;
    }
    if (selectedIndex == homeIndex &&
        (homePageKey.currentState?.handleAppBack() ?? false)) {
      return;
    }
    if (selectedIndex != homeIndex) {
      setState(() => selectedIndex = homeIndex);
      return;
    }
    final shouldExit = await showExitConfirmDialog(context);
    if (shouldExit && mounted) {
      await AppStoreScope.read(context).flushPersistence();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      NotesPage(key: notesPageKey),
      CalendarPage(key: calendarPageKey),
      HomePage(key: homePageKey, onNavigate: selectPage),
      const FinancePage(),
      const SettingsPage(),
    ];

    return AppNavigationScope(
      onNavigate: selectPage,
      onOpenNotesLocation: openNotesLocation,
      onOpenCalendarDailySchedule: openCalendarDailySchedule,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            unawaited(handleSystemBack());
          }
        },
        child: Scaffold(
          body: SafeArea(child: pages[selectedIndex]),
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: selectedIndex,
            onSelected: selectPage,
          ),
        ),
      ),
    );
  }
}

class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.onNavigate,
    required this.onOpenNotesLocation,
    required this.onOpenCalendarDailySchedule,
    required super.child,
  });

  final ValueChanged<int> onNavigate;
  final void Function(String folder, {bool showTrash}) onOpenNotesLocation;
  final ValueChanged<DateTime> onOpenCalendarDailySchedule;

  static AppNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) => false;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.style = AppNavBarStyle.template6,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppNavBarStyle style;

  static const items = [
    AppNavItem(
      label: '筆記',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
    ),
    AppNavItem(
      label: '行程',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    AppNavItem(
      label: '首頁',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavItem(
      label: '記帳',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    AppNavItem(
      label: '設定',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      AppNavBarStyle.template6 => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xffe2e6f4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              height: 92,
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: AppBottomNavigationItem(
                        item: items[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}

class AppBottomNavigationItem extends StatelessWidget {
  const AppBottomNavigationItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveColor = const Color(0xff596273);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.fromLTRB(4, 10, 4, 9),
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: selected ? 46 : 40,
                height: selected ? 46 : 38,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(selected ? 999 : 18),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 9),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? Colors.white : inactiveColor,
                  size: selected ? 27 : 23,
                ),
              ),
              SizedBox(height: selected ? 2 : 3),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? colorScheme.primary : inactiveColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

String appNavBarStyleLabel(AppNavBarStyle style) {
  return switch (style) {
    AppNavBarStyle.template6 => 'Template 6',
  };
}

Future<bool> showExitConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('是否退出？'),
      content: const Text('確定要離開 My Note 嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('退出'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '設定',
      subtitle: '本機資料、提醒與未來同步規劃',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const LocalDataManagementCard(),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Firebase Auth'),
                  subtitle: Text('使用者登入與帳號管理'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_sync_outlined),
                  title: Text('Cloud Firestore'),
                  subtitle: Text(
                    'Notes、Schedule、Subscriptions、Finance 將以 userId 分層同步。',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.attach_file),
                  title: Text('Firebase Storage'),
                  subtitle: Text('附件與圖片儲存'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('FCM 推播'),
                  subtitle: Text('手機推播與提醒通知'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.public),
                  title: Text('Flutter Web + Firebase Hosting'),
                  subtitle: Text('Web 部署與公開網址'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storefront_outlined),
                  title: Text('上架準備'),
                  subtitle: Text('Google Play 與 App Store 上架準備'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.space_dashboard_outlined),
                  title: Text('介面風格'),
                  subtitle: Text('下方導覽列已套用 Nav Bars Template 6，後續可在此加入風格切換。'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_note_outlined),
                  title: Text('筆記編輯器'),
                  subtitle: Text('一般筆記使用 Rich Text template 風格的整合編輯面板。'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocalDataManagementCard extends StatefulWidget {
  const LocalDataManagementCard({super.key});

  @override
  State<LocalDataManagementCard> createState() =>
      _LocalDataManagementCardState();
}

class _LocalDataManagementCardState extends State<LocalDataManagementCard> {
  bool busy = false;

  Future<void> exportData() async {
    setState(() => busy = true);
    try {
      final raw = await AppStoreScope.read(context).exportBundle();
      final now = DateTime.now();
      final fileName =
          'my_note_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final location = await NoteFileService.saveBytes(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
      if (!mounted) return;
      showToast(context, location == null ? '已取消匯出' : '資料已匯出');
    } catch (_) {
      if (mounted) showToast(context, '匯出資料失敗');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('匯入本機資料？'),
        content: const Text('目前資料會先建立可復原備份，再套用選擇的匯出檔。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('匯入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null) {
        if (mounted) showToast(context, '未選擇匯入檔');
        return;
      }
      if (!mounted) return;
      final result = await AppStoreScope.read(
        context,
      ).importBundle(utf8.decode(bytes, allowMalformed: false));
      if (!mounted) return;
      showToast(
        context,
        '已匯入 ${result.noteCount} 筆筆記、${result.scheduleCount} 筆行程與 ${result.todoCount} 項待辦',
      );
    } on FormatException catch (error) {
      if (mounted) showToast(context, error.message);
    } catch (_) {
      if (mounted) showToast(context, '匯入資料失敗');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showRecoveryHistory() async {
    final store = AppStoreScope.read(context);
    setState(() => busy = true);
    List<LocalBackupSnapshot> snapshots = const [];
    try {
      snapshots = await store.recoverySnapshots();
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('復原備份'),
        content: SizedBox(
          width: 420,
          child: snapshots.isEmpty
              ? const Text('目前沒有可復原的備份。')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: snapshots.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (_, index) {
                    final snapshot = snapshots[index];
                    return ListTile(
                      title: Text(
                        '${formatDate(snapshot.savedAt)} ${formatTime(snapshot.savedAt)}',
                      ),
                      subtitle: Text(
                        '${snapshot.noteCount} 筆筆記、${snapshot.scheduleCount} 筆行程、${snapshot.todoCount} 項待辦',
                      ),
                      trailing: const Icon(Icons.restore),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: dialogContext,
                          builder: (confirmContext) => AlertDialog(
                            title: const Text('復原這份備份？'),
                            content: const Text('目前資料會先建立新備份，再復原選擇的內容。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(confirmContext, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(confirmContext, true),
                                child: const Text('復原'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        try {
                          final result = await store.restoreRecoverySnapshot(
                            snapshot,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          showToast(
                            dialogContext,
                            '已復原 ${result.noteCount} 筆筆記、${result.scheduleCount} 筆行程與 ${result.todoCount} 項待辦',
                          );
                          Navigator.pop(dialogContext);
                        } catch (_) {
                          if (mounted && dialogContext.mounted) {
                            showToast(dialogContext, '復原備份失敗');
                          }
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('本機資料與備份'),
            subtitle: const Text('資料保留於裝置，可匯出 JSON 備份並在匯入前建立復原點。'),
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('匯出資料'),
            subtitle: const Text('建立可攜 JSON 備份檔'),
            trailing: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: busy ? null : exportData,
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('匯入資料'),
            subtitle: const Text('匯入 JSON 備份；目前資料會先備份'),
            onTap: busy ? null : importData,
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_outlined),
            title: const Text('復原備份'),
            subtitle: const Text('檢視並復原本機備份歷程'),
            onTap: busy ? null : showRecoveryHistory,
          ),
        ],
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.titleWidget,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? titleWidget;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffe1e6f3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: leading!,
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget ??
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xff171f2f),
                              ),
                        ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff687386),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back),
    );
  }
}

class EditorActionButtons extends StatelessWidget {
  const EditorActionButtons({
    super.key,
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            label: const Text('取消'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: const Text('儲存'),
          ),
        ),
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xffe4e8f5)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class AddBubbleButton extends StatelessWidget {
  const AddBubbleButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.heroTag,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      shape: const CircleBorder(),
      tooltip: tooltip,
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

class AnimatedQuickAddFab extends StatelessWidget {
  const AnimatedQuickAddFab({
    super.key,
    required this.tooltip,
    required this.controller,
    required this.onPressed,
    this.heroTag,
  });

  final String tooltip;
  final AnimationController controller;
  final VoidCallback onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return FloatingActionButton(
          heroTag: heroTag,
          shape: const CircleBorder(),
          tooltip: tooltip,
          onPressed: onPressed,
          child: Transform.rotate(
            angle: controller.value * math.pi * 0.75,
            child: child,
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

class FloatingActionMenuItem {
  const FloatingActionMenuItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onSelected;
}

class DismissFabMenuLayer extends StatelessWidget {
  const DismissFabMenuLayer({
    super.key,
    required this.isOpen,
    required this.onDismiss,
    required this.child,
  });

  final bool isOpen;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isOpen)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => onDismiss(),
            ),
          ),
      ],
    );
  }
}

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.tooltip,
    required this.onToggle,
    required this.items,
    this.heroTag,
  });

  final bool isOpen;
  final AnimationController controller;
  final String tooltip;
  final VoidCallback onToggle;
  final List<FloatingActionMenuItem> items;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IgnorePointer(
          ignoring: !isOpen,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isOpen
                ? Column(
                    key: const ValueKey('fab-menu-open'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        FloatingActionMenuPill(
                          key: ValueKey(items[index].value),
                          item: items[index],
                          index: index,
                          totalCount: items.length,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('fab-menu-closed')),
          ),
        ),
        AnimatedQuickAddFab(
          tooltip: tooltip,
          controller: controller,
          onPressed: onToggle,
          heroTag: heroTag,
        ),
      ],
    );
  }
}

class FloatingActionMenuPill extends StatefulWidget {
  const FloatingActionMenuPill({
    super.key,
    required this.item,
    required this.index,
    required this.totalCount,
  });

  final FloatingActionMenuItem item;
  final int index;
  final int totalCount;

  @override
  State<FloatingActionMenuPill> createState() => _FloatingActionMenuPillState();
}

class _FloatingActionMenuPillState extends State<FloatingActionMenuPill> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    final delayIndex = widget.totalCount - widget.index - 1;
    Future<void>.delayed(Duration(milliseconds: delayIndex * 100), () {
      if (mounted) {
        setState(() => visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: Offset(visible ? 0 : 0.26, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Material(
          color: colorScheme.surface,
          elevation: 7,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => widget.item.onSelected(widget.item.value),
            child: Container(
              width: 190,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.72),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.item.icon, size: 22, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuickAddPanel extends StatelessWidget {
  const QuickAddPanel({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '快速新增',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              QuickAddOption(
                icon: Icons.notes,
                title: '新增筆記',
                value: 'note',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.add_task,
                title: '新增待辦事項',
                value: 'todo',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.payments_outlined,
                title: '新增記帳',
                value: 'finance',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.subscriptions_outlined,
                title: '新增訂閱費用',
                value: 'subscription',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.event_note,
                title: '新增行程',
                value: 'schedule',
                onSelected: onSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwipeDeleteTile extends StatefulWidget {
  const SwipeDeleteTile({
    super.key,
    required this.itemKey,
    required this.child,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onDelete,
  });

  final String itemKey;
  final Widget child;
  final String confirmTitle;
  final String confirmMessage;
  final VoidCallback onDelete;

  @override
  State<SwipeDeleteTile> createState() => _SwipeDeleteTileState();
}

class _SwipeDeleteTileState extends State<SwipeDeleteTile> {
  static const double actionWidth = 88;

  double dragOffset = 0;

  bool get isOpen => dragOffset <= -actionWidth / 2;

  void settle() {
    setState(() {
      dragOffset = isOpen ? -actionWidth : 0;
    });
  }

  @override
  void didUpdateWidget(covariant SwipeDeleteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey && dragOffset != 0) {
      dragOffset = 0;
    }
  }

  Future<void> requestDelete() async {
    final confirmed = await confirmDelete(
      context,
      title: widget.confirmTitle,
      message: widget.confirmMessage,
    );
    if (!mounted) {
      return;
    }
    if (confirmed) {
      setState(() => dragOffset = 0);
      widget.onDelete();
    } else {
      setState(() => dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                dragOffset = (dragOffset + details.delta.dx).clamp(
                  -actionWidth,
                  0.0,
                );
              });
            },
            onHorizontalDragEnd: (_) => settle(),
            onTap: () {
              if (dragOffset != 0) {
                setState(() => dragOffset = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(dragOffset, 0, 0),
              child: widget.child,
            ),
          ),
          if (dragOffset < 0)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: actionWidth,
              child: Material(
                color: Colors.red.shade700,
                child: InkWell(
                  onTap: requestDelete,
                  child: const Center(
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.delete),
          label: const Text('刪除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmSaveChanges(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('不儲存'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.save_outlined),
          label: const Text('儲存'),
        ),
      ],
    ),
  );
  return result ?? true;
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= 720
          ? 260
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricSummaryRow extends StatelessWidget {
  const MetricSummaryRow({
    super.key,
    required this.items,
    this.style = HomeSectionStyle.list,
    this.forceInline = false,
  });

  final List<MetricInfo> items;
  final HomeSectionStyle style;
  final bool forceInline;

  @override
  Widget build(BuildContext context) {
    if (forceInline) {
      return InfoCard(
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: MetricSummaryCell(item: items[index])),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final item in items)
            SizedBox(
              width: homeGridTileWidth(context),
              child: InfoCard(child: MetricSummaryCell(item: item)),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InfoCard(child: MetricSummaryCell(item: item)),
          ),
      ],
    );
  }
}

class MetricSummaryCell extends StatelessWidget {
  const MetricSummaryCell({super.key, required this.item});

  final MetricInfo item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.icon, color: item.color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.onTap,
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: onTap == null ? 0 : 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        key: ValueKey('section-count-$title'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class SheetBackHeader extends StatelessWidget {
  const SheetBackHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 38, color: Colors.black38),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class ScheduleGroupedList extends StatelessWidget {
  const ScheduleGroupedList({super.key, required this.events});

  final List<ScheduleItem> events;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    if (events.isEmpty) {
      return const EmptyState(icon: Icons.event_busy, text: '尚無行程');
    }

    final grouped = <DateTime, List<ScheduleItem>>{};
    for (final event in events) {
      final day = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      grouped.putIfAbsent(day, () => []).add(event);
    }
    final days = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '行程清單'),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Chip(
              label: Text(
                isSameDate(day, DateTime.now()) ? '今日' : formatDate(day),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          for (final event
              in grouped[day]!..sort((a, b) => a.start.compareTo(b.start)))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ScheduleTile(
                event: event,
                onTap: () => showScheduleEditor(context, event: event),
                onDelete: () => store.deleteSchedule(event),
              ),
            ),
        ],
      ],
    );
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.mode = NotesViewMode.list,
    this.selectable = false,
    this.selected = false,
    this.readOnly = false,
    this.onSelectionChanged,
    this.onDelete,
  });

  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final NotesViewMode mode;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final tile = Card(
      color: selected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.65)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xffe1e5e1)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: switch (mode) {
          NotesViewMode.grid => NoteGridContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
          NotesViewMode.list => NoteListContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
          NotesViewMode.compact => NoteCompactContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
        },
      ),
    );
    if (onDelete == null || selectable) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'note-${note.id}',
      confirmTitle: '刪除筆記？',
      confirmMessage: '確定要刪除這筆筆記嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class NoteListContent extends StatelessWidget {
  const NoteListContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: NoteSelectionOrIcon(
        selectable: selectable,
        selected: selected,
        onChanged: onSelectionChanged,
        icon: noteTemplateIcon(note.templateType),
      ),
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 72),
            child: Text(
              note.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          NoteMetaWrap(note: note),
        ],
      ),
      trailing: readOnly
          ? null
          : NotePinButton(note: note, onPressed: onTogglePinned),
    );
  }
}

class NoteGridContent extends StatelessWidget {
  const NoteGridContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              NoteSelectionOrIcon(
                selectable: selectable,
                selected: selected,
                onChanged: onSelectionChanged,
                icon: noteTemplateIcon(note.templateType),
              ),
              const Spacer(),
              if (!readOnly)
                NotePinButton(
                  note: note,
                  onPressed: onTogglePinned,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (note.category.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class NoteCompactContent extends StatelessWidget {
  const NoteCompactContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoteSelectionOrIcon(
            selectable: selectable,
            selected: selected,
            onChanged: onSelectionChanged,
            icon: noteTemplateIcon(note.templateType),
          ),
          const SizedBox(width: 8),
          NoteBodyThumbnail(body: note.body),
        ],
      ),
      title: Text(
        note.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: readOnly
          ? null
          : NotePinButton(note: note, onPressed: onTogglePinned),
    );
  }
}

class NoteSelectionOrIcon extends StatelessWidget {
  const NoteSelectionOrIcon({
    super.key,
    required this.selectable,
    required this.selected,
    required this.onChanged,
    required this.icon,
  });

  final bool selectable;
  final bool selected;
  final VoidCallback? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!selectable) {
      return Icon(icon);
    }
    return Checkbox(
      value: selected,
      visualDensity: VisualDensity.compact,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

class NotePinButton extends StatelessWidget {
  const NotePinButton({
    super.key,
    required this.note,
    required this.onPressed,
    this.dense = false,
  });

  final NoteItem note;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: note.isPinned ? '取消置頂' : '置頂',
      visualDensity: dense ? VisualDensity.compact : null,
      padding: dense ? EdgeInsets.zero : null,
      constraints: dense
          ? const BoxConstraints.tightFor(width: 32, height: 32)
          : null,
      onPressed: onPressed,
      icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
    );
  }
}

class NoteMetaWrap extends StatelessWidget {
  const NoteMetaWrap({super.key, required this.note});

  final NoteItem note;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (note.category.trim().isNotEmpty)
          Chip(
            label: Text(note.category),
            visualDensity: VisualDensity.compact,
          ),
        for (final tag in note.tags.take(3))
          Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class NoteBodyThumbnail extends StatelessWidget {
  const NoteBodyThumbnail({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final text = body.trim().isEmpty ? '...' : body.trim();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.canRename,
    required this.onDelete,
    required this.onMove,
    required this.onRename,
    required this.onDone,
  });

  final int selectedCount;
  final bool canRename;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final VoidCallback? onRename;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text('已選 $selectedCount 項')),
          FilledButton.tonalIcon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
          FilledButton.tonalIcon(
            onPressed: onMove,
            icon: const Icon(Icons.drive_file_move_outline),
            label: const Text('移動'),
          ),
          if (canRename)
            FilledButton.tonalIcon(
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('重新命名'),
            ),
          TextButton(onPressed: onDone, child: const Text('完成')),
        ],
      ),
    );
  }
}

class TrashBatchActionBar extends StatelessWidget {
  const TrashBatchActionBar({
    super.key,
    required this.selectedCount,
    required this.onRestore,
    required this.onDelete,
    required this.onDone,
  });

  final int selectedCount;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text('已選 $selectedCount 筆')),
          FilledButton.tonalIcon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore),
            label: const Text('復原'),
          ),
          FilledButton.tonalIcon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('刪除'),
          ),
          TextButton(onPressed: onDone, child: const Text('完成')),
        ],
      ),
    );
  }
}

class NotesSortOption {
  const NotesSortOption(this.field, this.direction);

  final NotesSortField field;
  final SortDirection direction;
}

class NotesSortSummary extends StatelessWidget {
  const NotesSortSummary({
    super.key,
    required this.sortField,
    required this.sortDirection,
    required this.viewMode,
    required this.selectedTemplates,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onTemplateToggled,
  });

  final NotesSortField sortField;
  final SortDirection sortDirection;
  final NotesViewMode viewMode;
  final Set<NoteTemplateType> selectedTemplates;
  final void Function(NotesSortField field, SortDirection direction)
  onSortChanged;
  final ValueChanged<NotesViewMode> onViewModeChanged;
  final ValueChanged<NoteTemplateType> onTemplateToggled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium;
    final currentSortLabel =
        '${notesSortFieldLabel(sortField)} ${sortDirectionSymbol(sortDirection)}';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<NotesSortOption>(
          tooltip: '排序',
          onSelected: (option) => onSortChanged(option.field, option.direction),
          itemBuilder: (context) => [
            for (final field in NotesSortField.values)
              for (final direction in SortDirection.values)
                PopupMenuItem(
                  value: NotesSortOption(field, direction),
                  child: Row(
                    children: [
                      Icon(notesSortFieldIcon(field), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${notesSortFieldLabel(field)} ${sortDirectionSymbol(direction)}',
                        ),
                      ),
                      if (sortField == field && sortDirection == direction)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
          ],
          child: NotesToolbarDropdownChip(
            icon: notesSortFieldIcon(sortField),
            label: '排序：$currentSortLabel',
          ),
        ),
        PopupMenuButton<NotesViewMode>(
          tooltip: '檢視',
          onSelected: onViewModeChanged,
          itemBuilder: (context) => [
            for (final mode in NotesViewMode.values)
              PopupMenuItem(
                value: mode,
                child: Row(
                  children: [
                    Icon(notesViewModeIcon(mode), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(notesViewModeLabel(mode))),
                    if (viewMode == mode) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
          child: NotesToolbarDropdownChip(
            icon: notesViewModeIcon(viewMode),
            label: '檢視：${notesViewModeLabel(viewMode)}',
          ),
        ),
        const SizedBox(width: 2),
        for (final type in NoteTemplateType.values)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onTemplateToggled(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selectedTemplates.contains(type)
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.primary),
              ),
              child: Text(
                noteTemplateLabel(type),
                style: textStyle?.copyWith(
                  color: selectedTemplates.contains(type)
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotesToolbarDropdownChip extends StatelessWidget {
  const NotesToolbarDropdownChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String noteDateFilterLabel(NotesDateFilter filter) {
  return switch (filter) {
    NotesDateFilter.all => '全部',
    NotesDateFilter.oneDay => '過去 1 日',
    NotesDateFilter.sevenDays => '過去 7 日',
    NotesDateFilter.thirtyDays => '過去 30 日',
  };
}

String notesViewModeLabel(NotesViewMode mode) {
  return switch (mode) {
    NotesViewMode.grid => '格線',
    NotesViewMode.list => '清單',
    NotesViewMode.compact => '簡易清單',
  };
}

IconData notesViewModeIcon(NotesViewMode mode) {
  return switch (mode) {
    NotesViewMode.grid => Icons.grid_view,
    NotesViewMode.list => Icons.view_list,
    NotesViewMode.compact => Icons.view_headline,
  };
}

String notesSortFieldLabel(NotesSortField field) {
  return switch (field) {
    NotesSortField.createdAt => '建立日期',
    NotesSortField.updatedAt => '修改日期',
    NotesSortField.title => '名稱',
    NotesSortField.tag => '標籤',
  };
}

IconData notesSortFieldIcon(NotesSortField field) {
  return switch (field) {
    NotesSortField.createdAt => Icons.event_available_outlined,
    NotesSortField.updatedAt => Icons.history_outlined,
    NotesSortField.title => Icons.sort_by_alpha,
    NotesSortField.tag => Icons.sell_outlined,
  };
}

String sortDirectionSymbol(SortDirection direction) {
  return switch (direction) {
    SortDirection.ascending => '↑',
    SortDirection.descending => '↓',
  };
}

Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => StableTextPromptDialog(
      title: title,
      label: label,
      initialValue: initialValue,
    ),
  );
}

Future<String?> promptForFolderName(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => StableFolderNamePromptDialog(
      title: title,
      label: label,
      initialValue: initialValue,
    ),
  );
}

class StableTextPromptDialog extends StatefulWidget {
  const StableTextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<StableTextPromptDialog> createState() => _StableTextPromptDialogState();
}

class _StableTextPromptDialogState extends State<StableTextPromptDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(context).pop(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: submit, child: const Text('確認')),
      ],
    );
  }
}

class StableFolderNamePromptDialog extends StatefulWidget {
  const StableFolderNamePromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<StableFolderNamePromptDialog> createState() =>
      _StableFolderNamePromptDialogState();
}

class _StableFolderNamePromptDialogState
    extends State<StableFolderNamePromptDialog> {
  late final TextEditingController controller;
  bool limitExceeded = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: limitFolderNameForStorage(widget.initialValue),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void updateLimitExceeded(String value) {
    final exceeded = !folderNameWithinLengthLimit(value);
    if (limitExceeded != exceeded) {
      setState(() => limitExceeded = exceeded);
    }
  }

  void submit() {
    final value = controller.text.trim();
    if (!folderNameWithinLengthLimit(value)) {
      if (!limitExceeded) {
        setState(() => limitExceeded = true);
      }
      return;
    }
    Navigator.of(context).pop(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: '最多 18 個半形字或 12 個全形字',
          errorText: limitExceeded ? '資料夾名稱已達長度上限' : null,
        ),
        onChanged: updateLimitExceeded,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: limitExceeded ? null : submit,
          child: const Text('確認'),
        ),
      ],
    );
  }
}

Future<String?> chooseFolder(
  BuildContext context,
  AppStore store, {
  String title = '選擇資料夾',
  String excludedFolder = '',
  String rootLabel = '未分類',
}) async {
  final excluded = normalizeFolderPath(excludedFolder);
  final folders =
      store.folderPaths
          .where(
            (folder) => excluded.isEmpty || !folderContains(excluded, folder),
          )
          .toList()
        ..sort();
  var currentFolder = '';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) {
        final childFolders = folders
            .where((folder) => folderParentPath(folder) == currentFolder)
            .toList(growable: false);
        final canGoBack = currentFolder.isNotEmpty;
        final currentLabel = currentFolder.isEmpty
            ? rootLabel
            : folderBaseName(currentFolder);
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentFolder.isEmpty
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentFolder.isEmpty
                              ? rootLabel
                              : currentFolder.replaceAll('/', '\\'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (canGoBack)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_back),
                            title: const Text('上一層'),
                            onTap: () => setLocalState(
                              () => currentFolder = folderParentPath(
                                currentFolder,
                              ),
                            ),
                          ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text('移到這裡'),
                          subtitle: Text(currentLabel),
                          onTap: () => Navigator.pop(context, currentFolder),
                        ),
                        const Divider(height: 16),
                        if (childFolders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              '此層沒有子資料夾',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.black54),
                            ),
                          )
                        else
                          for (final folder in childFolders)
                            ListTile(
                              leading: Icon(
                                Icons.folder_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(folderBaseName(folder)),
                              subtitle: Text(folder.replaceAll('/', '\\')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  setLocalState(() => currentFolder = folder),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton.icon(
              onPressed: () async {
                final name = await promptForFolderName(
                  context,
                  title: '新增資料夾',
                  label: '資料夾名稱',
                );
                if (name == null || name.trim().isEmpty) {
                  return;
                }
                final newFolder = joinFolderPath(
                  currentFolder,
                  limitFolderNameForStorage(name),
                );
                store.createNoteFolder(newFolder);
                setLocalState(() => currentFolder = newFolder);
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新增資料夾'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, currentFolder),
              child: const Text('移到這裡'),
            ),
          ],
        );
      },
    ),
  );
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.event,
    required this.onTap,
    this.onDelete,
  });

  final ScheduleItem event;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.event_note),
        title: Text(event.title),
        subtitle: Text(
          '${formatDate(event.start)}  ${formatTime(event.start)} - ${formatTime(event.end)}\n${event.location}  提前 ${event.remindBeforeMinutes} 分鐘提醒',
        ),
        isThreeLine: true,
      ),
    );
    if (onDelete == null) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'schedule-${event.id}',
      confirmTitle: '刪除行程？',
      confirmMessage: '確定要刪除這筆行程嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class FinanceTile extends StatelessWidget {
  const FinanceTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  final FinanceEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == EntryType.income;
    final accountLabel = entry.account.trim().isEmpty ? '未指定帳戶' : entry.account;
    final detailParts = [
      if (isIncome) '收入' else entry.category,
      formatTime(entry.date),
    ].where((item) => item.trim().isNotEmpty).toList();
    final tile = Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: isIncome ? Colors.green : Colors.red,
        ),
        title: Text(entry.title),
        subtitle: Text(detailParts.join(' / ')),
        trailing: Text(
          '($accountLabel ${isIncome ? '+' : '-'}${currency(entry.amount)})',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
    if (onDelete == null) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'finance-${entry.id}',
      confirmTitle: '刪除記帳？',
      confirmMessage: '確定要刪除這筆記帳紀錄嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class CalendarPeriodSelector extends StatelessWidget {
  const CalendarPeriodSelector({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: const Color(0xffe4e8f5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一個期間',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: onPickMonth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一個期間',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class CalendarSwipeRegion extends StatefulWidget {
  const CalendarSwipeRegion({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  State<CalendarSwipeRegion> createState() => _CalendarSwipeRegionState();
}

class _CalendarSwipeRegionState extends State<CalendarSwipeRegion> {
  double horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => horizontalDragDistance = 0,
      onHorizontalDragUpdate: (details) {
        horizontalDragDistance += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (horizontalDragDistance <= -48 || velocity <= -150) {
          widget.onNext();
        } else if (horizontalDragDistance >= 48 || velocity >= 150) {
          widget.onPrevious();
        }
        horizontalDragDistance = 0;
      },
      onHorizontalDragCancel: () => horizontalDragDistance = 0,
      child: widget.child,
    );
  }
}

class CalendarMonthPickerDialog extends StatefulWidget {
  const CalendarMonthPickerDialog({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<CalendarMonthPickerDialog> createState() =>
      _CalendarMonthPickerDialogState();
}

class _CalendarMonthPickerDialogState extends State<CalendarMonthPickerDialog> {
  late int visibleYear;

  @override
  void initState() {
    super.initState();
    visibleYear = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Row(
        children: [
          IconButton(
            tooltip: '上一年',
            onPressed: () => setState(() => visibleYear--),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '$visibleYear年',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '下一年',
            onPressed: () => setState(() => visibleYear++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.75,
          children: [
            for (var month = 1; month <= 12; month++)
              Builder(
                builder: (context) {
                  final selected =
                      visibleYear == widget.initialMonth.year &&
                      month == widget.initialMonth.month;
                  return selected
                      ? FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DateTime(visibleYear, month),
                          ),
                          child: Text('$month月'),
                        )
                      : OutlinedButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DateTime(visibleYear, month),
                          ),
                          child: Text('$month月'),
                        );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class MonthStrip extends StatelessWidget {
  const MonthStrip({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<ScheduleItem> events;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(selectedDate.year, selectedDate.month);
    final daysInMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      0,
    ).day;
    final offset = firstDay.weekday % 7;
    final colors = Theme.of(context).colorScheme;
    return InfoCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final label in const ['日', '一', '二', '三', '四', '五', '六'])
                Expanded(
                  child: SizedBox(
                    height: 26,
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxWidth >= 720 ? 86.0 : 70.0;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: cellHeight,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: offset + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < offset) {
                    return const SizedBox.shrink();
                  }
                  final day = index - offset + 1;
                  final date = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    day,
                  );
                  final dayEvents = events
                      .where((event) => isSameDate(event.start, date))
                      .toList(growable: false);
                  final visibleDayEvents = dayEvents
                      .take(3)
                      .toList(growable: false);
                  final selected = isSameDate(date, selectedDate);
                  final today = isSameDate(date, now);
                  final foreground = selected
                      ? colors.primary
                      : colors.onSurface;
                  final eventLabelHeight = cellHeight >= 80 ? 17.0 : 13.0;
                  final eventFontSize = cellHeight >= 80 ? 10.0 : 8.0;
                  return InkWell(
                    onTap: () => onDateSelected(date),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      key: ValueKey(
                        'calendar-day-${date.year}-${date.month}-${date.day}',
                      ),
                      decoration: BoxDecoration(
                        color: !selected && today
                            ? colors.primaryContainer
                            : const Color(0xfff1f3ef),
                        border: Border.all(
                          color: selected ? colors.primary : Colors.transparent,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 5,
                            left: 6,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (visibleDayEvents.isNotEmpty)
                            Positioned.fill(
                              top: 20,
                              left: 3,
                              right: 3,
                              bottom: 3,
                              child: Column(
                                key: ValueKey(
                                  'calendar-events-${date.year}-${date.month}-${date.day}',
                                ),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (
                                    var eventIndex = 0;
                                    eventIndex < visibleDayEvents.length;
                                    eventIndex++
                                  ) ...[
                                    Container(
                                      key: ValueKey(
                                        'calendar-event-${visibleDayEvents[eventIndex].id}',
                                      ),
                                      height: eventLabelHeight,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: 0.09,
                                        ),
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        visibleDayEvents[eventIndex].title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: eventFontSize,
                                          height: 1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (eventIndex <
                                        visibleDayEvents.length - 1)
                                      const SizedBox(height: 1),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<ScheduleItem> events;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekStart = calendarWeekStart(selectedDate);
    return InfoCard(
      child: Row(
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final dayEvents = events
              .where((event) => isSameDate(event.start, date))
              .toList(growable: false);
          final selected = isSameDate(date, selectedDate);
          final isToday = isSameDate(date, today);
          return Expanded(
            child: InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                key: ValueKey(
                  'calendar-week-day-${date.year}-${date.month}-${date.day}',
                ),
                height: 96,
                margin: EdgeInsets.only(right: index == 6 ? 0 : 2),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday && !selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xfff1f3ef),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(
                      weekdayLabel(date.weekday),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (dayEvents.isNotEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            dayEvents.first.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.15,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ExpenseBarChart extends StatelessWidget {
  const ExpenseBarChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final maxValue = grouped.values.fold(
      0.0,
      (max, value) => value > max ? value : max,
    );
    return Column(
      children: grouped.entries.map((entry) {
        final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: ratio, minHeight: 12),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: Text(currency(entry.value), textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final total = grouped.values.fold(0.0, (sum, value) => sum + value);
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.donut_large_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('其他')),
            Text(
              currency(total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in sorted)
          ExpenseCategoryRingRow(
            label: entry.key,
            amount: entry.value,
            ratio: total == 0 ? 0 : entry.value / total,
          ),
      ],
    );
  }
}

class IncomeAccountBarChart extends StatelessWidget {
  const IncomeAccountBarChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sorted.isEmpty ? 0.0 : sorted.first.value;
    final total = grouped.values.fold(0.0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart),
            const SizedBox(width: 8),
            const Expanded(child: Text('本月收入')),
            Text(
              currency(total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final entry in sorted)
          IncomeAccountBarRow(
            label: entry.key,
            amount: entry.value,
            ratio: maxAmount <= 0 ? 0 : entry.value / maxAmount,
          ),
      ],
    );
  }
}

class IncomeAccountBarRow extends StatelessWidget {
  const IncomeAccountBarRow({
    super.key,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final String label;
  final double amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor('收入$label');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(currency(amount)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xffe8eee9)),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.04, 1.0),
                  child: Container(height: 16, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseCategoryRingRow extends StatelessWidget {
  const ExpenseCategoryRingRow({
    super.key,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final String label;
  final double amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CustomPaint(
              painter: ExpenseRingPainter(
                color: categoryColor(label),
                ratio: ratio.clamp(0.0, 1.0),
              ),
              child: Center(
                child: Text(
                  '${(ratio * 100).round()}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(currency(amount)),
        ],
      ),
    );
  }
}

class ExpenseRingPainter extends CustomPainter {
  ExpenseRingPainter({required this.color, required this.ratio});

  final Color color;
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xffe6ebe6);
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.butt
      ..color = color;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(rect, -math.pi / 2, ratio * math.pi * 2, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant ExpenseRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.ratio != ratio;
  }
}

class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 12, backgroundColor: categoryColor(label));
  }
}

Color categoryColor(String label) {
  if (label.contains('食物')) return const Color(0xffe53935);
  if (label.contains('交通')) return const Color(0xffff9800);
  if (label.contains('娛樂')) return const Color(0xff8e24aa);
  if (label.contains('訂閱')) return const Color(0xff00897b);
  if (label.contains('學習')) return const Color(0xff3949ab);
  if (label.contains('收入')) return const Color(0xff43a047);
  const colors = [
    Color(0xffd81b60),
    Color(0xff1e88e5),
    Color(0xffffb300),
    Color(0xff6d4c41),
    Color(0xff00acc1),
    Color(0xff7cb342),
  ];
  return colors[label.hashCode.abs() % colors.length];
}

String noteTemplateMenuValue(NoteTemplateType type) => 'note-${type.name}';

NoteTemplateType? noteTemplateTypeFromMenuValue(String value) {
  if (!value.startsWith('note-')) {
    return null;
  }
  final name = value.substring(5);
  for (final type in NoteTemplateType.values) {
    if (type.name == name) {
      return type;
    }
  }
  return null;
}

Future<void> showNoteEditor(
  BuildContext context, {
  NoteItem? note,
  String initialFolder = '',
  String? returnFolder,
  NoteTemplateType initialTemplateType = NoteTemplateType.general,
  bool readOnly = false,
}) async {
  final navigation = AppNavigationScope.maybeOf(context);
  final targetFolder =
      returnFolder ??
      (note != null
          ? note.category
          : initialFolder.isEmpty
          ? '所有筆記'
          : initialFolder);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => NoteEditorPage(
        note: note,
        initialFolder: initialFolder,
        initialTemplateType: note == null
            ? initialTemplateType
            : note.templateType,
        readOnly: readOnly,
      ),
    ),
  );
  navigation?.onOpenNotesLocation(
    targetFolder,
    showTrash: note?.deletedAt != null,
  );
}

Future<void> showScheduleEditor(
  BuildContext context, {
  ScheduleItem? event,
  DateTime? initialDate,
}) async {
  final navigation = AppNavigationScope.maybeOf(context);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          ScheduleEditorPage(event: event, initialDate: initialDate),
    ),
  );
  navigation?.onNavigate(1);
}

Future<void> showFinanceEditor(
  BuildContext context, {
  FinanceEntry? entry,
}) async {
  final navigation = AppNavigationScope.maybeOf(context);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => FinanceEditorPage(entry: entry),
    ),
  );
  navigation?.onNavigate(3);
}

Future<void> showNoteEditorSheet(BuildContext context, {NoteItem? note}) async {
  final store = AppStoreScope.of(context);
  final title = TextEditingController(text: note?.title ?? '');
  final body = TextEditingController(text: note?.body ?? '');
  final category = TextEditingController(text: note?.category ?? '');
  final tags = TextEditingController(
    text: formatTagsForEditing(note?.tags ?? []),
  );
  var pinned = note?.isPinned ?? false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note == null ? '新增筆記' : '編輯筆記',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '內容',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: '分類',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: '#標籤',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  value: pinned,
                  onChanged: (value) => setLocalState(() => pinned = value),
                  title: const Text('置頂'),
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      store.upsertNote(
                        NoteItem(
                          id: note?.id ?? store.newId('n'),
                          title: title.text.trim().isEmpty
                              ? '未命名筆記'
                              : title.text.trim(),
                          body: body.text.trim(),
                          category: category.text.trim().isEmpty
                              ? '未分類'
                              : category.text.trim(),
                          tags: splitTags(tags.text),
                          createdAt: note?.createdAt ?? now,
                          updatedAt: now,
                          isPinned: pinned,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('儲存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showScheduleEditorSheet(
  BuildContext context, {
  ScheduleItem? event,
  DateTime? initialDate,
}) async {
  final store = AppStoreScope.of(context);
  final title = TextEditingController(text: event?.title ?? '');
  final location = TextEditingController(text: event?.location ?? '');
  final notes = TextEditingController(text: event?.notes ?? '');
  var date = event?.start ?? initialDate ?? DateTime.now();
  var startHour = event?.start.hour ?? DateTime.now().hour + 1;
  var reminder = event?.remindBeforeMinutes ?? 30;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event == null ? '新增行程' : '編輯行程',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.today),
                  title: Text(formatDate(date)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                      initialDate: date,
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                DropdownMenu<int>(
                  initialSelection: startHour.clamp(0, 23),
                  label: const Text('開始時間'),
                  dropdownMenuEntries: List.generate(
                    24,
                    (hour) => DropdownMenuEntry(
                      value: hour,
                      label: '${hour.toString().padLeft(2, '0')}:00',
                    ),
                  ),
                  onSelected: (value) =>
                      setLocalState(() => startHour = value ?? startHour),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: '地點',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '備註',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownMenu<int>(
                  initialSelection: reminder,
                  label: const Text('提醒'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 0, label: '不提醒'),
                    DropdownMenuEntry(value: 10, label: '10 分鐘前'),
                    DropdownMenuEntry(value: 30, label: '30 分鐘前'),
                    DropdownMenuEntry(value: 60, label: '1 小時前'),
                    DropdownMenuEntry(value: 1440, label: '1 天前'),
                  ],
                  onSelected: (value) =>
                      setLocalState(() => reminder = value ?? reminder),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final start = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        startHour,
                      );
                      store.upsertSchedule(
                        ScheduleItem(
                          id: event?.id ?? store.newId('s'),
                          title: title.text.trim().isEmpty
                              ? '未命名行程'
                              : title.text.trim(),
                          start: start,
                          end: start.add(const Duration(hours: 1)),
                          location: location.text.trim(),
                          notes: notes.text.trim(),
                          remindBeforeMinutes: reminder,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('儲存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showFinanceEditorSheet(
  BuildContext context, {
  FinanceEntry? entry,
}) async {
  final store = AppStoreScope.of(context);
  final title = TextEditingController(text: entry?.title ?? '');
  final amount = TextEditingController(
    text: entry == null ? '' : entry.amount.toStringAsFixed(0),
  );
  final note = TextEditingController(text: entry?.note ?? '');
  var type = entry?.type ?? EntryType.expense;
  var category = entry?.category ?? '食物';
  var account = entry?.account ?? '';
  var date = entry?.date ?? DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final accountOptions = financeAccountOptions(
            store,
            currentAccount: account,
            includeCurrent: entry != null,
          );
          if (!accountOptions.contains(account)) {
            account = accountOptions.first;
          }
          Widget fieldBox(Widget child, {double width = 156}) {
            return SizedBox(width: width, child: child);
          }

          Widget metaButton({
            required IconData icon,
            required String label,
            required Future<void> Function() onPressed,
            double width = 148,
          }) {
            return SizedBox(
              width: width,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry == null ? '新增記帳' : '編輯記帳',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<EntryType>(
                    segments: const [
                      ButtonSegment(
                        value: EntryType.expense,
                        label: Text('支出'),
                        icon: Icon(Icons.remove),
                      ),
                      ButtonSegment(
                        value: EntryType.income,
                        label: Text('收入'),
                        icon: Icon(Icons.add),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) =>
                        setLocalState(() => type = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: moneyInputFormatters(),
                    decoration: const InputDecoration(
                      labelText: '金額',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (type == EntryType.expense)
                        fieldBox(
                          DropdownMenu<String>(
                            width: 156,
                            initialSelection: category,
                            label: const Text('分類'),
                            dropdownMenuEntries:
                                const ['食物', '交通', '娛樂', '訂閱', '學習', '生活', '其他']
                                    .map(
                                      (item) => DropdownMenuEntry(
                                        value: item,
                                        label: item,
                                      ),
                                    )
                                    .toList(),
                            onSelected: (value) => setLocalState(
                              () => category = value ?? category,
                            ),
                          ),
                        ),
                      fieldBox(
                        DropdownMenu<String>(
                          width: 156,
                          initialSelection: account,
                          label: const Text('帳戶'),
                          dropdownMenuEntries: accountOptions
                              .map(
                                (item) =>
                                    DropdownMenuEntry(value: item, label: item),
                              )
                              .toList(),
                          onSelected: (value) =>
                              setLocalState(() => account = value ?? account),
                        ),
                      ),
                      metaButton(
                        icon: Icons.today_outlined,
                        label: formatDate(date),
                        onPressed: () async {
                          final picked = await showAppDatePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                            initialDate: date,
                          );
                          if (picked != null) {
                            setLocalState(
                              () => date = combinePickedDateWithCurrentTime(
                                picked,
                                date,
                              ),
                            );
                          }
                        },
                      ),
                      metaButton(
                        icon: Icons.schedule,
                        label: formatTime(date),
                        width: 128,
                        onPressed: () async {
                          final picked = await showAppTimePicker(
                            context,
                            initialTime: timeOfDate(date),
                            helpText: '選擇記帳時間',
                          );
                          if (picked != null) {
                            setLocalState(
                              () => date = combineDateAndTime(date, picked),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '備註',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final selectedAccount = accountOptions.contains(account)
                            ? account
                            : accountOptions.first;
                        store.upsertFinanceEntry(
                          FinanceEntry(
                            id: entry?.id ?? store.newId('f'),
                            type: type,
                            title: title.text.trim().isEmpty
                                ? '未命名記帳'
                                : title.text.trim(),
                            amount: double.tryParse(amount.text) ?? 0,
                            category: type == EntryType.income
                                ? '收入'
                                : category,
                            account: selectedAccount,
                            date: date,
                            note: note.text.trim(),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('儲存'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showSubscriptionManager(BuildContext context) async {
  final store = AppStoreScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            '訂閱管理',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          InfoCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每月訂閱總額'),
              subtitle: const Text('依月費與年費換算估計'),
              trailing: Text(
                currency(store.monthlySubscriptionTotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in store.upcomingSubscriptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SwipeDeleteTile(
                itemKey: 'subscription-${item.id}',
                confirmTitle: '刪除訂閱？',
                confirmMessage: '這筆訂閱會從列表移除。',
                onDelete: () => store.deleteSubscription(item),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.subscriptions),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.category} / ${item.paymentMethod}\n下次付款 ${formatDate(item.nextPaymentDate)}  提前 ${item.reminderDays} 天提醒',
                    ),
                    isThreeLine: true,
                    trailing: Text(currency(item.amount)),
                    onTap: () =>
                        showSubscriptionEditor(context, subscription: item),
                  ),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: () => showSubscriptionEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('新增訂閱'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSubscriptionEditor(
  BuildContext context, {
  SubscriptionItem? subscription,
}) async {
  final navigation = AppNavigationScope.maybeOf(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SubscriptionEditorDialog(
      store: AppStoreScope.read(context),
      subscription: subscription,
    ),
  );
  navigation?.onNavigate(3);
}

class SubscriptionEditorDialog extends StatefulWidget {
  const SubscriptionEditorDialog({
    super.key,
    required this.store,
    this.subscription,
  });

  final AppStore store;
  final SubscriptionItem? subscription;

  @override
  State<SubscriptionEditorDialog> createState() =>
      _SubscriptionEditorDialogState();
}

class _SubscriptionEditorDialogState extends State<SubscriptionEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;
  late final TextEditingController paymentMethodController;
  late final TextEditingController categoryController;
  late SubscriptionCycle cycle;
  late DateTime date;
  late int reminderDays;
  late bool active;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    nameController = TextEditingController(text: subscription?.name ?? '');
    amountController = TextEditingController(
      text: subscription == null ? '' : subscription.amount.toStringAsFixed(0),
    );
    paymentMethodController = TextEditingController(
      text: subscription?.paymentMethod ?? '信用卡',
    );
    categoryController = TextEditingController(
      text: subscription?.category ?? '訂閱',
    );
    cycle = subscription?.cycle ?? SubscriptionCycle.monthly;
    date =
        subscription?.nextPaymentDate ??
        DateTime.now().add(const Duration(days: 30));
    reminderDays = subscription?.reminderDays ?? 3;
    active = subscription?.isActive ?? true;
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    paymentMethodController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  void submit() {
    final subscription = widget.subscription;
    final item = SubscriptionItem(
      id: subscription?.id ?? widget.store.newId('sub'),
      name: nameController.text.trim().isEmpty
          ? '未命名訂閱'
          : nameController.text.trim(),
      amount: double.tryParse(amountController.text) ?? 0,
      cycle: cycle,
      nextPaymentDate: date,
      paymentMethod: paymentMethodController.text.trim(),
      category: categoryController.text.trim(),
      reminderDays: reminderDays,
      isActive: active,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.upsertSubscription(item);
    });
  }

  Future<void> pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: date,
    );
    if (picked != null && mounted) {
      setState(() => date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.subscription == null;
    return AlertDialog(
      title: Text(isNew ? '新增訂閱' : '編輯訂閱'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '訂閱名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: moneyInputFormatters(),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '金額',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<SubscriptionCycle>(
                segments: const [
                  ButtonSegment(
                    value: SubscriptionCycle.monthly,
                    label: Text('月'),
                  ),
                  ButtonSegment(
                    value: SubscriptionCycle.yearly,
                    label: Text('年'),
                  ),
                  ButtonSegment(
                    value: SubscriptionCycle.custom,
                    label: Text('自訂'),
                  ),
                ],
                selected: {cycle},
                onSelectionChanged: (value) =>
                    setState(() => cycle = value.first),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat),
              title: const Text('下次付款日'),
              subtitle: Text(formatDate(date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: pickDate,
            ),
            TextField(
              controller: paymentMethodController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '付款方式',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '分類',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownMenu<int>(
              initialSelection: reminderDays,
              label: const Text('提醒天數'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 1, label: '1 天前'),
                DropdownMenuEntry(value: 3, label: '3 天前'),
                DropdownMenuEntry(value: 5, label: '5 天前'),
                DropdownMenuEntry(value: 7, label: '7 天前'),
              ],
              onSelected: (value) =>
                  setState(() => reminderDays = value ?? reminderDays),
            ),
            SwitchListTile(
              value: active,
              onChanged: (value) => setState(() => active = value),
              title: const Text('啟用訂閱'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
          label: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.check),
          label: const Text('確認'),
        ),
      ],
    );
  }
}

Future<void> showQuickAddMenu(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '快速新增',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            QuickAddOption(
              icon: Icons.notes,
              title: '新增筆記',
              value: 'note',
              onSelected: Navigator.of(context).pop,
            ),
            QuickAddOption(
              icon: Icons.add_task,
              title: '新增待辦事項',
              value: 'todo',
              onSelected: Navigator.of(context).pop,
            ),
            QuickAddOption(
              icon: Icons.payments_outlined,
              title: '新增記帳',
              value: 'finance',
              onSelected: Navigator.of(context).pop,
            ),
            QuickAddOption(
              icon: Icons.subscriptions_outlined,
              title: '新增訂閱費用',
              value: 'subscription',
              onSelected: Navigator.of(context).pop,
            ),
            QuickAddOption(
              icon: Icons.event_note,
              title: '新增行程',
              value: 'schedule',
              onSelected: Navigator.of(context).pop,
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) {
    return;
  }
  switch (choice) {
    case 'note':
      await showNoteEditor(context);
      break;
    case 'todo':
      await openTodoEditorPage(context);
      break;
    case 'finance':
      await showFinanceEditor(context);
      break;
    case 'subscription':
      await showSubscriptionEditor(context);
      break;
    case 'schedule':
      await showScheduleEditor(context);
      break;
  }
}

Future<void> showBudgetEditor(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        BudgetEditorDialog(store: AppStoreScope.read(context)),
  );
}

class BudgetEditorDialog extends StatefulWidget {
  const BudgetEditorDialog({super.key, required this.store});

  final AppStore store;

  @override
  State<BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<BudgetEditorDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.store.monthlyBudget.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final nextBudget = double.tryParse(controller.text) ?? 0;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.updateBudget(nextBudget);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('調整月預算'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: moneyInputFormatters(),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(
            labelText: '月預算',
            prefixText: r'$ ',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close),
          label: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.check),
          label: const Text('確認'),
        ),
      ],
    );
  }
}

Future<void> showSavingsAccountEditor(
  BuildContext context, {
  SavingsAccount? account,
  bool editName = true,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SavingsAccountEditorDialog(
      store: AppStoreScope.read(context),
      account: account,
      editName: editName,
    ),
  );
}

class SavingsAccountEditorDialog extends StatefulWidget {
  const SavingsAccountEditorDialog({
    super.key,
    required this.store,
    this.account,
    required this.editName,
  });

  final AppStore store;
  final SavingsAccount? account;
  final bool editName;

  @override
  State<SavingsAccountEditorDialog> createState() =>
      _SavingsAccountEditorDialogState();
}

class _SavingsAccountEditorDialogState
    extends State<SavingsAccountEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;

  bool get isNewAccount => widget.account == null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    nameController = TextEditingController(text: account?.name ?? '');
    amountController = TextEditingController(
      text: account == null ? '0' : account.amount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  String get dialogTitle {
    if (isNewAccount) {
      return '新增存餘帳戶';
    }
    return widget.editName ? '編輯帳戶名稱' : '編輯帳戶金額';
  }

  void submit() {
    final account = widget.account;
    if (account == null) {
      final name = nameController.text.trim().isEmpty
          ? '未命名帳戶'
          : nameController.text.trim();
      if (savingsAccountNameExists(widget.store, name)) {
        showDuplicateSavingsAccountNotice(context, name);
        return;
      }
      final nextAccount = SavingsAccount(
        id: widget.store.newId('sa'),
        name: name,
        amount: double.tryParse(amountController.text) ?? 0,
      );
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.store.upsertSavingsAccount(nextAccount);
      });
      return;
    }

    if (widget.editName) {
      final name = nameController.text.trim().isEmpty
          ? account.name
          : nameController.text.trim();
      if (savingsAccountNameExists(widget.store, name, exceptId: account.id)) {
        showDuplicateSavingsAccountNotice(context, name);
        return;
      }
      final nextAccount = SavingsAccount(
        id: account.id,
        name: name,
        amount: account.amount,
      );
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.store.upsertSavingsAccount(nextAccount);
      });
      return;
    }

    final nextAccount = SavingsAccount(
      id: account.id,
      name: account.name,
      amount: double.tryParse(amountController.text) ?? account.amount,
    );
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.upsertSavingsAccount(nextAccount);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(dialogTitle),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNewAccount || widget.editName)
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: isNewAccount
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  if (!isNewAccount) {
                    submit();
                  }
                },
                decoration: const InputDecoration(
                  labelText: '帳戶名稱',
                  border: OutlineInputBorder(),
                ),
              ),
            if (isNewAccount || widget.editName) const SizedBox(height: 12),
            if (isNewAccount || !widget.editName)
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters(),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: '金額',
                  prefixText: r'$ ',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.check),
          label: const Text('確認'),
        ),
      ],
    );
  }
}

Future<void> showSavingsAccountActions(
  BuildContext context,
  SavingsAccount account,
) async {
  final pageContext = context;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('編輯名稱'),
            onTap: () {
              Navigator.pop(context);
              showSavingsAccountEditor(pageContext, account: account);
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('編輯金額'),
            onTap: () {
              Navigator.pop(context);
              showSavingsAccountEditor(
                pageContext,
                account: account,
                editName: false,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: const Text('刪除帳戶'),
            textColor: Colors.red.shade700,
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await confirmDelete(
                pageContext,
                title: '刪除帳戶？',
                message: '確定要刪除「${account.name}」嗎？既有記帳紀錄會保留原本的帳戶文字。',
              );
              if (!confirmed || !pageContext.mounted) {
                return;
              }
              AppStoreScope.of(pageContext).deleteSavingsAccount(account);
            },
          ),
        ],
      ),
    ),
  );
}

class QuickAddOption extends StatelessWidget {
  const QuickAddOption({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onSelected(value),
    );
  }
}

Future<void> openTodoEditorPage(BuildContext context, {TodoItem? todo}) async {
  final navigation = AppNavigationScope.maybeOf(context);
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => TodoEditorPage(todo: todo)));
  navigation?.onNavigate(2);
}

Future<void> showTodoActionSheet(BuildContext context, TodoItem todo) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('編輯'),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('刪除'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('完成'),
            onTap: () => Navigator.pop(context, 'complete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) {
    return;
  }
  final store = AppStoreScope.of(context);
  switch (action) {
    case 'edit':
      await openTodoEditorPage(context, todo: todo);
      break;
    case 'delete':
      store.deleteTodo(todo);
      showToast(context, '刪除待辦事項');
      break;
    case 'complete':
      if (!todo.done) {
        store.toggleTodo(todo);
      }
      showToast(context, '完成待辦');
      break;
  }
}

class TodoEditorPage extends StatefulWidget {
  const TodoEditorPage({super.key, this.todo});

  final TodoItem? todo;

  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late final TextEditingController controller;
  late DateTime? dueDate;
  late bool reminderEnabled;
  late TimeOfDay reminderTime;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    controller = TextEditingController(text: todo?.title ?? '');
    dueDate = todo?.dueDate;
    reminderEnabled = todo?.reminderEnabled ?? false;
    reminderTime = todo?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void saveAndClose() {
    final store = AppStoreScope.of(context);
    final todo = widget.todo;
    if (todo == null) {
      store.addTodo(
        controller.text,
        dueDate: dueDate,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderEnabled ? reminderTime : null,
      );
    } else {
      final title = controller.text.trim();
      todo.title = title.isEmpty ? todo.title : title;
      todo.dueDate = dueDate;
      todo.reminderEnabled = reminderEnabled;
      todo.reminderTime = reminderEnabled ? reminderTime : null;
      store.upsertTodo(todo);
    }
    showToast(context, '完成編輯');
    Navigator.of(context).pop();
  }

  void cancelAndClose() {
    showToast(context, '取消編輯');
    Navigator.of(context).pop();
  }

  Future<void> pickDueDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => dueDate = picked);
    }
  }

  Future<void> pickReminderTime() async {
    final picked = await showAppTimePicker(
      context,
      initialTime: reminderTime,
      helpText: '選擇提醒時間',
    );
    if (picked != null && mounted) {
      setState(() {
        reminderTime = picked;
        reminderEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.todo != null;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoCard(
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: cancelAndClose,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? '編輯待辦' : '新增待辦',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '期限、提醒與內容',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xff687386)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '取消',
                      onPressed: cancelAndClose,
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: '完成',
                      onPressed: saveAndClose,
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: InfoCard(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: '標題',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => saveAndClose(),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('期限'),
                        subtitle: Text(
                          dueDate == null ? '無限期' : formatDate(dueDate!),
                        ),
                        onTap: pickDueDate,
                        trailing: dueDate == null
                            ? null
                            : IconButton(
                                tooltip: '清除期限',
                                onPressed: () => setState(() => dueDate = null),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('提醒'),
                        subtitle: Text(
                          reminderEnabled
                              ? formatTimeOfDayValue(reminderTime)
                              : '未開啟',
                        ),
                        onTap: pickReminderTime,
                        trailing: Switch(
                          value: reminderEnabled,
                          onChanged: (value) =>
                              setState(() => reminderEnabled = value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showTodoDialog(BuildContext context, {TodoItem? todo}) async {
  final store = AppStoreScope.of(context);
  final controller = TextEditingController(text: todo?.title ?? '');
  var dueDate = todo?.dueDate;
  var reminderEnabled = todo?.reminderEnabled ?? false;
  var reminderTime = todo?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => AlertDialog(
        title: Text(todo == null ? '新增待辦' : '編輯待辦'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '內容'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('期限'),
                subtitle: const Text('期限與提醒日期'),
                onTap: () async {
                  final picked = await showAppDatePicker(
                    context: context,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setModalState(() => dueDate = picked);
                  }
                },
                trailing: dueDate == null
                    ? null
                    : IconButton(
                        tooltip: '清除期限',
                        onPressed: () => setModalState(() => dueDate = null),
                        icon: const Icon(Icons.close),
                      ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('提醒'),
                subtitle: Text(
                  reminderEnabled ? formatTimeOfDayValue(reminderTime) : '未開啟',
                ),
                trailing: Switch(
                  value: reminderEnabled,
                  onChanged: (value) =>
                      setModalState(() => reminderEnabled = value),
                ),
                onTap: () async {
                  final picked = await showAppTimePicker(
                    context,
                    initialTime: reminderTime,
                    helpText: '選擇提醒時間',
                  );
                  if (picked != null) {
                    setModalState(() {
                      reminderTime = picked;
                      reminderEnabled = true;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          if (todo != null)
            TextButton.icon(
              onPressed: () async {
                final confirmed = await confirmDelete(
                  context,
                  title: '刪除待辦事項？',
                  message: '確定要刪除這個待辦事項嗎？',
                );
                if (confirmed) {
                  store.deleteTodo(todo);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('刪除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (todo == null) {
                store.addTodo(
                  controller.text,
                  dueDate: dueDate,
                  reminderEnabled: reminderEnabled,
                  reminderTime: reminderEnabled ? reminderTime : null,
                );
              } else {
                todo.title = controller.text.trim().isEmpty
                    ? todo.title
                    : controller.text.trim();
                todo.dueDate = dueDate;
                todo.reminderEnabled = reminderEnabled;
                todo.reminderTime = reminderEnabled ? reminderTime : null;
                store.upsertTodo(todo);
              }
              Navigator.pop(context);
            },
            child: Text(todo == null ? '新增' : '儲存'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Map<String, double> groupExpensesByCategory(List<FinanceEntry> entries) {
  final now = DateTime.now();
  final result = <String, double>{};
  for (final entry in entries) {
    if (entry.type != EntryType.expense ||
        entry.date.year != now.year ||
        entry.date.month != now.month) {
      continue;
    }
    result.update(
      entry.category,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return result;
}

Map<String, double> groupIncomeByAccount(List<FinanceEntry> entries) {
  final now = DateTime.now();
  final result = <String, double>{};
  for (final entry in entries) {
    if (entry.type != EntryType.income ||
        entry.date.year != now.year ||
        entry.date.month != now.month) {
      continue;
    }
    final account = entry.account.trim().isEmpty ? '未指定帳戶' : entry.account;
    result.update(
      account,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return result;
}

Map<DateTime, List<FinanceEntry>> groupFinanceEntriesByDate(
  List<FinanceEntry> entries,
) {
  final result = <DateTime, List<FinanceEntry>>{};
  for (final entry in entries) {
    final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
    result.putIfAbsent(key, () => <FinanceEntry>[]).add(entry);
  }
  return result;
}

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

List<String> splitTags(String value) {
  final hashTags = RegExp(r'#([^\s#]+)')
      .allMatches(value)
      .map((match) => match.group(1)?.trim() ?? '')
      .where((tag) => tag.isNotEmpty)
      .toList();
  final rawTags = hashTags.isNotEmpty
      ? hashTags
      : value
            .split(RegExp(r'\s+'))
            .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), ''))
            .where((tag) => tag.isNotEmpty)
            .toList();
  final uniqueTags = <String>[];
  for (final tag in rawTags) {
    if (!uniqueTags.contains(tag)) {
      uniqueTags.add(tag);
    }
  }
  return uniqueTags;
}

String formatTagsForEditing(List<String> tags) {
  return tags
      .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), ''))
      .where((tag) => tag.isNotEmpty)
      .map((tag) => '#$tag')
      .join(' ');
}

bool stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String limitedFolderNameForDisplay(String value) {
  return _limitFolderName(value.trim(), addEllipsis: true);
}

String folderNameForPathTitle(String value) {
  final normalized = value.trim();
  final buffer = StringBuffer();
  var count = 0;
  for (final rune in normalized.runes) {
    if (count >= 5) {
      break;
    }
    buffer.write(String.fromCharCode(rune));
    count++;
  }
  if (count < normalized.runes.length) {
    buffer.write('…');
  }
  return buffer.toString();
}

bool folderNameWithinLengthLimit(String value) {
  return folderNameLengthUnits(value.trim()) <= folderNameMaxUnits;
}

int folderNameLengthUnits(String value) {
  var units = 0;
  for (final rune in value.trim().runes) {
    units += folderNameLengthUnitsForRune(rune);
  }
  return units;
}

int folderNameLengthUnitsForRune(int rune) => rune > 0xff ? 3 : 2;

String _limitFolderName(String value, {required bool addEllipsis}) {
  const ellipsisUnits = 2;
  var usedUnits = 0;
  final buffer = StringBuffer();
  final normalized = value.trim();
  for (final rune in normalized.runes) {
    final charUnits = folderNameLengthUnitsForRune(rune);
    final limit = addEllipsis
        ? folderNameMaxUnits - ellipsisUnits
        : folderNameMaxUnits;
    if (usedUnits + charUnits > limit) {
      if (addEllipsis && buffer.isNotEmpty) {
        buffer.write('…');
      }
      return buffer.toString();
    }
    buffer.write(String.fromCharCode(rune));
    usedUnits += charUnits;
  }
  return buffer.toString();
}

const folderNameMaxUnits = 36;

class FolderNameLengthInputFormatter extends TextInputFormatter {
  const FolderNameLengthInputFormatter({
    required this.onLimitExceeded,
    required this.onWithinLimit,
  });

  final VoidCallback onLimitExceeded;
  final VoidCallback onWithinLimit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (folderNameWithinLengthLimit(newValue.text)) {
      onWithinLimit();
      return newValue;
    }
    onLimitExceeded();
    return oldValue;
  }
}

String? notesBackTarget(String folder, {bool showingTrash = false}) {
  if (showingTrash) {
    return '所有筆記';
  }
  final normalized = normalizeFolderPath(folder);
  if (folder == '所有筆記') {
    return null;
  }
  if (normalized.isEmpty) {
    return '所有筆記';
  }
  final parent = folderParentPath(normalized);
  return parent.isEmpty ? '所有筆記' : parent;
}

bool noteBelongsToFolder(String category, String folder) {
  return normalizeFolderPath(category) == normalizeFolderPath(folder);
}

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

Future<DateTime?> showCalendarMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => CalendarMonthPickerDialog(initialMonth: initialMonth),
  );
}

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
