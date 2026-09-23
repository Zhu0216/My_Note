import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart' as fbt;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'firebase_options.dart';
import 'data/my_note_data.dart';
import 'ui/app_navigation.dart';
import 'ui/app_store_scope.dart';
import 'ui/formatters.dart';
import 'ui/note_template_metadata.dart';
import 'ui/prompt_dialogs.dart';
import 'ui/shared_components.dart';
import 'ui/todo_display.dart';
import 'services/note_file_service.dart';
import 'features/settings/settings_page.dart';
import 'features/calendar/calendar_page.dart';
import 'features/finance/finance_page.dart';
import 'features/home/home_page.dart';
import 'features/notes/notes_page.dart';

export 'data/my_note_data.dart';
export 'ui/app_navigation.dart';
export 'ui/app_store_scope.dart';
export 'ui/basic_display.dart';
export 'ui/display_components.dart';
export 'ui/calendar_helpers.dart';
export 'ui/calendar_components.dart';
export 'ui/formatters.dart';
export 'ui/finance_charts.dart';
export 'ui/folder_names.dart';
export 'ui/note_template_metadata.dart';
export 'ui/note_navigation_helpers.dart';
export 'ui/prompt_dialogs.dart';
export 'ui/shared_components.dart';
export 'ui/todo_display.dart';
export 'services/note_file_service.dart';
export 'features/settings/settings_page.dart';
export 'features/calendar/calendar_page.dart';
export 'features/finance/finance_page.dart';
export 'features/home/home_page.dart';
export 'features/notes/notes_page.dart';

part 'note_editor.dart';

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

  final notesPageKey = GlobalKey<NotesPageState>();
  final calendarPageKey = GlobalKey<CalendarPageState>();
  final homePageKey = GlobalKey<HomePageState>();
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
      NotesPage(
        key: notesPageKey,
        actions: NotesFeatureActions(editNote: showNoteEditor),
      ),
      CalendarPage(key: calendarPageKey, onEditSchedule: showScheduleEditor),
      HomePage(
        key: homePageKey,
        onNavigate: selectPage,
        actions: HomeFeatureActions(
          editNote: showNoteEditor,
          editTodo: openTodoEditorPage,
          showTodoActions: showTodoActionSheet,
          editFinance: showFinanceEditor,
          editSubscription: showSubscriptionEditor,
          editSchedule: showScheduleEditor,
        ),
      ),
      FinancePage(
        actions: FinanceFeatureActions(
          editEntry: showFinanceEditor,
          manageSubscriptions: showSubscriptionManager,
          editSubscription: showSubscriptionEditor,
          editSavingsAccount: showSavingsAccountEditor,
          showSavingsAccountActions: showSavingsAccountActions,
          editBudget: showBudgetEditor,
        ),
      ),
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
