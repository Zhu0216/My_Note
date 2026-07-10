import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart' as fbt;
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

const appLocale = Locale('zh', 'TW');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(MyNoteApp(store: store));
  unawaited(_initializeFirebaseIfConfigured());
}

Future<void> _initializeFirebaseIfConfigured() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class MyNoteApp extends StatelessWidget {
  const MyNoteApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppStoreScope(
      store: store,
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

enum CalendarViewMode { month, week, list }

enum SubscriptionCycle { monthly, yearly, custom }

enum EntryType { income, expense }

enum HomeSectionId { metrics, schedule, subscriptions, notes, todos }

enum HomeSectionStyle { list, grid }

enum NotesViewMode { grid, list, compact }

enum NotesSortField { createdAt, updatedAt, title, tag }

enum SortDirection { ascending, descending }

enum NotesDateFilter { all, oneDay, sevenDays, thirtyDays }

enum NoteTemplateType { general, plan, mindMap, lifeSheet }

enum NoteImageAlignment { free, left, center, right }

enum NoteBackgroundMode { fill, stretch, repeat }

enum AppNavBarStyle { template6 }

enum NoteEditorMenuAction { background, insertNote, export }

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.deletedAt,
    this.templateType = NoteTemplateType.general,
    Map<String, dynamic>? templateData,
    Map<String, dynamic>? style,
    List<Map<String, dynamic>>? images,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? background,
  }) : templateData = templateData ?? defaultNoteTemplateData(templateType),
       style = style ?? defaultNoteStyle(),
       images = images ?? <Map<String, dynamic>>[],
       attachments = attachments ?? <Map<String, dynamic>>[],
       background = background ?? defaultNoteBackground();

  final String id;
  String title;
  String body;
  String category;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  DateTime? deletedAt;
  NoteTemplateType templateType;
  Map<String, dynamic> templateData;
  Map<String, dynamic> style;
  List<Map<String, dynamic>> images;
  List<Map<String, dynamic>> attachments;
  Map<String, dynamic> background;
}

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.notes,
    required this.remindBeforeMinutes,
  });

  final String id;
  String title;
  DateTime start;
  DateTime end;
  String location;
  String notes;
  int remindBeforeMinutes;
}

class SubscriptionItem {
  SubscriptionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.nextPaymentDate,
    required this.paymentMethod,
    required this.category,
    required this.reminderDays,
    this.isActive = true,
  });

  final String id;
  String name;
  double amount;
  SubscriptionCycle cycle;
  DateTime nextPaymentDate;
  String paymentMethod;
  String category;
  int reminderDays;
  bool isActive;
}

class FinanceEntry {
  FinanceEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.account,
    required this.date,
    required this.note,
  });

  final String id;
  EntryType type;
  String title;
  double amount;
  String category;
  String account;
  DateTime date;
  String note;
}

class SavingsAccount {
  SavingsAccount({required this.id, required this.name, required this.amount});

  final String id;
  String name;
  double amount;
}

class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.done = false,
    this.dueDate,
    this.reminderEnabled = false,
    this.reminderTime,
    this.completedAt,
    this.sortOrder = 0,
  });

  final String id;
  String title;
  bool done;
  DateTime? dueDate;
  bool reminderEnabled;
  TimeOfDay? reminderTime;
  DateTime? completedAt;
  int sortOrder;
}

class AppStore extends ChangeNotifier {
  AppStore._({
    required this.notes,
    required this.schedules,
    required this.subscriptions,
    required this.financeEntries,
    required this.savingsAccounts,
    required this.todos,
    required this.noteFolders,
    required this.monthlyBudget,
    required this.homeSectionOrder,
    required this.collapsedHomeSections,
    required this.hiddenHomeSections,
    required this.hiddenUpcomingItems,
    required this.homeSectionStyles,
  }) {
    _syncNoteFolders();
    _removeLegacySeedTodos();
    _cleanupCompletedTodos();
    _normalizeTodoOrder();
    _nextId = _calculateNextId();
    _scheduleCompletedTodoCleanup();
  }

  factory AppStore.seeded() {
    return AppStore._(
      monthlyBudget: 18000,
      homeSectionOrder: defaultHomeSectionOrder(),
      collapsedHomeSections: <HomeSectionId>{},
      hiddenHomeSections: <HomeSectionId>{},
      hiddenUpcomingItems: <String>{},
      homeSectionStyles: defaultHomeSectionStyles(),
      notes: [],
      schedules: [],
      subscriptions: [],
      financeEntries: [],
      savingsAccounts: [],
      todos: [],
      noteFolders: [],
    );
  }

  static DateTime completedCleanupCutoff(DateTime now) {
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(hours: 1));
  }

  static const String _storageKey = 'my_note_local_v1';

  void _removeLegacySeedTodos() {
    const legacySeedTodoTitles = {'讀書計畫', '完成筆記模板整理', '設定 Firebase 專案'};
    todos.removeWhere(
      (todo) =>
          (todo.id == 't1' || todo.id == 't2') &&
          legacySeedTodoTitles.contains(todo.title),
    );
  }

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return AppStore.seeded();
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return AppStore._(
        notes: listOf(data['notes'], noteFromJson),
        schedules: listOf(data['schedules'], scheduleFromJson),
        subscriptions: listOf(data['subscriptions'], subscriptionFromJson),
        financeEntries: listOf(data['financeEntries'], financeEntryFromJson),
        savingsAccounts: listOf(
          data['savingsAccounts'],
          savingsAccountFromJson,
        ),
        todos: listOf(data['todos'], todoFromJson),
        noteFolders: readStringList(data['noteFolders']),
        monthlyBudget: readDouble(data['monthlyBudget'], fallback: 18000),
        homeSectionOrder: readHomeSectionOrder(data['homeSectionOrder']),
        collapsedHomeSections: readHomeSectionSet(
          data['collapsedHomeSections'],
        ),
        hiddenHomeSections: readHomeSectionSet(data['hiddenHomeSections']),
        hiddenUpcomingItems: readStringList(
          data['hiddenUpcomingItems'],
        ).toSet(),
        homeSectionStyles: readHomeSectionStyles(data['homeSectionStyles']),
      );
    } catch (_) {
      return AppStore.seeded();
    }
  }

  final List<NoteItem> notes;
  final List<ScheduleItem> schedules;
  final List<SubscriptionItem> subscriptions;
  final List<FinanceEntry> financeEntries;
  final List<SavingsAccount> savingsAccounts;
  final List<TodoItem> todos;
  final List<String> noteFolders;
  final List<HomeSectionId> homeSectionOrder;
  final Set<HomeSectionId> collapsedHomeSections;
  final Set<HomeSectionId> hiddenHomeSections;
  final Set<String> hiddenUpcomingItems;
  final Map<HomeSectionId, HomeSectionStyle> homeSectionStyles;
  double monthlyBudget;
  int _nextId = 100;
  Timer? _saveDebounce;
  Timer? _todoCleanupTimer;

  String newId(String prefix) => '$prefix${_nextId++}';

  int _calculateNextId() {
    final ids = [
      ...notes.map((item) => item.id),
      ...schedules.map((item) => item.id),
      ...subscriptions.map((item) => item.id),
      ...financeEntries.map((item) => item.id),
      ...savingsAccounts.map((item) => item.id),
      ...todos.map((item) => item.id),
    ];
    var maxId = 99;
    for (final id in ids) {
      final digits = RegExp(r'\d+$').firstMatch(id)?.group(0);
      final value = int.tryParse(digits ?? '');
      if (value != null && value > maxId) {
        maxId = value;
      }
    }
    return maxId + 1;
  }

  Map<String, dynamic> toJson() {
    return {
      'notes': notes.map(noteToJson).toList(),
      'schedules': schedules.map(scheduleToJson).toList(),
      'subscriptions': subscriptions.map(subscriptionToJson).toList(),
      'financeEntries': financeEntries.map(financeEntryToJson).toList(),
      'savingsAccounts': savingsAccounts.map(savingsAccountToJson).toList(),
      'todos': todos.map(todoToJson).toList(),
      'noteFolders': noteFolders,
      'monthlyBudget': monthlyBudget,
      'homeSectionOrder': homeSectionOrder.map((item) => item.name).toList(),
      'collapsedHomeSections': collapsedHomeSections
          .map((item) => item.name)
          .toList(),
      'hiddenHomeSections': hiddenHomeSections
          .map((item) => item.name)
          .toList(),
      'hiddenUpcomingItems': hiddenUpcomingItems.toList(),
      'homeSectionStyles': {
        for (final entry in homeSectionStyles.entries)
          entry.key.name: entry.value.name,
      },
    };
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(toJson()));
  }

  void _commit() {
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), _save);
  }

  void _scheduleCompletedTodoCleanup() {
    _todoCleanupTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _todoCleanupTimer = Timer(tomorrow.difference(now), () {
      _cleanupCompletedTodos(notify: true);
      _scheduleCompletedTodoCleanup();
    });
  }

  void _cleanupCompletedTodos({bool notify = false}) {
    final cutoff = completedCleanupCutoff(DateTime.now());
    final before = todos.length;
    todos.removeWhere((todo) {
      if (!todo.done) {
        return false;
      }
      final completedAt = todo.completedAt;
      return completedAt == null || completedAt.isBefore(cutoff);
    });
    if (before != todos.length) {
      _normalizeTodoOrder();
      if (notify) {
        _commit();
      }
    }
  }

  void _normalizeTodoOrder() {
    for (var index = 0; index < todos.length; index++) {
      if (todos[index].sortOrder <= 0) {
        todos[index].sortOrder = (index + 1) * 1000;
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _todoCleanupTimer?.cancel();
    _save();
    super.dispose();
  }

  List<NoteItem> get visibleNotes {
    final sorted = notes.where((item) => item.deletedAt == null).toList();
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  List<NoteItem> get trashNotes {
    final sorted = notes.where((item) => item.deletedAt != null).toList();
    sorted.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return sorted;
  }

  List<String> get folders {
    final folders = noteFolders.toList();
    folders.sort();
    return folders;
  }

  List<String> get folderPaths {
    final paths = <String>{};
    for (final folder in noteFolders) {
      final parts = folder
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      for (var index = 0; index < parts.length; index++) {
        paths.add(parts.take(index + 1).join('/'));
      }
    }
    final result = paths.toList();
    result.sort();
    return result;
  }

  List<ScheduleItem> get upcomingSchedules {
    final upcoming = schedules
        .where((item) => !item.end.isBefore(DateTime.now()))
        .toList();
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    return upcoming;
  }

  List<TodoItem> get activeTodos {
    final active = todos.where((item) => !item.done).toList();
    active.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) {
        return order;
      }
      return a.id.compareTo(b.id);
    });
    return active;
  }

  List<TodoItem> get completedTodayTodos {
    final now = DateTime.now();
    final completed = todos
        .where(
          (item) =>
              item.done &&
              item.completedAt != null &&
              isSameDate(item.completedAt!, now),
        )
        .toList();
    completed.sort(
      (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
        a.completedAt ?? DateTime(0),
      ),
    );
    return completed;
  }

  List<SubscriptionItem> get upcomingSubscriptions {
    final active = subscriptions.where((item) => item.isActive).toList();
    active.sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));
    return active;
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return financeEntries
        .where(
          (entry) =>
              entry.type == EntryType.expense &&
              entry.date.year == now.year &&
              entry.date.month == now.month,
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  double get monthlyIncome {
    final now = DateTime.now();
    return financeEntries
        .where(
          (entry) =>
              entry.type == EntryType.income &&
              entry.date.year == now.year &&
              entry.date.month == now.month,
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  double get savingsTotal =>
      savingsAccounts.fold(0, (sum, account) => sum + account.amount);

  double get monthlySubscriptionTotal => subscriptions
      .where((item) => item.isActive)
      .fold(0, (sum, item) => sum + item.monthlyAmount);

  void upsertNote(NoteItem note) {
    if (note.category.trim().isNotEmpty) {
      createNoteFolder(note.category, notify: false);
    }
    final index = notes.indexWhere((item) => item.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
    _commit();
  }

  void createNoteFolder(String name, {bool notify = true}) {
    final folder = normalizeFolderPath(name);
    if (folder.isEmpty) {
      return;
    }
    if (!noteFolders.contains(folder)) {
      noteFolders.add(folder);
      if (notify) {
        _commit();
      }
    }
  }

  void deleteNotesById(Set<String> ids) {
    final now = DateTime.now();
    for (final note in notes.where((item) => ids.contains(item.id))) {
      note.deletedAt = now;
      note.updatedAt = now;
    }
    _commit();
  }

  void restoreNotesById(Set<String> ids) {
    final now = DateTime.now();
    for (final note in notes.where((item) => ids.contains(item.id))) {
      note.deletedAt = null;
      note.updatedAt = now;
      if (note.category.trim().isNotEmpty) {
        createNoteFolder(note.category, notify: false);
      }
    }
    _commit();
  }

  void permanentlyDeleteNotesById(Set<String> ids) {
    notes.removeWhere(
      (item) => ids.contains(item.id) && item.deletedAt != null,
    );
    _commit();
  }

  void moveNotesToFolder(Set<String> ids, String folder) {
    final target = normalizeFolderPath(folder);
    if (target.isNotEmpty) {
      createNoteFolder(target, notify: false);
    }
    for (final note in notes.where((item) => ids.contains(item.id))) {
      note.category = target;
      note.updatedAt = DateTime.now();
    }
    _commit();
  }

  void moveNoteToFolder(NoteItem note, String folder) {
    moveNotesToFolder({note.id}, folder);
  }

  void renameNote(NoteItem note, String title) {
    final value = title.trim();
    if (value.isEmpty) {
      return;
    }
    note.title = value;
    note.updatedAt = DateTime.now();
    _commit();
  }

  void renameNoteFolder(String oldName, String newName) {
    final oldPath = normalizeFolderPath(oldName);
    final folderName = folderBaseName(newName);
    if (oldPath.isEmpty || folderName.isEmpty) {
      return;
    }
    final newPath = joinFolderPath(folderParentPath(oldPath), folderName);
    if (oldPath == newPath) {
      return;
    }
    createNoteFolder(newPath, notify: false);
    for (final note in notes.where(
      (item) => folderContains(oldPath, item.category),
    )) {
      note.category = replaceFolderPrefix(note.category, oldPath, newPath);
      note.updatedAt = DateTime.now();
    }
    for (var index = 0; index < noteFolders.length; index++) {
      if (folderContains(oldPath, noteFolders[index])) {
        noteFolders[index] = replaceFolderPrefix(
          noteFolders[index],
          oldPath,
          newPath,
        );
      }
    }
    noteFolders.remove(oldPath);
    final unique = noteFolders.toSet().toList();
    noteFolders
      ..clear()
      ..addAll(unique);
    _commit();
  }

  void moveNoteFolder(String oldName, String targetParent) {
    final oldPath = normalizeFolderPath(oldName);
    final parent = normalizeFolderPath(targetParent);
    if (oldPath.isEmpty ||
        parent == oldPath ||
        folderContains(oldPath, parent)) {
      return;
    }
    final newPath = joinFolderPath(parent, folderBaseName(oldPath));
    if (oldPath == newPath) {
      return;
    }
    createNoteFolder(newPath, notify: false);
    for (final note in notes.where(
      (item) => folderContains(oldPath, item.category),
    )) {
      note.category = replaceFolderPrefix(note.category, oldPath, newPath);
      note.updatedAt = DateTime.now();
    }
    for (var index = 0; index < noteFolders.length; index++) {
      if (folderContains(oldPath, noteFolders[index])) {
        noteFolders[index] = replaceFolderPrefix(
          noteFolders[index],
          oldPath,
          newPath,
        );
      }
    }
    final unique = noteFolders.toSet().toList();
    noteFolders
      ..clear()
      ..addAll(unique);
    _commit();
  }

  void deleteNoteFolder(String folder) {
    final path = normalizeFolderPath(folder);
    if (path.isEmpty) {
      return;
    }
    final now = DateTime.now();
    for (final note in notes.where(
      (item) => folderContains(path, item.category),
    )) {
      note.deletedAt = now;
      note.updatedAt = now;
    }
    noteFolders.removeWhere((folder) => folderContains(path, folder));
    _commit();
  }

  void _syncNoteFolders() {
    final expired = DateTime.now().subtract(const Duration(days: 30));
    notes.removeWhere(
      (note) => note.deletedAt != null && note.deletedAt!.isBefore(expired),
    );
    for (final note in notes) {
      final folder = note.category.trim();
      note.category = folder;
      if (folder.isNotEmpty && !noteFolders.contains(folder)) {
        noteFolders.add(folder);
      }
    }
    noteFolders.removeWhere((folder) => folder.trim().isEmpty);
    final unique = noteFolders.map(normalizeFolderPath).toSet().toList();
    noteFolders
      ..clear()
      ..addAll(unique);
  }

  void toggleNotePinned(NoteItem note) {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    _commit();
  }

  void deleteNote(NoteItem note) {
    note.deletedAt = DateTime.now();
    note.updatedAt = DateTime.now();
    _commit();
  }

  void clearTrashNotes() {
    notes.removeWhere((item) => item.deletedAt != null);
    _commit();
  }

  void upsertSchedule(ScheduleItem item) {
    final index = schedules.indexWhere((schedule) => schedule.id == item.id);
    if (index >= 0) {
      schedules[index] = item;
    } else {
      schedules.add(item);
    }
    _commit();
  }

  void deleteSchedule(ScheduleItem item) {
    schedules.removeWhere((schedule) => schedule.id == item.id);
    _commit();
  }

  void upsertSubscription(SubscriptionItem item) {
    final index = subscriptions.indexWhere((sub) => sub.id == item.id);
    if (index >= 0) {
      subscriptions[index] = item;
    } else {
      subscriptions.add(item);
    }
    _commit();
  }

  void deleteSubscription(SubscriptionItem item) {
    subscriptions.removeWhere((sub) => sub.id == item.id);
    _commit();
  }

  void upsertFinanceEntry(FinanceEntry item) {
    final index = financeEntries.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      financeEntries[index] = item;
    } else {
      financeEntries.add(item);
    }
    _commit();
  }

  void deleteFinanceEntry(FinanceEntry item) {
    financeEntries.removeWhere((entry) => entry.id == item.id);
    _commit();
  }

  void upsertSavingsAccount(SavingsAccount account) {
    final index = savingsAccounts.indexWhere((item) => item.id == account.id);
    if (index >= 0) {
      savingsAccounts[index] = account;
    } else {
      savingsAccounts.add(account);
    }
    _commit();
  }

  void deleteSavingsAccount(SavingsAccount account) {
    savingsAccounts.removeWhere((item) => item.id == account.id);
    _commit();
  }

  void toggleTodo(TodoItem todo) {
    todo.done = !todo.done;
    todo.completedAt = todo.done ? DateTime.now() : null;
    if (!todo.done) {
      todo.sortOrder = _nextActiveTodoSortOrder();
    }
    _commit();
  }

  void upsertTodo(TodoItem todo) {
    if (!todo.done && todo.sortOrder <= 0) {
      todo.sortOrder = _nextActiveTodoSortOrder();
    }
    final index = todos.indexWhere((item) => item.id == todo.id);
    if (index >= 0) {
      todos[index] = todo;
    } else {
      todos.add(todo);
    }
    _commit();
  }

  int _nextActiveTodoSortOrder() {
    final active = todos.where((item) => !item.done);
    if (active.isEmpty) {
      return 1000;
    }
    return active.map((item) => item.sortOrder).reduce(math.max) + 1000;
  }

  void reorderActiveTodo(int oldIndex, int newIndex) {
    final active = activeTodos;
    if (oldIndex < 0 || oldIndex >= active.length) {
      return;
    }
    newIndex = math.min(math.max(newIndex, 0), active.length - 1);
    final item = active.removeAt(oldIndex);
    active.insert(newIndex, item);
    for (var index = 0; index < active.length; index++) {
      active[index].sortOrder = (index + 1) * 1000;
    }
    _commit();
  }

  void addTodo(
    String title, {
    DateTime? dueDate,
    bool reminderEnabled = false,
    TimeOfDay? reminderTime,
  }) {
    if (title.trim().isEmpty) {
      return;
    }
    todos.add(
      TodoItem(
        id: newId('t'),
        title: title.trim(),
        dueDate: dueDate,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderTime,
        sortOrder: _nextActiveTodoSortOrder(),
      ),
    );
    _commit();
  }

  void deleteTodo(TodoItem todo) {
    todos.removeWhere((item) => item.id == todo.id);
    _commit();
  }

  void updateBudget(double value) {
    monthlyBudget = value;
    _commit();
  }

  void toggleHomeSection(HomeSectionId section) {
    if (collapsedHomeSections.contains(section)) {
      collapsedHomeSections.remove(section);
    } else {
      collapsedHomeSections.add(section);
    }
    _commit();
  }

  void moveHomeSection(HomeSectionId section, int delta) {
    final index = homeSectionOrder.indexOf(section);
    final target = (index + delta).clamp(0, homeSectionOrder.length - 1);
    if (index == -1 || index == target) {
      return;
    }
    homeSectionOrder
      ..removeAt(index)
      ..insert(target, section);
    _commit();
  }

  void reorderHomeSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    reorderHomeSectionsToIndex(oldIndex, newIndex);
  }

  void reorderHomeSectionsToIndex(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    final section = homeSectionOrder.removeAt(oldIndex);
    homeSectionOrder.insert(newIndex, section);
    _commit();
  }

  void toggleHomeSectionVisible(HomeSectionId section) {
    if (hiddenHomeSections.contains(section)) {
      hiddenHomeSections.remove(section);
    } else {
      hiddenHomeSections.add(section);
    }
    _commit();
  }

  void setUpcomingItemHidden(String key, bool hidden) {
    if (hidden) {
      hiddenUpcomingItems.add(key);
    } else {
      hiddenUpcomingItems.remove(key);
    }
    _commit();
  }

  void setHomeSectionStyle(HomeSectionId section, HomeSectionStyle style) {
    homeSectionStyles[section] = style;
    _commit();
  }
}

extension on SubscriptionItem {
  double get monthlyAmount {
    switch (cycle) {
      case SubscriptionCycle.monthly:
        return amount;
      case SubscriptionCycle.yearly:
        return amount / 12;
      case SubscriptionCycle.custom:
        return amount;
    }
  }
}

List<T> listOf<T>(Object? raw, T Function(Map<String, dynamic>) read) {
  if (raw is! List) {
    return [];
  }
  return raw
      .whereType<Map>()
      .map((item) => read(Map<String, dynamic>.from(item)))
      .toList();
}

Map<String, dynamic> noteToJson(NoteItem note) {
  return {
    'id': note.id,
    'title': note.title,
    'body': note.body,
    'category': note.category,
    'tags': note.tags,
    'createdAt': note.createdAt.toIso8601String(),
    'updatedAt': note.updatedAt.toIso8601String(),
    'isPinned': note.isPinned,
    'deletedAt': note.deletedAt?.toIso8601String(),
    'templateType': note.templateType.name,
    'templateData': note.templateData,
    'style': note.style,
    'images': note.images,
    'attachments': note.attachments,
    'background': note.background,
  };
}

NoteItem noteFromJson(Map<String, dynamic> data) {
  final templateType = readEnum(
    NoteTemplateType.values,
    data['templateType'],
    NoteTemplateType.general,
  );
  return NoteItem(
    id: readString(data['id'], fallback: 'n-local'),
    title: readString(data['title'], fallback: '未命名筆記'),
    body: readString(data['body']),
    category: readString(data['category']),
    tags: readStringList(data['tags']),
    createdAt: readDate(data['createdAt']),
    updatedAt: readDate(data['updatedAt']),
    isPinned: data['isPinned'] == true,
    deletedAt: readOptionalDate(data['deletedAt']),
    templateType: templateType,
    templateData: readStringMap(
      data['templateData'],
      fallback: defaultNoteTemplateData(templateType),
    ),
    style: readStringMap(data['style'], fallback: defaultNoteStyle()),
    images: readMapList(data['images']),
    attachments: readMapList(data['attachments']),
    background: readStringMap(
      data['background'],
      fallback: defaultNoteBackground(),
    ),
  );
}

Map<String, dynamic> scheduleToJson(ScheduleItem item) {
  return {
    'id': item.id,
    'title': item.title,
    'start': item.start.toIso8601String(),
    'end': item.end.toIso8601String(),
    'location': item.location,
    'notes': item.notes,
    'remindBeforeMinutes': item.remindBeforeMinutes,
  };
}

ScheduleItem scheduleFromJson(Map<String, dynamic> data) {
  final start = readDate(data['start']);
  return ScheduleItem(
    id: readString(data['id'], fallback: 's-local'),
    title: readString(data['title'], fallback: '未命名行程'),
    start: start,
    end: readDate(data['end'], fallback: start.add(const Duration(hours: 1))),
    location: readString(data['location']),
    notes: readString(data['notes']),
    remindBeforeMinutes: readInt(data['remindBeforeMinutes'], fallback: 30),
  );
}

Map<String, dynamic> subscriptionToJson(SubscriptionItem item) {
  return {
    'id': item.id,
    'name': item.name,
    'amount': item.amount,
    'cycle': item.cycle.name,
    'nextPaymentDate': item.nextPaymentDate.toIso8601String(),
    'paymentMethod': item.paymentMethod,
    'category': item.category,
    'reminderDays': item.reminderDays,
    'isActive': item.isActive,
  };
}

SubscriptionItem subscriptionFromJson(Map<String, dynamic> data) {
  return SubscriptionItem(
    id: readString(data['id'], fallback: 'sub-local'),
    name: readString(data['name'], fallback: '未命名訂閱'),
    amount: readDouble(data['amount']),
    cycle: readEnum(
      SubscriptionCycle.values,
      data['cycle'],
      SubscriptionCycle.monthly,
    ),
    nextPaymentDate: readDate(data['nextPaymentDate']),
    paymentMethod: readString(data['paymentMethod'], fallback: '信用卡'),
    category: readString(data['category'], fallback: '其他'),
    reminderDays: readInt(data['reminderDays'], fallback: 3),
    isActive: data['isActive'] != false,
  );
}

Map<String, dynamic> financeEntryToJson(FinanceEntry item) {
  return {
    'id': item.id,
    'type': item.type.name,
    'title': item.title,
    'amount': item.amount,
    'category': item.category,
    'account': item.account,
    'date': item.date.toIso8601String(),
    'note': item.note,
  };
}

FinanceEntry financeEntryFromJson(Map<String, dynamic> data) {
  return FinanceEntry(
    id: readString(data['id'], fallback: 'f-local'),
    type: readEnum(EntryType.values, data['type'], EntryType.expense),
    title: readString(data['title'], fallback: '未命名記帳'),
    amount: readDouble(data['amount']),
    category: readString(data['category'], fallback: '其他'),
    account: readString(data['account'], fallback: '其他'),
    date: readDate(data['date']),
    note: readString(data['note']),
  );
}

Map<String, dynamic> savingsAccountToJson(SavingsAccount item) {
  return {'id': item.id, 'name': item.name, 'amount': item.amount};
}

SavingsAccount savingsAccountFromJson(Map<String, dynamic> data) {
  return SavingsAccount(
    id: readString(data['id'], fallback: 'sa-local'),
    name: readString(data['name'], fallback: '未命名帳戶'),
    amount: readDouble(data['amount']),
  );
}

Map<String, dynamic> todoToJson(TodoItem item) {
  return {
    'id': item.id,
    'title': item.title,
    'done': item.done,
    'dueDate': item.dueDate?.toIso8601String(),
    'reminderEnabled': item.reminderEnabled,
    'reminderTime': item.reminderTime == null
        ? null
        : '${item.reminderTime!.hour}:${item.reminderTime!.minute}',
    'completedAt': item.completedAt?.toIso8601String(),
    'sortOrder': item.sortOrder,
  };
}

TodoItem todoFromJson(Map<String, dynamic> data) {
  return TodoItem(
    id: readString(data['id'], fallback: 't-local'),
    title: readString(data['title'], fallback: '未命名待辦'),
    done: data['done'] == true,
    dueDate: readOptionalDate(data['dueDate']),
    reminderEnabled: data['reminderEnabled'] == true,
    reminderTime: readTimeOfDay(data['reminderTime']),
    completedAt: readOptionalDate(data['completedAt']),
    sortOrder: readInt(data['sortOrder']),
  );
}

String readString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

List<String> readStringList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value.whereType<String>().toList();
}

Map<String, dynamic> readStringMap(
  Object? value, {
  Map<String, dynamic> fallback = const {},
}) {
  if (value is! Map) {
    return Map<String, dynamic>.from(fallback);
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> cloneJsonMap(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

List<Map<String, dynamic>> readMapList(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return fallback;
}

double readDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

DateTime readDate(Object? value, {DateTime? fallback}) {
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

DateTime? readOptionalDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

TimeOfDay? readTimeOfDay(Object? value) {
  if (value is! String) {
    return null;
  }
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
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

T readEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) {
        return item;
      }
    }
  }
  return fallback;
}

Map<String, dynamic> defaultNoteStyle() {
  return {
    'fontFamily': 'System',
    'fontSize': 16.0,
    'color': '#202522',
    'lineHeight': 1.45,
  };
}

Map<String, dynamic> defaultNoteBackground() {
  return {
    'color': '#FFFFFF',
    'image': '',
    'mode': NoteBackgroundMode.fill.name,
  };
}

Map<String, dynamic> defaultNoteTemplateData(NoteTemplateType type) {
  switch (type) {
    case NoteTemplateType.general:
      return <String, dynamic>{
        'schema': 'general.v2',
        'richText': {
          'format': richTextFormatVersion,
          'plainText': '',
          'spans': <Map<String, dynamic>>[],
        },
        'appflowy': blankAppFlowyMirrorJson(),
      };
    case NoteTemplateType.plan:
      return {
        'schema': 'plan.v1',
        'goal': '',
        'phase': '',
        'tasks': <Map<String, dynamic>>[
          {'title': '', 'done': false},
        ],
        'startDate': null,
        'dueDate': null,
        'spentHours': 0.0,
        'notes': '',
      };
    case NoteTemplateType.mindMap:
      return {
        'schema': 'mind_map.v1',
        'topic': '',
        'nodes': <Map<String, dynamic>>[
          {
            'title': '',
            'subtitle': '',
            'description': '',
            'x': 0.0,
            'y': 0.0,
            'color': '#7C8B5F',
            'expanded': true,
          },
        ],
      };
    case NoteTemplateType.lifeSheet:
      return {
        'schema': 'life_sheet.v1',
        'linkedPlanIds': <String>[],
        'items': <Map<String, dynamic>>[
          {
            'name': '',
            'targetAmount': 0.0,
            'currentAmount': 0.0,
            'actualCost': 0.0,
          },
        ],
        'startDate': null,
        'spentHours': 0.0,
        'notes': '',
      };
  }
}

List<HomeSectionId> defaultHomeSectionOrder() {
  return [
    HomeSectionId.metrics,
    HomeSectionId.schedule,
    HomeSectionId.subscriptions,
    HomeSectionId.notes,
    HomeSectionId.todos,
  ];
}

Map<HomeSectionId, HomeSectionStyle> defaultHomeSectionStyles() {
  return {
    for (final section in HomeSectionId.values) section: HomeSectionStyle.list,
    HomeSectionId.metrics: HomeSectionStyle.grid,
  };
}

List<HomeSectionId> readHomeSectionOrder(Object? value) {
  final defaults = defaultHomeSectionOrder();
  if (value is! List) {
    return defaults;
  }
  final parsed = value
      .whereType<String>()
      .map(
        (name) => readEnum(HomeSectionId.values, name, HomeSectionId.metrics),
      )
      .where((section) => defaults.contains(section))
      .toList();
  return [
    ...{...parsed},
    for (final section in defaults)
      if (!parsed.contains(section)) section,
  ];
}

Set<HomeSectionId> readHomeSectionSet(Object? value) {
  if (value is! List) {
    return {};
  }
  return value
      .whereType<String>()
      .map(
        (name) => readEnum(HomeSectionId.values, name, HomeSectionId.metrics),
      )
      .where((section) => HomeSectionId.values.contains(section))
      .toSet();
}

Map<HomeSectionId, HomeSectionStyle> readHomeSectionStyles(Object? value) {
  final styles = defaultHomeSectionStyles();
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! String) {
        continue;
      }
      final section = readEnum(
        HomeSectionId.values,
        entry.key,
        HomeSectionId.metrics,
      );
      styles[section] = readEnum(
        HomeSectionStyle.values,
        entry.value,
        styles[section] ?? HomeSectionStyle.list,
      );
    }
  }
  return styles;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int homeIndex = 2;

  int selectedIndex = homeIndex;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const NotesPage(),
      const CalendarPage(),
      HomePage(onNavigate: (index) => setState(() => selectedIndex = index)),
      const FinancePage(),
      const SettingsPage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (selectedIndex != homeIndex) {
          setState(() => selectedIndex = homeIndex);
          return;
        }
        final shouldExit = await showExitConfirmDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(child: pages[selectedIndex]),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: selectedIndex,
          onSelected: (index) => setState(() => selectedIndex = index),
        ),
      ),
    );
  }
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

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController quickAddFabController;
  bool quickAddOpen = false;

  @override
  void initState() {
    super.initState();
    quickAddFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    quickAddFabController.dispose();
    super.dispose();
  }

  void toggleQuickAdd() {
    if (quickAddOpen) {
      closeQuickAdd();
    } else {
      setState(() => quickAddOpen = true);
      quickAddFabController.forward();
    }
  }

  void closeQuickAdd() {
    setState(() => quickAddOpen = false);
    quickAddFabController.reverse();
  }

  Future<void> handleQuickAdd(String value) async {
    closeQuickAdd();
    switch (value) {
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

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionMenu(
        isOpen: quickAddOpen,
        controller: quickAddFabController,
        tooltip: '快速新增',
        onToggle: toggleQuickAdd,
        items: [
          FloatingActionMenuItem(
            icon: Icons.notes,
            label: '新增筆記',
            value: 'note',
            onSelected: handleQuickAdd,
          ),
          FloatingActionMenuItem(
            icon: Icons.add_task,
            label: '新增待辦事項',
            value: 'todo',
            onSelected: handleQuickAdd,
          ),
          FloatingActionMenuItem(
            icon: Icons.payments_outlined,
            label: '新增記帳',
            value: 'finance',
            onSelected: handleQuickAdd,
          ),
          FloatingActionMenuItem(
            icon: Icons.subscriptions_outlined,
            label: '新增訂閱費用',
            value: 'subscription',
            onSelected: handleQuickAdd,
          ),
          FloatingActionMenuItem(
            icon: Icons.event_note,
            label: '新增行程',
            value: 'schedule',
            onSelected: handleQuickAdd,
          ),
        ],
      ),
      body: AppPage(
        title: 'My Note',
        subtitle: 'All-in-one 個人管理筆記本',
        actions: [
          IconButton(
            tooltip: '調整首頁',
            onPressed: () => showHomeLayoutSettings(context),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            for (final section in store.homeSectionOrder)
              if (!store.hiddenHomeSections.contains(section))
                HomeSection(section: section, onNavigate: widget.onNavigate),
          ],
        ),
      ),
    );
  }
}

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.section,
    required this.onNavigate,
  });

  final HomeSectionId section;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final collapsed = store.collapsedHomeSections.contains(section);
    final style = store.homeSectionStyles[section] ?? HomeSectionStyle.list;

    if (section == HomeSectionId.todos) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TodoHomeSection(
          style: style,
          collapsed: collapsed,
          onToggleCollapsed: () => store.toggleHomeSection(section),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          SectionHeader(
            title: homeSectionTitle(section),
            onTap: () => store.toggleHomeSection(section),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                homeSectionAction(context, section, onNavigate),
                Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: collapsed
                ? const SizedBox.shrink(key: ValueKey('collapsed'))
                : KeyedSubtree(
                    key: ValueKey('${section.name}-${style.name}'),
                    child: buildHomeSectionContent(context, section, style),
                  ),
          ),
        ],
      ),
    );
  }
}

String homeSectionTitle(HomeSectionId section) {
  return switch (section) {
    HomeSectionId.metrics => '月結算',
    HomeSectionId.schedule => '今日行程',
    HomeSectionId.subscriptions => '即將到來',
    HomeSectionId.notes => '最近筆記',
    HomeSectionId.todos => '待辦事項',
  };
}

Widget homeSectionAction(
  BuildContext context,
  HomeSectionId section,
  ValueChanged<int> onNavigate,
) {
  return switch (section) {
    HomeSectionId.metrics => const SizedBox.shrink(),
    HomeSectionId.schedule => TextButton.icon(
      onPressed: () => onNavigate(1),
      icon: const Icon(Icons.chevron_right),
      label: const Text('查看'),
    ),
    HomeSectionId.subscriptions => TextButton.icon(
      onPressed: () => showUpcomingManager(context),
      icon: const Icon(Icons.open_in_new),
      label: const Text('管理'),
    ),
    HomeSectionId.notes => TextButton.icon(
      onPressed: () => onNavigate(0),
      icon: const Icon(Icons.chevron_right),
      label: const Text('查看'),
    ),
    HomeSectionId.todos => IconButton(
      tooltip: '新增待辦事項',
      onPressed: () => openTodoEditorPage(context),
      icon: const Icon(Icons.add_task),
    ),
  };
}

Widget buildHomeSectionContent(
  BuildContext context,
  HomeSectionId section,
  HomeSectionStyle style,
) {
  return switch (section) {
    HomeSectionId.metrics => MetricsHomeSection(style: style),
    HomeSectionId.schedule => ScheduleHomeSection(style: style),
    HomeSectionId.subscriptions => UpcomingHomeSection(style: style),
    HomeSectionId.notes => NotesHomeSection(style: style),
    HomeSectionId.todos => TodoHomeSection(style: style),
  };
}

class MetricsHomeSection extends StatelessWidget {
  const MetricsHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = [
      MetricInfo(
        title: '本月收入',
        value: currency(store.monthlyIncome),
        icon: Icons.payments_outlined,
        color: const Color(0xffb5533d),
      ),
      MetricInfo(
        title: '本月支出',
        value: currency(store.monthlyExpense),
        icon: Icons.subscriptions_outlined,
        color: const Color(0xff3f5f99),
      ),
    ];

    return MetricSummaryRow(items: items, style: style);
  }
}

class MetricInfo {
  const MetricInfo({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class ScheduleHomeSection extends StatelessWidget {
  const ScheduleHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final todayEvents =
        store.schedules
            .where((event) => isSameDate(event.start, DateTime.now()))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final shownEvents = todayEvents.isNotEmpty
        ? todayEvents
        : store.upcomingSchedules.take(2).toList();
    final eventLabel = todayEvents.isNotEmpty
        ? '今日'
        : shownEvents.isEmpty
        ? '今日'
        : formatDate(shownEvents.first.start);

    if (shownEvents.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.event_available, text: '尚無行程'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final event in shownEvents)
            SizedBox(
              width: homeGridTileWidth(context),
              child: CompactInfoTile(
                icon: Icons.schedule,
                title: event.title,
                subtitle:
                    '$eventLabel\n${formatTime(event.start)} - ${formatTime(event.end)}',
              ),
            ),
        ],
      );
    }

    return InfoCard(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(eventLabel),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 4),
          for (final event in shownEvents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(event.title),
              subtitle: Text(
                '${formatTime(event.start)} - ${formatTime(event.end)}  ${event.location}',
              ),
            ),
        ],
      ),
    );
  }
}

class UpcomingHomeSection extends StatelessWidget {
  const UpcomingHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final items = upcomingHomeItems(store).take(6).toList();
    if (items.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.event_available, text: '7 日內沒有即將到來的項目'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final item in items)
            SizedBox(
              width: homeGridTileWidth(context),
              child: CompactInfoTile(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                onTap: () => showUpcomingDetails(context, item),
              ),
            ),
        ],
      );
    }

    return InfoCard(
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: item.trailing == null
                    ? null
                    : Text(
                        item.trailing!,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                onTap: () => showUpcomingDetails(context, item),
              ),
            ),
        ],
      ),
    );
  }
}

class UpcomingHomeItem {
  const UpcomingHomeItem({
    required this.key,
    required this.date,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.details,
    required this.hidden,
    this.trailing,
  });

  final String key;
  final DateTime date;
  final IconData icon;
  final String title;
  final String subtitle;
  final String typeLabel;
  final String details;
  final bool hidden;
  final String? trailing;
}

List<UpcomingHomeItem> upcomingHomeItems(
  AppStore store, {
  bool includeHidden = false,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final inSevenDays = today.add(const Duration(days: 8));
  final items = <UpcomingHomeItem>[
    for (final sub in store.upcomingSubscriptions.where(
      (sub) =>
          isInUpcomingWindow(sub.nextPaymentDate, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(
                upcomingSubscriptionKey(sub),
              )),
    ))
      UpcomingHomeItem(
        key: upcomingSubscriptionKey(sub),
        date: sub.nextPaymentDate,
        icon: Icons.autorenew,
        title: sub.name,
        subtitle:
            '${formatDate(sub.nextPaymentDate)}  ${cycleLabel(sub.cycle)}',
        typeLabel: '訂閱',
        details:
            '下次付款日: ${formatDate(sub.nextPaymentDate)}\n週期: ${cycleLabel(sub.cycle)}\n金額: ${currency(sub.amount)}\n付款方式: ${sub.paymentMethod}\n分類: ${sub.category}\n提醒: 前 ${sub.reminderDays} 天',
        hidden: store.hiddenUpcomingItems.contains(
          upcomingSubscriptionKey(sub),
        ),
        trailing: currency(sub.amount),
      ),
    for (final event in store.upcomingSchedules.where(
      (event) =>
          isInUpcomingWindow(event.start, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(upcomingScheduleKey(event))),
    ))
      UpcomingHomeItem(
        key: upcomingScheduleKey(event),
        date: event.start,
        icon: Icons.event_note,
        title: event.title,
        subtitle: '${formatDate(event.start)}  ${formatTime(event.start)}',
        typeLabel: '行程',
        details:
            '地點：${event.location.isEmpty ? '未設定' : event.location}\n提醒：提前 ${event.remindBeforeMinutes} 分鐘\n備註：${event.notes.isEmpty ? '無' : event.notes}',
        hidden: store.hiddenUpcomingItems.contains(upcomingScheduleKey(event)),
      ),
    for (final todo in store.todos.where(
      (todo) =>
          !todo.done &&
          todo.dueDate != null &&
          isInUpcomingWindow(todo.dueDate!, today, inSevenDays) &&
          (includeHidden ||
              !store.hiddenUpcomingItems.contains(upcomingTodoKey(todo))),
    ))
      UpcomingHomeItem(
        key: upcomingTodoKey(todo),
        date: todo.dueDate!,
        icon: todo.reminderEnabled
            ? Icons.notifications_active_outlined
            : Icons.task_alt,
        title: todo.title,
        subtitle: todoSubtitle(todo),
        typeLabel: '待辦',
        details:
            '期限：${formatDate(todo.dueDate!)}\n提醒：${todo.reminderEnabled ? (todo.reminderTime == null ? '已開啟' : '${todo.reminderTime!.hour.toString().padLeft(2, '0')}:${todo.reminderTime!.minute.toString().padLeft(2, '0')}') : '未開啟'}',
        hidden: store.hiddenUpcomingItems.contains(upcomingTodoKey(todo)),
      ),
  ];
  items.sort((a, b) => a.date.compareTo(b.date));
  return items;
}

bool isInUpcomingWindow(DateTime value, DateTime start, DateTime end) {
  return !value.isBefore(start) && value.isBefore(end);
}

String upcomingSubscriptionKey(SubscriptionItem item) => 'sub-${item.id}';

String upcomingScheduleKey(ScheduleItem item) => 'schedule-${item.id}';

String upcomingTodoKey(TodoItem item) => 'todo-${item.id}';

Future<void> showUpcomingDetails(
  BuildContext context,
  UpcomingHomeItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(item.icon),
          const SizedBox(width: 8),
          Expanded(child: Text(item.title)),
        ],
      ),
      content: Text('${item.typeLabel}\n${item.details}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('確認'),
        ),
      ],
    ),
  );
}

Future<void> showUpcomingManager(BuildContext context) async {
  final store = AppStoreScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = upcomingHomeItems(store, includeHidden: true);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '即將到來管理',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const EmptyState(icon: Icons.event_available, text: '尚無行程')
              else
                for (final item in items)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(item.icon),
                    value: !item.hidden,
                    title: Text(item.title),
                    subtitle: Text('${item.typeLabel}  ${item.subtitle}'),
                    onChanged: (visible) =>
                        store.setUpcomingItemHidden(item.key, !visible),
                  ),
            ],
          ),
        );
      },
    ),
  );
}

class NotesHomeSection extends StatelessWidget {
  const NotesHomeSection({super.key, required this.style});

  final HomeSectionStyle style;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes.take(3).toList();
    if (notes.isEmpty) {
      return const InfoCard(
        child: EmptyState(icon: Icons.note_alt_outlined, text: '尚無筆記'),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final note in notes)
            SwipeDeleteTile(
              itemKey: 'home-note-${note.id}',
              confirmTitle: '刪除筆記？',
              confirmMessage: '確定要刪除這則筆記嗎？',
              onDelete: () => store.deleteNote(note),
              child: SizedBox(
                width: homeGridTileWidth(context),
                child: CompactInfoTile(
                  icon: note.isPinned ? Icons.push_pin : Icons.notes,
                  title: note.title,
                  subtitle: note.category,
                  onTap: () => showNoteEditor(context, note: note),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NoteTile(
              note: note,
              onTap: () => showNoteEditor(context, note: note),
              onDelete: () => store.deleteNote(note),
            ),
          ),
      ],
    );
  }
}

class TodoHomeSection extends StatefulWidget {
  const TodoHomeSection({
    super.key,
    required this.style,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final HomeSectionStyle style;

  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  State<TodoHomeSection> createState() => _TodoHomeSectionState();
}

class _TodoHomeSectionState extends State<TodoHomeSection> {
  bool showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: showCompleted ? '已完成事項' : '待辦事項',
          onTap: widget.onToggleCollapsed,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => showCompleted = !showCompleted),
                icon: Icon(
                  showCompleted ? Icons.checklist : Icons.task_alt_outlined,
                ),
                label: Text(showCompleted ? '待辦事項' : '已完成'),
              ),
              IconButton(
                tooltip: '新增待辦事項',
                onPressed: () => openTodoEditorPage(context),
                icon: const Icon(Icons.add_task),
              ),
              Icon(widget.collapsed ? Icons.expand_more : Icons.expand_less),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: widget.collapsed
              ? const SizedBox.shrink(key: ValueKey('todo-collapsed'))
              : TodoBlock(
                  key: ValueKey(
                    'todo-${showCompleted ? 'completed' : 'active'}-${widget.style.name}',
                  ),
                  compact: widget.style == HomeSectionStyle.grid,
                  showCompleted: showCompleted,
                ),
        ),
      ],
    );
  }
}

class TodoBlock extends StatelessWidget {
  const TodoBlock({
    super.key,
    this.compact = false,
    this.showCompleted = false,
  });

  final bool compact;
  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final todos = showCompleted ? store.completedTodayTodos : store.activeTodos;
    if (todos.isEmpty) {
      return InfoCard(
        child: EmptyState(
          icon: showCompleted ? Icons.task_alt : Icons.checklist,
          text: showCompleted ? '今日沒有已完成項目' : '尚無待辦事項',
        ),
      );
    }

    return InfoCard(
      child: showCompleted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '今日已完成項目',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < todos.length; index++) ...[
                  EditableTodoRow(todo: todos[index], compact: compact),
                  if (index != todos.length - 1)
                    const Divider(height: 8, thickness: 0.6),
                ],
              ],
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: todos.length,
              onReorderItem: store.reorderActiveTodo,
              itemBuilder: (context, index) => Column(
                key: ValueKey(todos[index].id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  EditableTodoRow(
                    todo: todos[index],
                    compact: compact,
                    reorderIndex: index,
                  ),
                  if (index != todos.length - 1)
                    const Divider(height: 8, thickness: 0.6),
                ],
              ),
            ),
    );
  }
}

class EditableTodoRow extends StatefulWidget {
  const EditableTodoRow({
    super.key,
    required this.todo,
    this.compact = false,
    this.reorderIndex,
  });

  final TodoItem todo;
  final bool compact;
  final int? reorderIndex;

  @override
  State<EditableTodoRow> createState() => _EditableTodoRowState();
}

class _EditableTodoRowState extends State<EditableTodoRow> {
  late final TextEditingController controller;
  late final FocusNode focusNode;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.todo.title);
    focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        commitTitle();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EditableTodoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id && !editing) {
      controller.text = widget.todo.title;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void startEditing() {
    setState(() => editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      focusNode.requestFocus();
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    });
  }

  void commitTitle() {
    if (!editing) {
      return;
    }
    final nextTitle = controller.text.trim();
    if (nextTitle.isNotEmpty && nextTitle != widget.todo.title) {
      widget.todo.title = nextTitle;
      AppStoreScope.of(context).upsertTodo(widget.todo);
    } else {
      controller.text = widget.todo.title;
    }
    if (mounted) {
      setState(() => editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final metaStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.black54);
    return InkWell(
      onLongPress: () => openTodoEditorPage(context, todo: widget.todo),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: widget.todo.done,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => store.toggleTodo(widget.todo),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.todo.done
                                ? todoCompletedLabel(widget.todo)
                                : todoDueLabel(widget.todo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                        if (widget.todo.reminderEnabled) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.notifications_active,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            todoReminderTimeLabel(widget.todo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (editing)
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: widget.compact ? 2 : null,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: todoTitleStyle(widget.todo),
                        onSubmitted: (_) => commitTitle(),
                      )
                    else
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: startEditing,
                        child: Text(
                          widget.todo.title,
                          maxLines: widget.compact ? 2 : null,
                          overflow: widget.compact
                              ? TextOverflow.ellipsis
                              : null,
                          style: todoTitleStyle(widget.todo),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.reorderIndex != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ReorderableDragStartListener(
                  index: widget.reorderIndex!,
                  child: const Icon(Icons.drag_handle, color: Colors.black45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TodoCard extends StatelessWidget {
  const TodoCard({super.key, required this.todo, this.compact = true});

  final TodoItem todo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => store.toggleTodo(todo),
        onLongPress: () => openTodoEditorPage(context, todo: todo),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: todo.done,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => store.toggleTodo(todo),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              todo.done
                                  ? todoCompletedLabel(todo)
                                  : todoDueLabel(todo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ),
                          if (todo.reminderEnabled) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_active,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              todoReminderTimeLabel(todo),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        todo.title,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: TextStyle(
                          decoration: todo.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.done ? Colors.black45 : null,
                          fontWeight: FontWeight.w700,
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

class CompactInfoTile extends StatelessWidget {
  const CompactInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionSummaryTile extends StatelessWidget {
  const SubscriptionSummaryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: SubscriptionSummaryContent(
        icon: icon,
        title: title,
        subtitle: subtitle,
        amount: amount,
      ),
    );
  }
}

class SubscriptionSummaryContent extends StatelessWidget {
  const SubscriptionSummaryContent({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class HomeTileWrap extends StatelessWidget {
  const HomeTileWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: 12,
        runSpacing: 12,
        children: children,
      ),
    );
  }
}

double homeGridTileWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= 720 ? 220 : (width - 44) / 2;
}

Future<void> showHomeLayoutSettings(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => const HomeLayoutSettingsPage(),
    ),
  );
}

class HomeLayoutSettingsPage extends StatelessWidget {
  const HomeLayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '調整首頁',
          subtitle: '排序、顯示與版面樣式',
          leading: const PageBackButton(),
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: store.homeSectionOrder.length,
                  onReorderItem: store.reorderHomeSectionsToIndex,
                  itemBuilder: (context, index) {
                    final section = store.homeSectionOrder[index];
                    return HomeLayoutSettingsCard(
                      key: ValueKey(section),
                      section: section,
                      index: index,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: 1 + animation.value * 0.03,
                          child: child,
                        ),
                      ),
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '拖曳右側三條線調整順序，顯示設定會立即更新。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showHomeLayoutSettingsSheet(BuildContext context) async {
  final store = AppStoreScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '返回',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: store.homeSectionOrder.length,
                  onReorderItem: store.reorderHomeSectionsToIndex,
                  itemBuilder: (context, index) {
                    final section = store.homeSectionOrder[index];
                    return HomeLayoutSettingsCard(
                      key: ValueKey(section),
                      section: section,
                      index: index,
                    );
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1 + animation.value * 0.03,
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '首頁標題可點擊收合各區塊。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class HomeLayoutSettingsCard extends StatelessWidget {
  const HomeLayoutSettingsCard({
    super.key,
    required this.section,
    required this.index,
  });

  final HomeSectionId section;
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final style = store.homeSectionStyles[section] ?? HomeSectionStyle.list;
    final visible = !store.hiddenHomeSections.contains(section);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: visible,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => store.toggleHomeSectionVisible(section),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    homeSectionTitle(section),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: IconButton(
                    tooltip: '拖曳排序',
                    onPressed: null,
                    icon: const Icon(Icons.drag_handle),
                    disabledColor: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<HomeSectionStyle>(
                    segments: const [
                      ButtonSegment(
                        value: HomeSectionStyle.list,
                        label: Text('條列'),
                        icon: Icon(Icons.view_list),
                      ),
                      ButtonSegment(
                        value: HomeSectionStyle.grid,
                        label: Text('方塊'),
                        icon: Icon(Icons.grid_view),
                      ),
                    ],
                    selected: {style},
                    onSelectionChanged: (value) =>
                        store.setHomeSectionStyle(section, value.first),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class EqualMenuIcon extends StatelessWidget {
  const EqualMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              Container(
                width: 18,
                height: 2,
                decoration: BoxDecoration(
                  color: IconTheme.of(context).color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (index != 2) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class NotesNavigationDrawer extends StatefulWidget {
  const NotesNavigationDrawer({
    super.key,
    required this.selectedFolder,
    required this.showingTrash,
    required this.onAllNotes,
    required this.onFolderSelected,
    required this.onNoteSelected,
    required this.onTrash,
  });

  final String selectedFolder;
  final bool showingTrash;
  final VoidCallback onAllNotes;
  final ValueChanged<String> onFolderSelected;
  final ValueChanged<NoteItem> onNoteSelected;
  final VoidCallback onTrash;

  @override
  State<NotesNavigationDrawer> createState() => _NotesNavigationDrawerState();
}

class _NotesNavigationDrawerState extends State<NotesNavigationDrawer> {
  final Set<String> expandedFolders = {};
  bool uncategorizedExpanded = false;

  @override
  void initState() {
    super.initState();
    expandSelectedFolder();
  }

  @override
  void didUpdateWidget(covariant NotesNavigationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFolder != widget.selectedFolder) {
      expandSelectedFolder();
    }
  }

  void expandSelectedFolder() {
    if (widget.selectedFolder.isEmpty) {
      uncategorizedExpanded = true;
      return;
    }
    if (widget.selectedFolder == '所有筆記') {
      return;
    }
    var current = normalizeFolderPath(widget.selectedFolder);
    while (current.isNotEmpty) {
      expandedFolders.add(current);
      current = folderParentPath(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes;
    final rootFolders = store.folderPaths
        .where((folder) => folderParentPath(folder).isEmpty)
        .toList(growable: false);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Text(
                '筆記',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('所有筆記'),
              trailing: Text('${notes.length}'),
              selected: !widget.showingTrash && widget.selectedFolder == '所有筆記',
              onTap: () {
                Navigator.pop(context);
                widget.onAllNotes();
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text('資料夾'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 16),
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('未分類'),
              trailing: FolderExpandButton(
                expanded: uncategorizedExpanded,
                count: notes.where((note) => note.category.isEmpty).length,
                onPressed: notes.any((note) => note.category.isEmpty)
                    ? () => setState(
                        () => uncategorizedExpanded = !uncategorizedExpanded,
                      )
                    : null,
              ),
              selected: !widget.showingTrash && widget.selectedFolder.isEmpty,
              onTap: () {
                Navigator.pop(context);
                widget.onFolderSelected('');
              },
            ),
            if (uncategorizedExpanded)
              for (final note in notes.where((note) => note.category.isEmpty))
                NotesDrawerNoteTile(
                  note: note,
                  depth: 1,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteSelected(note);
                  },
                  onLongPress: () => showNoteNavActions(context, note),
                ),
            for (final folder in rootFolders)
              ...buildFolderBranch(context, store, notes, folder, 0),
            const Divider(height: 28),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('垃圾桶'),
              trailing: Text('${store.trashNotes.length}'),
              selected: widget.showingTrash,
              onTap: () {
                Navigator.pop(context);
                widget.onTrash();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildFolderBranch(
    BuildContext context,
    AppStore store,
    List<NoteItem> notes,
    String folder,
    int depth,
  ) {
    final childFolders = store.folderPaths
        .where((item) => folderParentPath(item) == folder)
        .toList(growable: false);
    final directNotes = notes
        .where((note) => note.category == folder)
        .toList(growable: false);
    final expanded = expandedFolders.contains(folder);
    final hasChildren = childFolders.isNotEmpty || directNotes.isNotEmpty;

    return [
      NotesDrawerFolderTile(
        folder: folder,
        depth: depth,
        expanded: expanded,
        canExpand: hasChildren,
        selected: !widget.showingTrash && widget.selectedFolder == folder,
        count: notes
            .where((note) => folderContains(folder, note.category))
            .length,
        onTap: () {
          Navigator.pop(context);
          widget.onFolderSelected(folder);
        },
        onToggle: hasChildren
            ? () => setState(() {
                if (expanded) {
                  expandedFolders.remove(folder);
                } else {
                  expandedFolders.add(folder);
                }
              })
            : null,
        onLongPress: () => showFolderNavActions(context, folder),
      ),
      if (expanded) ...[
        for (final childFolder in childFolders)
          ...buildFolderBranch(context, store, notes, childFolder, depth + 1),
        for (final note in directNotes)
          NotesDrawerNoteTile(
            note: note,
            depth: depth + 1,
            onTap: () {
              Navigator.pop(context);
              widget.onNoteSelected(note);
            },
            onLongPress: () => showNoteNavActions(context, note),
          ),
      ],
    ];
  }

  Future<void> showFolderNavActions(BuildContext context, String folder) async {
    final store = AppStoreScope.of(context);
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
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final name = await promptForText(
                  context,
                  title: '重新命名',
                  label: '名稱',
                  initialValue: folderBaseName(folder),
                );
                if (name != null && name.trim().isNotEmpty) {
                  store.renameNoteFolder(folder, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(
                  context,
                  store,
                  title: '移動',
                  excludedFolder: folder,
                  rootLabel: '根目錄',
                );
                if (target != null) {
                  store.moveNoteFolder(folder, target);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  context,
                  title: '刪除資料夾？',
                  message: '確定要刪除這個資料夾嗎？',
                );
                if (confirmed) {
                  store.deleteNoteFolder(folder);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showNoteNavActions(BuildContext context, NoteItem note) async {
    final store = AppStoreScope.of(context);
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
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final title = await promptForText(
                  context,
                  title: '重新命名',
                  label: '筆記標題',
                  initialValue: note.title,
                );
                if (title != null) {
                  store.renameNote(note, title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(context, store);
                if (target != null) {
                  store.moveNoteToFolder(note, target);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除筆記'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  context,
                  title: '刪除筆記？',
                  message: '確定要刪除這筆筆記嗎？',
                );
                if (confirmed) {
                  store.deleteNote(note);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NotesDrawerFolderTile extends StatelessWidget {
  const NotesDrawerFolderTile({
    super.key,
    required this.folder,
    required this.depth,
    required this.expanded,
    required this.canExpand,
    required this.selected,
    required this.count,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final String folder;
  final int depth;
  final bool expanded;
  final bool canExpand;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + depth * 18, right: 16),
      leading: const Icon(Icons.folder_outlined),
      title: Text(folderBaseName(folder)),
      trailing: FolderExpandButton(
        expanded: expanded,
        count: count,
        onPressed: canExpand ? onToggle : null,
      ),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class FolderExpandButton extends StatelessWidget {
  const FolderExpandButton({
    super.key,
    required this.expanded,
    required this.count,
    required this.onPressed,
  });

  final bool expanded;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      return Text('$count');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count'),
        const SizedBox(width: 4),
        IconButton(
          tooltip: expanded ? '收合資料夾' : '展開資料夾',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
          ),
        ),
      ],
    );
  }
}

class NotesDrawerNoteTile extends StatelessWidget {
  const NotesDrawerNoteTile({
    super.key,
    required this.note,
    required this.depth,
    required this.onTap,
    required this.onLongPress,
  });

  final NoteItem note;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 44 + depth * 18, right: 16),
      leading: Icon(
        note.isPinned ? Icons.push_pin : Icons.description_outlined,
        size: 18,
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  String query = '';
  String folder = '所有筆記';
  NotesDateFilter dateFilter = NotesDateFilter.all;
  NotesSortField sortField = NotesSortField.updatedAt;
  SortDirection sortDirection = SortDirection.descending;
  NotesViewMode viewMode = NotesViewMode.list;
  final Set<NoteTemplateType> templateFilters = {};
  bool showFilters = false;
  bool batchMode = false;
  bool showingTrash = false;
  bool addMenuOpen = false;
  final Set<String> selectedNoteIds = {};
  late final AnimationController addFabController;

  @override
  void initState() {
    super.initState();
    addFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    addFabController.dispose();
    super.dispose();
  }

  void toggleAddMenu() {
    if (addMenuOpen) {
      closeAddMenu();
    } else {
      setState(() => addMenuOpen = true);
      addFabController.forward();
    }
  }

  void closeAddMenu() {
    if (!addMenuOpen) {
      return;
    }
    setState(() => addMenuOpen = false);
    addFabController.reverse();
  }

  Future<void> handleAddMenu(String value) async {
    closeAddMenu();
    final templateType = noteTemplateTypeFromMenuValue(value);
    if (templateType != null) {
      await showNoteEditor(
        context,
        initialFolder: currentFolderContext,
        initialTemplateType: templateType,
      );
    }
  }

  String get currentFolderContext {
    if (showingTrash || folder == '所有筆記') {
      return '';
    }
    return folder;
  }

  String get currentDirectoryTitle {
    if (showingTrash) {
      return '垃圾桶';
    }
    if (folder == '所有筆記') {
      return '所有筆記';
    }
    if (folder.isEmpty) {
      return '未分類';
    }
    return folder.replaceAll('/', '\\');
  }

  void openNotesFolder(String value) {
    setState(() {
      showingTrash = false;
      folder = value;
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  Widget buildDirectoryTitle(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
    final linkStyle = titleStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    final separatorStyle = titleStyle?.copyWith(color: Colors.black38);

    Widget item(String label, String target) {
      final isCurrent = !showingTrash && !batchMode && folder == target;
      final style = isCurrent ? titleStyle : linkStyle;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openNotesFolder(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (target != '所有筆記' && target.isNotEmpty) ...[
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: style?.color ?? Theme.of(context).iconTheme.color,
                ),
                const SizedBox(width: 4),
              ],
              Text(label, style: style, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    if (showingTrash) {
      return Text(currentDirectoryTitle, style: titleStyle);
    }
    if (folder == '所有筆記') {
      return item('所有筆記', '所有筆記');
    }
    if (folder.isEmpty) {
      return item('未分類', '');
    }

    final parts = normalizeFolderPath(folder).split('/');
    final children = <Widget>[];
    for (var index = 0; index < parts.length; index++) {
      final target = parts.take(index + 1).join('/');
      if (index > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Text('\\', style: separatorStyle),
          ),
        );
      }
      children.add(item(parts[index], target));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final folders = ['所有筆記', '', ...store.folderPaths];
    var notes = (showingTrash ? store.trashNotes : store.visibleNotes).where((
      note,
    ) {
      final text =
          '${note.title} ${note.body} ${note.category} ${note.tags.join(' ')}'
              .toLowerCase();
      return text.contains(query.toLowerCase()) &&
          (showingTrash ||
              folder == '所有筆記' ||
              (folder.isEmpty
                  ? note.category.isEmpty
                  : folderContains(folder, note.category))) &&
          (templateFilters.isEmpty ||
              templateFilters.contains(note.templateType)) &&
          matchesDateFilter(note, dateFilter);
    }).toList();
    notes.sort(compareNotes);
    final pinnedNotes = showingTrash
        ? <NoteItem>[]
        : notes.where((note) => note.isPinned).toList();
    final regularNotes = showingTrash
        ? notes
        : notes.where((note) => !note.isPinned).toList();
    final childFolders = directChildFolders(store.folderPaths);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: NotesNavigationDrawer(
        selectedFolder: folder,
        showingTrash: showingTrash,
        onAllNotes: () => setState(() {
          showingTrash = false;
          folder = '所有筆記';
          batchMode = false;
          selectedNoteIds.clear();
        }),
        onFolderSelected: (value) => setState(() {
          showingTrash = false;
          folder = value;
          batchMode = false;
          selectedNoteIds.clear();
        }),
        onNoteSelected: (note) => showNoteEditor(context, note: note),
        onTrash: () => setState(() {
          showingTrash = true;
          batchMode = false;
          selectedNoteIds.clear();
        }),
      ),
      floatingActionButton: showingTrash
          ? null
          : FloatingActionMenu(
              isOpen: addMenuOpen,
              controller: addFabController,
              tooltip: '新增筆記',
              onToggle: toggleAddMenu,
              heroTag: 'notes-add',
              items: [
                FloatingActionMenuItem(
                  icon: Icons.notes,
                  label: '筆記',
                  value: noteTemplateMenuValue(NoteTemplateType.general),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.flag_outlined,
                  label: '計劃',
                  value: noteTemplateMenuValue(NoteTemplateType.plan),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.account_tree_outlined,
                  label: '心智圖',
                  value: noteTemplateMenuValue(NoteTemplateType.mindMap),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.stacked_bar_chart,
                  label: '人生試算表',
                  value: noteTemplateMenuValue(NoteTemplateType.lifeSheet),
                  onSelected: handleAddMenu,
                ),
              ],
            ),
      body: AppPage(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: '開啟側邊欄',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const EqualMenuIcon(),
          ),
        ),
        title: currentDirectoryTitle,
        titleWidget: buildDirectoryTitle(context),
        subtitle: '資料夾、標籤與搜尋',
        actions: [
          IconButton(
            tooltip: '搜尋與篩選',
            onPressed: () => setState(() => showFilters = !showFilters),
            icon: Icon(showFilters ? Icons.search_off : Icons.search),
          ),
          if (showingTrash)
            IconButton(
              tooltip: '清空垃圾桶',
              onPressed: clearTrashNotes,
              icon: const Icon(Icons.delete_sweep_outlined),
            )
          else
            IconButton(
              tooltip: '建立資料夾',
              onPressed: createFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
        ],
        child: Column(
          children: [
            if (batchMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: showingTrash
                    ? TrashBatchActionBar(
                        selectedCount: selectedNoteIds.length,
                        onRestore: selectedNoteIds.isEmpty
                            ? null
                            : () => restoreSelectedTrashNotes(store),
                        onDelete: selectedNoteIds.isEmpty
                            ? null
                            : () => permanentlyDeleteSelectedTrashNotes(store),
                        onDone: exitBatchMode,
                      )
                    : BatchActionBar(
                        selectedCount: selectedNoteIds.length,
                        canRename: selectedNoteIds.length == 1,
                        onDelete: selectedNoteIds.isEmpty
                            ? null
                            : () => deleteSelectedNotes(store),
                        onMove: selectedNoteIds.isEmpty
                            ? null
                            : () => moveSelectedNotes(store),
                        onRename: selectedNoteIds.length == 1
                            ? () => renameSelectedNote(store)
                            : null,
                        onDone: exitBatchMode,
                      ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (showFilters) ...[
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜尋標題、內文、標籤',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DropdownMenu<String>(
                          initialSelection: folder,
                          label: const Text('資料夾'),
                          dropdownMenuEntries: folders
                              .map(
                                (item) => DropdownMenuEntry(
                                  value: item,
                                  label: item.isEmpty ? '未分類' : item,
                                ),
                              )
                              .toList(),
                          onSelected: (value) =>
                              setState(() => folder = value ?? '所有筆記'),
                        ),
                        DropdownMenu<NotesDateFilter>(
                          initialSelection: dateFilter,
                          label: const Text('日期篩選'),
                          dropdownMenuEntries: NotesDateFilter.values
                              .map(
                                (item) => DropdownMenuEntry(
                                  value: item,
                                  label: noteDateFilterLabel(item),
                                ),
                              )
                              .toList(),
                          onSelected: (value) => setState(
                            () => dateFilter = value ?? NotesDateFilter.all,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  NotesSortSummary(
                    sortField: sortField,
                    sortDirection: sortDirection,
                    viewMode: viewMode,
                    selectedTemplates: templateFilters,
                    onSortChanged: (field, direction) {
                      setState(() {
                        sortField = field;
                        sortDirection = direction;
                      });
                    },
                    onViewModeChanged: (mode) =>
                        setState(() => viewMode = mode),
                    onTemplateToggled: (type) {
                      setState(() {
                        if (!templateFilters.add(type)) {
                          templateFilters.remove(type);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (notes.isEmpty && childFolders.isEmpty)
                    EmptyState(
                      icon: Icons.note_alt_outlined,
                      text: showingTrash ? '垃圾桶沒有筆記' : '還沒有筆記',
                    )
                  else ...[
                    if (childFolders.isNotEmpty)
                      NotesFolderGrid(
                        folders: childFolders,
                        onTap: openNotesFolder,
                        onLongPress: showFolderActions,
                      ),
                    if (pinnedNotes.isNotEmpty)
                      NotesGroupContainer(
                        notes: pinnedNotes,
                        mode: viewMode,
                        batchMode: batchMode,
                        selectedNoteIds: selectedNoteIds,
                        onSelectionChanged: toggleSelected,
                        onTap: handleNoteTap,
                        onLongPress: enterBatchModeWith,
                        readOnly: showingTrash,
                        onDelete: showingTrash
                            ? null
                            : (note) => store.deleteNote(note),
                      ),
                    if (regularNotes.isNotEmpty)
                      NotesGroupContainer(
                        notes: regularNotes,
                        mode: viewMode,
                        batchMode: batchMode,
                        selectedNoteIds: selectedNoteIds,
                        onSelectionChanged: toggleSelected,
                        onTap: handleNoteTap,
                        onLongPress: enterBatchModeWith,
                        readOnly: showingTrash,
                        onDelete: showingTrash
                            ? null
                            : (note) => store.deleteNote(note),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> directChildFolders(List<String> folders) {
    if (showingTrash || folder.isEmpty) {
      return [];
    }
    if (folder == '所有筆記') {
      return folders
          .where((item) => folderParentPath(item).isEmpty)
          .toList(growable: false);
    }
    final current = normalizeFolderPath(folder);
    return folders
        .where((item) => folderParentPath(item) == current)
        .toList(growable: false);
  }

  int compareNotes(NoteItem a, NoteItem b) {
    int result;
    switch (sortField) {
      case NotesSortField.createdAt:
        result = a.createdAt.compareTo(b.createdAt);
        break;
      case NotesSortField.updatedAt:
        result = a.updatedAt.compareTo(b.updatedAt);
        break;
      case NotesSortField.title:
        result = a.title.compareTo(b.title);
        break;
      case NotesSortField.tag:
        result = firstTag(a).compareTo(firstTag(b));
        break;
    }
    if (result == 0 && a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    return sortDirection == SortDirection.ascending ? result : -result;
  }

  String firstTag(NoteItem note) => note.tags.isEmpty ? '' : note.tags.first;

  bool matchesDateFilter(NoteItem note, NotesDateFilter filter) {
    if (filter == NotesDateFilter.all) {
      return true;
    }
    final now = DateTime.now();
    final days = switch (filter) {
      NotesDateFilter.oneDay => 1,
      NotesDateFilter.sevenDays => 7,
      NotesDateFilter.thirtyDays => 30,
      NotesDateFilter.all => 0,
    };
    return note.updatedAt.isAfter(now.subtract(Duration(days: days)));
  }

  void handleNoteTap(NoteItem note) {
    if (batchMode) {
      toggleSelected(note);
      return;
    }
    showNoteEditor(context, note: note, readOnly: showingTrash);
  }

  void enterBatchModeWith(NoteItem note) {
    setState(() {
      if (!batchMode) {
        selectedNoteIds.clear();
      }
      batchMode = true;
      selectedNoteIds.add(note.id);
    });
  }

  void exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  void toggleSelected(NoteItem note) {
    setState(() {
      if (!selectedNoteIds.add(note.id)) {
        selectedNoteIds.remove(note.id);
      }
    });
  }

  Future<void> showNotesOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (showingTrash) ...[
              ListTile(
                leading: Icon(batchMode ? Icons.close : Icons.checklist),
                title: Text(batchMode ? '完成編輯' : '編輯'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    batchMode = !batchMode;
                    selectedNoteIds.clear();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('刪除全部'),
                onTap: () {
                  Navigator.pop(context);
                  clearTrashNotes();
                },
              ),
            ] else
              ListTile(
                leading: Icon(batchMode ? Icons.close : Icons.checklist),
                title: Text(batchMode ? '完成編輯' : '編輯'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    batchMode = !batchMode;
                    selectedNoteIds.clear();
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('檢視'),
              subtitle: Text(notesViewModeLabel(viewMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showNotesViewOptions(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: const Text('排序'),
              subtitle: Text(
                '${notesSortFieldLabel(sortField)}'
                ' ${sortDirectionSymbol(sortDirection)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showNotesSortOptions(context);
              },
            ),
            if (!showingTrash)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('建立資料夾'),
                onTap: () {
                  Navigator.pop(context);
                  createFolder();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> clearTrashNotes() async {
    final store = AppStoreScope.of(context);
    if (store.trashNotes.isEmpty) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除全部？',
      message: '確定要清空垃圾桶嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    store.clearTrashNotes();
  }

  Future<void> showNotesViewOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SheetBackHeader(
              title: '檢視',
              onBack: () {
                Navigator.pop(context);
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    showNotesOptions(this.context);
                  }
                });
              },
            ),
            for (final mode in NotesViewMode.values)
              ListTile(
                leading: Icon(notesViewModeIcon(mode)),
                title: Text(notesViewModeLabel(mode)),
                trailing: viewMode == mode ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => viewMode = mode);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showNotesSortOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SheetBackHeader(
              title: '排序',
              onBack: () {
                Navigator.pop(context);
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    showNotesOptions(this.context);
                  }
                });
              },
            ),
            for (final field in NotesSortField.values)
              for (final direction in SortDirection.values)
                ListTile(
                  leading: Icon(notesSortFieldIcon(field)),
                  title: Text(
                    '${notesSortFieldLabel(field)}'
                    ' ${sortDirectionSymbol(direction)}',
                  ),
                  trailing: sortField == field && sortDirection == direction
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      sortField = field;
                      sortDirection = direction;
                    });
                  },
                ),
          ],
        ),
      ),
    );
  }

  Future<void> createFolder() async {
    final store = AppStoreScope.of(context);
    final name = await promptForText(context, title: '新增資料夾', label: '資料夾名稱');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final newFolder = joinFolderPath(currentFolderContext, name);
    store.createNoteFolder(newFolder);
    setState(() {
      showingTrash = false;
      folder = newFolder;
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  Future<void> showFolderActions(String targetFolder) async {
    final store = AppStoreScope.of(context);
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
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final name = await promptForText(
                  this.context,
                  title: '重新命名',
                  label: '名稱',
                  initialValue: folderBaseName(targetFolder),
                );
                if (name != null && name.trim().isNotEmpty) {
                  store.renameNoteFolder(targetFolder, name);
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(
                  this.context,
                  store,
                  title: '移動',
                  excludedFolder: targetFolder,
                  rootLabel: '根目錄',
                );
                if (target != null) {
                  store.moveNoteFolder(targetFolder, target);
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  this.context,
                  title: '刪除資料夾？',
                  message: '確定要刪除這個資料夾嗎？',
                );
                if (confirmed) {
                  store.deleteNoteFolder(targetFolder);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteSelectedNotes(AppStore store) async {
    final confirmed = await confirmDelete(
      context,
      title: '刪除選取筆記？',
      message: '確定要刪除選取的筆記嗎？',
    );
    if (!confirmed) {
      return;
    }
    store.deleteNotesById(selectedNoteIds);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  void restoreSelectedTrashNotes(AppStore store) {
    store.restoreNotesById(selectedNoteIds);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  Future<void> permanentlyDeleteSelectedTrashNotes(AppStore store) async {
    final confirmed = await confirmDelete(
      context,
      title: '刪除選取筆記？',
      message: '這會永久刪除垃圾桶中選取的筆記，確定要刪除嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    store.permanentlyDeleteNotesById(selectedNoteIds);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
    });
  }

  Future<void> moveSelectedNotes(AppStore store) async {
    final folderName = await chooseFolder(context, store);
    if (folderName == null) {
      return;
    }
    store.moveNotesToFolder(selectedNoteIds, folderName);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      folder = folderName;
    });
  }

  Future<void> renameSelectedNote(AppStore store) async {
    final note = store.notes.firstWhere(
      (item) => item.id == selectedNoteIds.first,
    );
    final title = await promptForText(
      context,
      title: '重新命名',
      label: '筆記標題',
      initialValue: note.title,
    );
    if (title == null) {
      return;
    }
    store.renameNote(note, title);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
    });
  }
}

class NotesGroupContainer extends StatelessWidget {
  const NotesGroupContainer({
    super.key,
    required this.notes,
    required this.mode,
    required this.batchMode,
    required this.selectedNoteIds,
    required this.onSelectionChanged,
    required this.onTap,
    required this.onLongPress,
    this.readOnly = false,
    this.onDelete,
  });

  final List<NoteItem> notes;
  final NotesViewMode mode;
  final bool batchMode;
  final Set<String> selectedNoteIds;
  final ValueChanged<NoteItem> onSelectionChanged;
  final ValueChanged<NoteItem> onTap;
  final ValueChanged<NoteItem> onLongPress;
  final bool readOnly;
  final ValueChanged<NoteItem>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdfe6df)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == NotesViewMode.grid)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < 3; column++) ...[
                  if (column > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = column;
                          index < notes.length;
                          index += 3
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: buildTile(notes[index]),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          else
            for (var index = 0; index < notes.length; index++) ...[
              buildTile(notes[index]),
              if (index != notes.length - 1)
                const Divider(
                  height: 16,
                  thickness: 0.8,
                  color: Color(0xffe1e5e1),
                ),
            ],
        ],
      ),
    );
  }

  Widget buildTile(NoteItem note) {
    return NoteTile(
      note: note,
      mode: mode,
      selectable: batchMode,
      selected: selectedNoteIds.contains(note.id),
      onSelectionChanged: () => onSelectionChanged(note),
      onTap: () => onTap(note),
      onLongPress: () => onLongPress(note),
      readOnly: readOnly,
      onDelete: onDelete == null ? null : () => onDelete!(note),
    );
  }
}

class NotesFolderGrid extends StatelessWidget {
  const NotesFolderGrid({
    super.key,
    required this.folders,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> folders;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdfe6df)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final folder in folders)
              SizedBox(
                width: 58,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTap(folder),
                  onLongPress: () => onLongPress(folder),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          folderBaseName(folder),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewMode mode = CalendarViewMode.month;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final events = store.schedules.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final selectedEvents = events
        .where((event) => isSameDate(event.start, selectedDate))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AddBubbleButton(
        tooltip: '新增行程',
        onPressed: () => showScheduleEditor(context, initialDate: selectedDate),
        heroTag: 'calendar-add',
      ),
      body: AppPage(
        title: '行程',
        subtitle: '月曆、週曆與清單檢視',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            SegmentedButton<CalendarViewMode>(
              segments: const [
                ButtonSegment(
                  value: CalendarViewMode.month,
                  label: Text('月曆'),
                  icon: Icon(Icons.calendar_view_month),
                ),
                ButtonSegment(
                  value: CalendarViewMode.week,
                  label: Text('週曆'),
                  icon: Icon(Icons.view_week),
                ),
                ButtonSegment(
                  value: CalendarViewMode.list,
                  label: Text('清單'),
                  icon: Icon(Icons.list),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => setState(() => mode = value.first),
            ),
            const SizedBox(height: 16),
            if (mode == CalendarViewMode.month)
              MonthStrip(
                events: events,
                selectedDate: selectedDate,
                onDateSelected: (date) => setState(() => selectedDate = date),
              ),
            if (mode == CalendarViewMode.week)
              WeekStrip(
                events: events,
                selectedDate: selectedDate,
                onDateSelected: (date) => setState(() => selectedDate = date),
              ),
            if (mode != CalendarViewMode.list) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () =>
                        showScheduleEditor(context, initialDate: selectedDate),
                    icon: const Icon(Icons.add),
                    label: const Text('新增行程'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (mode == CalendarViewMode.list)
              ScheduleGroupedList(events: events)
            else ...[
              SectionHeader(title: '當日行程'),
              if (selectedEvents.isEmpty)
                const EmptyState(icon: Icons.event_busy, text: '當日沒有行程')
              else
                for (final event in selectedEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ScheduleTile(
                      event: event,
                      onTap: () => showScheduleEditor(context, event: event),
                      onDelete: () => store.deleteSchedule(event),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            InfoCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('提醒通知'),
                subtitle: const Text('提醒已開啟'),
                trailing: const Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool showSubscriptions = false;
  bool showCashFlowAmounts = false;
  bool showSavingsAccountAmounts = false;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final grouped = groupExpensesByCategory(store.financeEntries);
    final incomeGrouped = groupIncomeByAccount(store.financeEntries);
    final budgetRatio = store.monthlyBudget == 0
        ? 0.0
        : (store.monthlyExpense / store.monthlyBudget).clamp(0.0, 1.3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AddBubbleButton(
        tooltip: '新增記帳',
        onPressed: () => showFinanceEditor(context),
        heroTag: 'finance-add',
      ),
      body: AppPage(
        title: '記帳',
        subtitle: '收入、支出、預算與訂閱管理',
        actions: [
          IconButton(
            tooltip: '近期紀錄',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const FinanceHistoryPage(),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: '訂閱管理',
            onPressed: () => showSubscriptionManager(context),
            icon: const Icon(Icons.subscriptions),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            SectionHeader(
              title: '金流',
              trailing: IconButton(
                tooltip: showCashFlowAmounts ? '隱藏金額' : '顯示金額',
                onPressed: () =>
                    setState(() => showCashFlowAmounts = !showCashFlowAmounts),
                icon: Icon(
                  showCashFlowAmounts
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            FinanceMetricRow(
              items: [
                FinanceMetricInfo(
                  id: 'savings',
                  title: '存餘',
                  value: currency(store.savingsTotal),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xff4568b2),
                ),
                FinanceMetricInfo(
                  id: 'income',
                  title: '本月收入',
                  value: currency(store.monthlyIncome),
                  icon: Icons.trending_up,
                  color: const Color(0xff34785f),
                ),
                FinanceMetricInfo(
                  id: 'expense',
                  title: '本月支出',
                  value: currency(store.monthlyExpense),
                  icon: Icons.trending_down,
                  color: const Color(0xffb5533d),
                ),
              ],
              visible: showCashFlowAmounts,
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '存餘帳戶',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: showSavingsAccountAmounts ? '隱藏帳戶金額' : '顯示帳戶金額',
                    onPressed: () => setState(
                      () => showSavingsAccountAmounts =
                          !showSavingsAccountAmounts,
                    ),
                    icon: Icon(
                      showSavingsAccountAmounts
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: '新增帳戶',
                    onPressed: () => showSavingsAccountEditor(context),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            if (store.savingsAccounts.isEmpty)
              const InfoCard(
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  text: '尚無存餘帳戶',
                ),
              )
            else
              HomeTileWrap(
                children: [
                  for (final account in store.savingsAccounts)
                    SizedBox(
                      width: homeGridTileWidth(context),
                      child: SavingsAccountCard(
                        account: account,
                        visible: showSavingsAccountAmounts,
                        onLongPress: () =>
                            showSavingsAccountActions(context, account),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '月預算提醒',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text('預算: ${currency(store.monthlyBudget)}'),
                            Text('花費: ${currency(store.monthlyExpense)}'),
                            Text(
                              '剩餘: ${currency(store.monthlyBudget - store.monthlyExpense)}',
                              style: TextStyle(
                                color:
                                    store.monthlyBudget >= store.monthlyExpense
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatPercent(budgetRatio),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => showBudgetEditor(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('調整預算'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '支出分類',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        const FinanceTimelinePage(type: EntryType.expense),
                  ),
                ),
                child: const Text('查看'),
              ),
            ),
            InfoCard(
              child: grouped.isEmpty
                  ? const EmptyState(
                      icon: Icons.pie_chart_outline,
                      text: '尚無支出資料',
                    )
                  : Column(children: [ExpensePieChart(grouped: grouped)]),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '收入分類',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        const FinanceTimelinePage(type: EntryType.income),
                  ),
                ),
                child: const Text('查看'),
              ),
            ),
            InfoCard(
              child: incomeGrouped.isEmpty
                  ? const EmptyState(icon: Icons.bar_chart, text: '尚無收入資料')
                  : IncomeAccountBarChart(grouped: incomeGrouped),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '訂閱管理',
              trailing: Switch(
                value: showSubscriptions,
                onChanged: (value) => setState(() => showSubscriptions = value),
              ),
            ),
            if (showSubscriptions)
              InfoCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('每月訂閱總額'),
                      subtitle: const Text('依月費與年費換算估計'),
                      trailing: Text(
                        currency(store.monthlySubscriptionTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final sub in store.upcomingSubscriptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SwipeDeleteTile(
                          itemKey: 'finance-subscription-${sub.id}',
                          confirmTitle: '刪除訂閱？',
                          confirmMessage: '這筆訂閱會從列表移除。',
                          onDelete: () => store.deleteSubscription(sub),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.autorenew),
                            title: Text(sub.name),
                            subtitle: Text(
                              '${formatDate(sub.nextPaymentDate)}  ${sub.paymentMethod}',
                            ),
                            trailing: Text(currency(sub.amount)),
                            onTap: () => showSubscriptionEditor(
                              context,
                              subscription: sub,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => showSubscriptionEditor(context),
                        icon: const Icon(Icons.add),
                        label: const Text('新增訂閱'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FinanceHistoryPage extends StatelessWidget {
  const FinanceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final entries = store.financeEntries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '近期紀錄',
          subtitle: '依日期排序的收入與支出',
          leading: const PageBackButton(),
          child: entries.isEmpty
              ? const EmptyState(icon: Icons.history, text: '目前沒有記帳紀錄')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final item in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FinanceTile(
                          entry: item,
                          onTap: () => showFinanceEditor(context, entry: item),
                          onDelete: () => store.deleteFinanceEntry(item),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class FinanceTimelinePage extends StatelessWidget {
  const FinanceTimelinePage({super.key, required this.type});

  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final entries =
        store.financeEntries.where((entry) => entry.type == type).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final groups = groupFinanceEntriesByDate(entries);
    final isIncome = type == EntryType.income;

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: isIncome ? '收入時間軸' : '支出時間軸',
          subtitle: isIncome ? '依日期查看收入紀錄' : '依日期查看支出紀錄',
          leading: const PageBackButton(),
          child: entries.isEmpty
              ? EmptyState(
                  icon: isIncome ? Icons.trending_up : Icons.trending_down,
                  text: isIncome ? '目前沒有收入紀錄' : '目前沒有支出紀錄',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final group in groups.entries) ...[
                      FinanceTimelineDateHeader(date: group.key),
                      for (final item in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FinanceTile(
                            entry: item,
                            onTap: () =>
                                showFinanceEditor(context, entry: item),
                            onDelete: () => store.deleteFinanceEntry(item),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class FinanceTimelineDateHeader extends StatelessWidget {
  const FinanceTimelineDateHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 17),
          const SizedBox(width: 8),
          Text(
            formatDate(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xff465064),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xffdfe5f4))),
        ],
      ),
    );
  }
}

class FinanceMetricInfo {
  const FinanceMetricInfo({
    required this.id,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class FinanceMetricRow extends StatelessWidget {
  const FinanceMetricRow({
    super.key,
    required this.items,
    required this.visible,
  });

  final List<FinanceMetricInfo> items;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(
              child: FinanceMetricCell(item: items[index], visible: visible),
            ),
            if (index != items.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class FinanceMetricCell extends StatelessWidget {
  const FinanceMetricCell({
    super.key,
    required this.item,
    required this.visible,
  });

  final FinanceMetricInfo item;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            visible ? item.value : '*****',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class SavingsAccountCard extends StatelessWidget {
  const SavingsAccountCard({
    super.key,
    required this.account,
    required this.visible,
    required this.onLongPress,
  });

  final SavingsAccount account;
  final bool visible;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                visible ? currency(account.amount) : '*****',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '設定',
      subtitle: 'Firebase 與上線規劃',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: const [
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
          SizedBox(height: 16),
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
          SizedBox(height: 16),
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
    return Material(
      color: colorScheme.surface,
      elevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: Offset(visible ? 0 : 0.26, 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
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
    this.trailing,
    this.onTap,
  });

  final String title;
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
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
          Chip(label: Text('已選 $selectedCount 筆')),
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
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('確認'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
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
                final name = await promptForText(
                  context,
                  title: '新增資料夾',
                  label: '資料夾名稱',
                );
                if (name == null || name.trim().isEmpty) {
                  return;
                }
                final newFolder = joinFolderPath(currentFolder, name);
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
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return InfoCard(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: MediaQuery.sizeOf(context).width >= 720
              ? 1.85
              : 1.05,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: firstDay.weekday % 7 + daysInMonth,
        itemBuilder: (context, index) {
          final offset = firstDay.weekday % 7;
          if (index < offset) return const SizedBox.shrink();
          final day = index - offset + 1;
          final date = DateTime(now.year, now.month, day);
          final count = events
              .where((event) => isSameDate(event.start, date))
              .length;
          final selected = isSameDate(date, selectedDate);
          final today = isSameDate(date, now);
          return InkWell(
            onTap: () => onDateSelected(date),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : today
                    ? Theme.of(context).colorScheme.primaryContainer
                    : const Color(0xfff1f3ef),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
    return InfoCard(
      child: Row(
        children: List.generate(7, (index) {
          final date = today.add(Duration(days: index));
          final count = events
              .where((event) => isSameDate(event.start, date))
              .length;
          final selected = isSameDate(date, selectedDate);
          return Expanded(
            child: InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 86,
                margin: EdgeInsets.only(right: index == 6 ? 0 : 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : index == 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xfff1f3ef),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayLabel(date.weekday),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
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
  NoteTemplateType initialTemplateType = NoteTemplateType.general,
  bool readOnly = false,
}) async {
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
}

Future<void> showScheduleEditor(
  BuildContext context, {
  ScheduleItem? event,
  DateTime? initialDate,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          ScheduleEditorPage(event: event, initialDate: initialDate),
    ),
  );
}

Future<void> showFinanceEditor(
  BuildContext context, {
  FinanceEntry? entry,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => FinanceEditorPage(entry: entry),
    ),
  );
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    this.note,
    this.initialFolder = '',
    this.initialTemplateType = NoteTemplateType.general,
    this.readOnly = false,
  });

  final NoteItem? note;
  final String initialFolder;
  final NoteTemplateType initialTemplateType;
  final bool readOnly;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class NoteTemplatePickerPage extends StatelessWidget {
  const NoteTemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '選擇筆記模板',
          subtitle: '每種模板會用各自的資料格式儲存',
          leading: const PageBackButton(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final type in NoteTemplateType.values) ...[
                NoteTemplatePickerCard(type: type),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NoteTemplatePickerCard extends StatelessWidget {
  const NoteTemplatePickerCard({super.key, required this.type});

  final NoteTemplateType type;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe4e8f5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(noteTemplateIcon(type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noteTemplateLabel(type),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noteTemplateDescription(type),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController title;
  late final RichNoteTextController body;
  late final TextEditingController tags;
  late String folder;
  late NoteTemplateType templateType;
  late Map<String, dynamic> templateData;
  late final String initialEditorBody;
  late final Map<String, dynamic> initialEditorTemplateData;
  late Map<String, dynamic> noteStyle;
  late List<Map<String, dynamic>> noteImages;
  late List<Map<String, dynamic>> noteAttachments;
  late Map<String, dynamic> noteBackground;
  bool allowPop = false;
  bool didSave = false;
  bool get readOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    title = TextEditingController(text: note?.title ?? '未命名筆記');
    tags = TextEditingController(text: formatTagsForEditing(note?.tags ?? []));
    folder = note?.category ?? normalizeFolderPath(widget.initialFolder);
    templateType = note?.templateType ?? widget.initialTemplateType;
    templateData = Map<String, dynamic>.from(
      note?.templateData ?? defaultNoteTemplateData(templateType),
    );
    final richSeed = templateType == NoteTemplateType.general
        ? richNoteSeedFromTemplateData(note?.body ?? '', templateData)
        : RichNoteSeed(text: note?.body ?? '', marks: const []);
    body = RichNoteTextController(text: richSeed.text, marks: richSeed.marks);
    noteStyle = Map<String, dynamic>.from(note?.style ?? defaultNoteStyle());
    noteImages = List<Map<String, dynamic>>.from(
      note?.images ?? <Map<String, dynamic>>[],
    );
    noteAttachments = List<Map<String, dynamic>>.from(
      note?.attachments ?? <Map<String, dynamic>>[],
    );
    noteBackground = Map<String, dynamic>.from(
      note?.background ?? defaultNoteBackground(),
    );
    if (templateType == NoteTemplateType.general) {
      migrateLegacyInlineAssets();
      body.isolateEmbedBlocks(images: noteImages);
      templateData = generalNoteTemplateData(
        templateData,
        body,
        noteImages,
        noteAttachments,
      );
      unawaited(hydrateInlineImageDimensions());
    }
    initialEditorBody = body.text;
    initialEditorTemplateData = cloneJsonMap(templateData);
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    tags.dispose();
    super.dispose();
  }

  bool get hasChanges {
    final note = widget.note;
    final nextTitle = title.text.trim();
    final nextBody = body.text;
    final nextFolder = folder.trim();
    final nextTags = splitTags(tags.text);
    final nextTemplateData = currentNoteTemplateData();
    if (note == null) {
      return (nextTitle.isNotEmpty && nextTitle != '未命名筆記') ||
          nextBody.trim().isNotEmpty ||
          nextFolder.isNotEmpty ||
          nextTags.isNotEmpty ||
          templateType != NoteTemplateType.general ||
          jsonEncode(nextTemplateData) !=
              jsonEncode(defaultNoteTemplateData(templateType)) ||
          jsonEncode(noteStyle) != jsonEncode(defaultNoteStyle()) ||
          noteImages.isNotEmpty ||
          noteAttachments.isNotEmpty ||
          jsonEncode(noteBackground) != jsonEncode(defaultNoteBackground());
    }
    return nextTitle != note.title ||
        nextBody != initialEditorBody ||
        nextFolder != note.category ||
        !stringListsEqual(nextTags, note.tags) ||
        templateType != note.templateType ||
        jsonEncode(nextTemplateData) != jsonEncode(initialEditorTemplateData) ||
        jsonEncode(noteStyle) != jsonEncode(note.style) ||
        jsonEncode(noteImages) != jsonEncode(note.images) ||
        jsonEncode(noteAttachments) != jsonEncode(note.attachments) ||
        jsonEncode(noteBackground) != jsonEncode(note.background);
  }

  Map<String, dynamic> currentNoteTemplateData() {
    if (templateType == NoteTemplateType.general) {
      return generalNoteTemplateData(
        templateData,
        body,
        noteImages,
        noteAttachments,
      );
    }
    return templateData;
  }

  void saveNote() {
    if (readOnly) {
      return;
    }
    if (didSave) {
      return;
    }
    if (!hasChanges) {
      didSave = true;
      return;
    }
    final store = AppStoreScope.of(context);
    final now = DateTime.now();
    final note = widget.note;
    final nextBody = body.text;
    final nextTemplateData = currentNoteTemplateData();
    store.upsertNote(
      NoteItem(
        id: note?.id ?? store.newId('n'),
        title: title.text.trim().isEmpty ? '未命名筆記' : title.text.trim(),
        body: nextBody,
        category: folder.trim(),
        tags: splitTags(tags.text),
        createdAt: note?.createdAt ?? now,
        updatedAt: now,
        isPinned: note?.isPinned ?? false,
        templateType: templateType,
        templateData: nextTemplateData,
        style: noteStyle,
        images: noteImages,
        attachments: noteAttachments,
        background: noteBackground,
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    if (readOnly) {
      Navigator.pop(context);
      return;
    }
    saveNote();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (readOnly) {
      Navigator.pop(context);
      return;
    }
    saveAndExit();
  }

  Future<void> deleteAndExit() async {
    final note = widget.note;
    if (note == null) {
      final confirmed = await confirmDelete(
        context,
        title: '刪除筆記？',
        message: '確定要放棄這份尚未儲存的筆記嗎？',
      );
      if (confirmed && mounted) {
        discardAndExit();
      }
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除筆記？',
      message: '確定要刪除這筆筆記嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    AppStoreScope.of(context).deleteNote(note);
    didSave = true;
    allowPop = true;
    Navigator.pop(context);
  }

  Future<void> createFolder() async {
    final store = AppStoreScope.of(context);
    final name = await promptForText(context, title: '新增資料夾', label: '資料夾名稱');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final newFolder = joinFolderPath(folder, name);
    store.createNoteFolder(newFolder);
    setState(() => folder = newFolder);
  }

  void setTemplateType(NoteTemplateType value) {
    setState(() {
      templateType = value;
      templateData = defaultNoteTemplateData(value);
    });
  }

  void migrateLegacyInlineAssets() {
    for (final image in noteImages) {
      final id = readString(image['id']);
      if (id.isNotEmpty &&
          !body.hasEmbedBlock(type: richNoteEmbedTypeImage, id: id)) {
        body.appendEmbedBlock(type: richNoteEmbedTypeImage, id: id);
      }
    }
    for (final attachment in noteAttachments) {
      final id = readString(attachment['id']);
      if (id.isNotEmpty &&
          !body.hasEmbedBlock(type: richNoteEmbedTypeAttachment, id: id)) {
        body.appendEmbedBlock(type: richNoteEmbedTypeAttachment, id: id);
      }
    }
  }

  Future<void> hydrateInlineImageDimensions() async {
    var changed = false;
    final nextImages = <Map<String, dynamic>>[];
    for (final image in noteImages) {
      final naturalWidth = readDouble(image['naturalWidth']);
      final naturalHeight = readDouble(image['naturalHeight']);
      if (naturalWidth > 0 && naturalHeight > 0) {
        nextImages.add(image);
        continue;
      }
      final bytes = decodeBase64BytesOrNull(readString(image['bytesBase64']));
      final dimensions = bytes == null
          ? null
          : await decodeImageDimensions(bytes);
      if (dimensions == null) {
        nextImages.add(image);
        continue;
      }
      nextImages.add({
        ...image,
        'naturalWidth': dimensions.width,
        'naturalHeight': dimensions.height,
      });
      changed = true;
    }
    if (changed && mounted) {
      setState(() => noteImages = nextImages);
    }
  }

  void insertBodyToken(String token) {
    final selection = body.selection;
    final text = body.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    body.text = text.replaceRange(start, end, token);
    body.selection = TextSelection.collapsed(offset: start + token.length);
    setState(() {});
  }

  Future<void> addImagePlaceholder() async {
    final file = await NoteFileService.pickImage();
    if (!mounted || file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '無法讀取圖片');
      return;
    }
    final dimensions = await decodeImageDimensions(bytes);
    final naturalWidth = math.max(1.0, dimensions?.width ?? 240.0);
    final naturalHeight = math.max(1.0, dimensions?.height ?? 160.0);
    final initialWidth = math
        .min(280.0, naturalWidth)
        .clamp(80.0, 320.0)
        .toDouble();
    final initialHeight = (initialWidth * naturalHeight / naturalWidth)
        .clamp(60.0, 320.0)
        .toDouble();
    final image = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': file.name,
      'bytesBase64': base64Encode(bytes),
      'size': file.size,
      'alignment': NoteImageAlignment.left.name,
      'x': 0.0,
      'y': 0.0,
      'locked': false,
      'width': initialWidth,
      'height': initialHeight,
      'naturalWidth': naturalWidth,
      'naturalHeight': naturalHeight,
      'crop': '',
      'path': file.path ?? '',
      'row': body.text.split('\n').length,
    };
    final nextImages = [...noteImages, image];
    body.insertEmbedBlock(
      type: richNoteEmbedTypeImage,
      id: readString(image['id']),
    );
    body.isolateEmbedBlocks(images: nextImages);
    setState(() => noteImages = nextImages);
  }

  Future<void> addAttachmentPlaceholder() async {
    final file = await NoteFileService.pickAttachment();
    if (!mounted || file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '無法讀取附件');
      return;
    }
    final attachment = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': file.name,
      'mode': 'file',
      'bytesBase64': base64Encode(bytes),
      'size': file.size,
      'content': '',
      'path': file.path ?? '',
    };
    body.insertEmbedBlock(
      type: richNoteEmbedTypeAttachment,
      id: readString(attachment['id']),
    );
    setState(() => noteAttachments.add(attachment));
  }

  Future<void> editBackground() async {
    final color = TextEditingController(
      text: readString(noteBackground['color'], fallback: '#FFFFFF'),
    );
    final image = TextEditingController(
      text: readString(noteBackground['image']),
    );
    var mode = readEnum(
      NoteBackgroundMode.values,
      noteBackground['mode'],
      NoteBackgroundMode.fill,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('背景設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: color,
                decoration: const InputDecoration(labelText: '背景顏色'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: image,
                decoration: const InputDecoration(labelText: '背景圖片'),
              ),
              const SizedBox(height: 12),
              DropdownMenu<NoteBackgroundMode>(
                initialSelection: mode,
                label: const Text('背景模式'),
                dropdownMenuEntries: NoteBackgroundMode.values
                    .map(
                      (item) => DropdownMenuEntry(
                        value: item,
                        label: noteBackgroundModeLabel(item),
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  if (value != null) {
                    setModalState(() => mode = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  noteBackground = {
                    'color': color.text.trim().isEmpty
                        ? '#FFFFFF'
                        : color.text.trim(),
                    'image': image.text.trim(),
                    'mode': mode.name,
                  };
                });
                Navigator.pop(context);
              },
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
    color.dispose();
    image.dispose();
  }

  Future<void> showExportOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: const [
            ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('另存為 PDF'),
              subtitle: Text('另存為 PDF'),
            ),
            ListTile(
              leading: Icon(Icons.text_snippet_outlined),
              title: Text('另存為 TXT'),
              subtitle: Text('另存為 txt'),
            ),
            ListTile(
              leading: Icon(Icons.code_outlined),
              title: Text('另存為 Markdown'),
              subtitle: Text('另存為 Markdown'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> insertTodoReference() async {
    final store = AppStoreScope.of(context);
    if (store.todos.isEmpty) {
      body.insertTodoCheckbox();
      return;
    }
    final todo = await showDialog<TodoItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('插入待辦事項'),
        children: [
          for (final item in store.todos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(item.title),
            ),
        ],
      ),
    );
    if (todo != null) {
      body.insertTodoCheckbox(todo.title);
    }
  }

  Future<void> insertNoteReference() async {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes.where(
      (item) => item.id != widget.note?.id,
    );
    final note = await showDialog<NoteItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('插入筆記連結'),
        children: [
          for (final item in notes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(item.title),
            ),
        ],
      ),
    );
    if (note != null) {
      insertBodyToken('[筆記:${note.title}]');
    }
  }

  void handleEditorMenu(NoteEditorMenuAction action) {
    switch (action) {
      case NoteEditorMenuAction.background:
        unawaited(editBackground());
        return;
      case NoteEditorMenuAction.insertNote:
        unawaited(insertNoteReference());
        return;
      case NoteEditorMenuAction.export:
        unawaited(showExportOptions());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: readOnly || allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: title.text.trim().isEmpty ? '未命名筆記' : title.text.trim(),
            titleWidget: NoteEditorHeaderFields(
              title: title,
              tags: tags,
              readOnly: readOnly,
              onChanged: () => setState(() {}),
            ),
            leading: PageBackButton(onPressed: requestExit),
            actions: [
              if (!readOnly)
                IconButton(
                  tooltip: '刪除筆記',
                  onPressed: deleteAndExit,
                  icon: const Icon(Icons.delete_outline),
                ),
              PopupMenuButton<NoteEditorMenuAction>(
                tooltip: '更多',
                icon: const Icon(Icons.more_vert),
                onSelected: handleEditorMenu,
                itemBuilder: (context) => [
                  if (!readOnly)
                    const PopupMenuItem(
                      value: NoteEditorMenuAction.background,
                      child: ListTile(
                        leading: Icon(Icons.format_color_fill_outlined),
                        title: Text('背景設定'),
                      ),
                    ),
                  if (!readOnly)
                    const PopupMenuItem(
                      value: NoteEditorMenuAction.insertNote,
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('插入筆記'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: NoteEditorMenuAction.export,
                    child: ListTile(
                      leading: Icon(Icons.save_alt_outlined),
                      title: Text('另存為'),
                    ),
                  ),
                ],
              ),
            ],
            child: templateType == NoteTemplateType.general
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: GeneralRichTextEditorPanel(
                      controller: body,
                      readOnly: readOnly,
                      style: noteStyle,
                      images: noteImages,
                      attachments: noteAttachments,
                      background: noteBackground,
                      onStyleChanged: (value) =>
                          setState(() => noteStyle = value),
                      onAddImage: addImagePlaceholder,
                      onAddAttachment: addAttachmentPlaceholder,
                      onInsertTodo: insertTodoReference,
                      onImagesChanged: (value) =>
                          setState(() => noteImages = value),
                      onAttachmentsChanged: (value) =>
                          setState(() => noteAttachments = value),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      IgnorePointer(
                        ignoring: readOnly,
                        child: NoteTemplateFields(
                          type: templateType,
                          data: templateData,
                          onChanged: (value) =>
                              setState(() => templateData = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!readOnly) ...[
                        NoteEditorToolbar(
                          style: noteStyle,
                          imageCount: noteImages.length,
                          attachmentCount: noteAttachments.length,
                          onStyleChanged: (value) =>
                              setState(() => noteStyle = value),
                          onAddImage: addImagePlaceholder,
                          onAddAttachment: addAttachmentPlaceholder,
                          onInsertTodo: insertTodoReference,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: body,
                        readOnly: readOnly,
                        minLines: 5,
                        maxLines: 10,
                        style: noteBodyTextStyle(noteStyle, context: context),
                        decoration: InputDecoration(
                          labelText: noteBodyLabel(templateType),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: effectiveNoteBackgroundColor(
                            context,
                            noteBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xffdfe5f4),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xffdfe5f4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      NoteAssetsSummary(
                        images: noteImages,
                        attachments: noteAttachments,
                        background: noteBackground,
                        readOnly: readOnly,
                        onImagesChanged: (value) =>
                            setState(() => noteImages = value),
                        onAttachmentsChanged: (value) =>
                            setState(() => noteAttachments = value),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class NoteTemplateSelector extends StatelessWidget {
  const NoteTemplateSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NoteTemplateType value;
  final ValueChanged<NoteTemplateType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NoteTemplateType>(
      segments: [
        for (final type in NoteTemplateType.values)
          ButtonSegment(
            value: type,
            icon: Icon(noteTemplateIcon(type)),
            label: Text(noteTemplateLabel(type)),
          ),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class NoteTemplateBadge extends StatelessWidget {
  const NoteTemplateBadge({super.key, required this.type});

  final NoteTemplateType type;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        children: [
          Icon(noteTemplateIcon(type)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noteTemplateLabel(type),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  noteTemplateDescription(type),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoteEditorHeaderFields extends StatelessWidget {
  const NoteEditorHeaderFields({
    super.key,
    required this.title,
    required this.tags,
    required this.readOnly,
    required this.onChanged,
  });

  final TextEditingController title;
  final TextEditingController tags;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: title,
          readOnly: readOnly,
          onChanged: (_) => onChanged(),
          minLines: 1,
          maxLines: 2,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xff171f2f),
          ),
          decoration: const InputDecoration(
            hintText: '未命名筆記',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: tags,
          readOnly: readOnly,
          onChanged: (_) => onChanged(),
          minLines: 1,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          decoration: const InputDecoration(
            hintText: '#標籤',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

const richTextFormatVersion = 'my_note.rich_text.v1';
const appFlowyMirrorFormatVersion = 'my_note.appflowy.v1';
const richNoteEmbedObject = '\uFFFC';
const richNoteEmbedTypeImage = 'image';
const richNoteEmbedTypeAttachment = 'attachment';

class RichNoteAttribute {
  const RichNoteAttribute._();

  static const bold = 'bold';
  static const italic = 'italic';
  static const underline = 'underline';
  static const strikethrough = 'strikethrough';
  static const inlineCode = 'inlineCode';
  static const codeBlock = 'codeBlock';
  static const subscript = 'subscript';
  static const superscript = 'superscript';
  static const heading = 'heading';
  static const quote = 'quote';
  static const embedType = 'embedType';
  static const embedId = 'embedId';
}

class RichNoteMark {
  const RichNoteMark({
    required this.start,
    required this.end,
    required this.attributes,
  });

  final int start;
  final int end;
  final Map<String, dynamic> attributes;

  bool get isValid => end > start && attributes.isNotEmpty;

  RichNoteMark copyWith({
    int? start,
    int? end,
    Map<String, dynamic>? attributes,
  }) {
    return RichNoteMark(
      start: start ?? this.start,
      end: end ?? this.end,
      attributes: attributes ?? Map<String, dynamic>.from(this.attributes),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'attributes': attributes,
  };

  static RichNoteMark? fromJson(Map<String, dynamic> data, int textLength) {
    final start = readInt(data['start']).clamp(0, textLength).toInt();
    final end = readInt(data['end']).clamp(0, textLength).toInt();
    final attributes = readStringMap(data['attributes']);
    final mark = RichNoteMark(
      start: math.min(start, end),
      end: math.max(start, end),
      attributes: attributes,
    );
    return mark.isValid ? mark : null;
  }
}

class RichNoteEditingSnapshot {
  const RichNoteEditingSnapshot(this.value, this.marks);

  final TextEditingValue value;
  final List<RichNoteMark> marks;
}

class RichNoteTextChange {
  const RichNoteTextChange({
    required this.oldStart,
    required this.oldEnd,
    required this.replacementLength,
    required this.textLength,
  });

  final int oldStart;
  final int oldEnd;
  final int replacementLength;
  final int textLength;

  int get replacementEnd => oldStart + replacementLength;
}

class RichNoteAutoEdit {
  const RichNoteAutoEdit({
    required this.start,
    required this.end,
    required this.replacement,
    required this.cursorOffset,
  });

  final int start;
  final int end;
  final String replacement;
  final int cursorOffset;
}

class RichNoteSeed {
  const RichNoteSeed({required this.text, required this.marks});

  final String text;
  final List<RichNoteMark> marks;
}

class RichNoteTextController extends TextEditingController {
  RichNoteTextController({
    required String text,
    required List<RichNoteMark> marks,
  }) : _marks = normalizeRichNoteMarks(marks, text.length),
       _lastText = text,
       _lastValue = TextEditingValue(
         text: text,
         selection: TextSelection.collapsed(offset: text.length),
       ),
       _lastMarks = normalizeRichNoteMarks(marks, text.length),
       super(text: text) {
    addListener(_handleUserTextChange);
  }

  List<RichNoteMark> _marks;
  String _lastText;
  TextEditingValue _lastValue;
  List<RichNoteMark> _lastMarks;
  final Map<String, Object?> _typingAttributeOverrides = {};
  bool _applyingChange = false;
  final List<RichNoteEditingSnapshot> _undoStack = [];
  final List<RichNoteEditingSnapshot> _redoStack = [];
  TextSelection? _lastValidSelection;
  List<Map<String, dynamic>> _renderImages = const [];
  List<Map<String, dynamic>> _renderAttachments = const [];
  bool _renderReadOnly = false;
  String? _selectedEmbedType;
  String? _selectedEmbedId;
  void Function(String type, String id)? _onEmbedSelected;
  void Function(String type, String id)? _onEmbedBlockTapped;
  ValueChanged<RichImageTapTarget>? _onImageLayoutChanged;
  ValueChanged<Map<String, dynamic>>? _onInlineImageChanged;
  ValueChanged<Map<String, dynamic>>? _onInlineAttachmentChanged;
  void Function(String type, String id)? _onEmbedDeleted;
  double? _renderContentWidth;
  DateTime? _suppressSelectionLogUntil;

  bool get canUndoRichChange => _undoStack.isNotEmpty;
  bool get canRedoRichChange => _redoStack.isNotEmpty;

  List<RichNoteMark> get marks =>
      _marks.map((mark) => mark.copyWith()).toList();

  Map<String, dynamic> toRichTextJson() => {
    'format': richTextFormatVersion,
    'plainText': text,
    'spans': _marks.map((mark) => mark.toJson()).toList(),
  };

  void configureInlineContent({
    required List<Map<String, dynamic>> images,
    required List<Map<String, dynamic>> attachments,
    required bool readOnly,
    required String? selectedType,
    required String? selectedId,
    required void Function(String type, String id) onEmbedSelected,
    required void Function(String type, String id) onEmbedBlockTapped,
    required ValueChanged<RichImageTapTarget> onImageLayoutChanged,
    required ValueChanged<Map<String, dynamic>> onImageChanged,
    required ValueChanged<Map<String, dynamic>> onAttachmentChanged,
    required void Function(String type, String id) onEmbedDeleted,
    double? contentWidth,
  }) {
    _renderImages = images;
    _renderAttachments = attachments;
    _renderReadOnly = readOnly;
    _selectedEmbedType = selectedType;
    _selectedEmbedId = selectedId;
    _onEmbedSelected = onEmbedSelected;
    _onEmbedBlockTapped = onEmbedBlockTapped;
    _onImageLayoutChanged = onImageLayoutChanged;
    _onInlineImageChanged = onImageChanged;
    _onInlineAttachmentChanged = onAttachmentChanged;
    _onEmbedDeleted = onEmbedDeleted;
    _renderContentWidth = contentWidth;
  }

  void insertEmbedBlock({required String type, required String id}) {
    final range = normalizedSelectionRange();
    final currentText = text;
    final needsLeadingNewLine =
        range.start > 0 && currentText[range.start - 1] != '\n';
    final needsTrailingNewLine =
        range.end < currentText.length && currentText[range.end] != '\n';
    final leading = needsLeadingNewLine ? '\n' : '';
    final trailing = needsTrailingNewLine || range.end == currentText.length
        ? '\n'
        : '';
    final replacement = '$leading$richNoteEmbedObject$trailing';
    final embedStart = range.start + leading.length;
    _pushCurrentUndo();
    _applyingChange = true;
    final nextText = currentText.replaceRange(
      range.start,
      range.end,
      replacement,
    );
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: range.start,
      oldEnd: range.end,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    _marks.add(
      RichNoteMark(
        start: embedStart,
        end: embedStart + 1,
        attributes: {
          RichNoteAttribute.embedType: type,
          RichNoteAttribute.embedId: id,
        },
      ),
    );
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: (embedStart + 1 + trailing.length)
            .clamp(0, nextText.length)
            .toInt(),
      ),
    );
    _rememberSelection();
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void appendEmbedBlock({required String type, required String id}) {
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    insertEmbedBlock(type: type, id: id);
  }

  bool hasEmbedBlock({required String type, required String id}) {
    return _marks.any(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
  }

  void removeEmbedBlock({required String type, required String id}) {
    final index = _marks.indexWhere(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
    if (index < 0) {
      return;
    }
    final mark = _marks[index];
    replaceTextRange(mark.start, mark.end, '');
  }

  bool moveEmbedBlock({
    required String type,
    required String id,
    required int direction,
  }) {
    final index = _marks.indexWhere(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
    if (index < 0 || direction == 0) {
      return false;
    }
    final mark = _marks[index];
    final currentText = text;
    var insertAt = mark.start;
    if (direction < 0) {
      var before = mark.start;
      while (before > 0 && currentText[before - 1] == '\n') {
        before--;
      }
      if (before <= 0) {
        return false;
      }
      insertAt = currentText.lastIndexOf('\n', before - 1) + 1;
    } else {
      var after = mark.end;
      while (after < currentText.length && currentText[after] == '\n') {
        after++;
      }
      if (after >= currentText.length) {
        return false;
      }
      final nextBreak = currentText.indexOf('\n', after);
      insertAt = nextBreak < 0 ? currentText.length : nextBreak + 1;
    }
    if (insertAt == mark.start) {
      return false;
    }
    replaceTextRange(mark.start, mark.end, '');
    final adjustedInsertAt = insertAt > mark.start
        ? insertAt - (mark.end - mark.start)
        : insertAt;
    value = value.copyWith(
      selection: TextSelection.collapsed(
        offset: adjustedInsertAt.clamp(0, text.length).toInt(),
      ),
    );
    insertEmbedBlock(type: type, id: id);
    return true;
  }

  void clearTextSelectionForImageInteraction() {
    suppressSelectionChangeLogForImageInteraction();
    _applyingChange = true;
    final nextValue = value.copyWith(
      selection: const TextSelection.collapsed(offset: -1),
      composing: TextRange.empty,
    );
    value = nextValue;
    _lastValue = nextValue;
    _applyingChange = false;
  }

  void suppressSelectionChangeLogForImageInteraction([
    Duration duration = const Duration(milliseconds: 500),
  ]) {
    _suppressSelectionLogUntil = DateTime.now().add(duration);
  }

  bool get _shouldSuppressSelectionChangeLog {
    final until = _suppressSelectionLogUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _handleUserTextChange() {
    final selectionChanged = value.selection != _lastValue.selection;
    _rememberSelection();
    if (_applyingChange || text == _lastText) {
      if (!_applyingChange && text == _lastText && selectionChanged) {
        if (_shouldSuppressSelectionChangeLog) {
          _lastValue = value;
          return;
        }
        debugPrint(
          'CARET_CHANGED selection=${value.selection.start}-${value.selection.end}',
        );
        _lastValue = value;
      }
      return;
    }
    final previousEmbeds = embedKeysFromRichNoteMarks(_lastMarks);
    final change = richNoteTextChange(oldText: _lastText, newText: text);
    _pushUndo(_lastValue, _lastMarks);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: change.oldStart,
      oldEnd: change.oldEnd,
      replacementLength: change.replacementLength,
      textLength: change.textLength,
    );
    if (change.replacementLength > 0 && _typingAttributeOverrides.isNotEmpty) {
      final insertedRange = TextRange(
        start: change.oldStart,
        end: change.replacementEnd,
      );
      for (final entry in _typingAttributeOverrides.entries) {
        if (entry.value == false) {
          _marks = removeRichNoteAttribute(
            _marks,
            insertedRange,
            entry.key,
            text.length,
          );
        }
      }
      final enabledAttributes = <String, dynamic>{
        for (final entry in _typingAttributeOverrides.entries)
          if (entry.value != false) entry.key: entry.value,
      };
      if (enabledAttributes.isNotEmpty) {
        _marks.add(
          RichNoteMark(
            start: insertedRange.start,
            end: insertedRange.end,
            attributes: enabledAttributes,
          ),
        );
      }
      _marks = normalizeRichNoteMarks(_marks, text.length);
    }
    if (text.isEmpty && change.replacementLength == 0) {
      _marks = [];
      _typingAttributeOverrides.clear();
    }
    final autoEdit = richListContinuationEdit(text, change);
    if (autoEdit != null) {
      _applyInternalReplacement(autoEdit);
    }
    _isolateEmbedBlocks();
    _notifyDeletedEmbeds(previousEmbeds);
    _syncLastSnapshot();
  }

  void _notifyDeletedEmbeds(Set<String> previousEmbeds) {
    if (previousEmbeds.isEmpty || _onEmbedDeleted == null) {
      return;
    }
    final currentEmbeds = embedKeysFromRichNoteMarks(_marks);
    for (final key in previousEmbeds.difference(currentEmbeds)) {
      final separator = key.indexOf('\n');
      if (separator <= 0 || separator >= key.length - 1) {
        continue;
      }
      _onEmbedDeleted?.call(
        key.substring(0, separator),
        key.substring(separator + 1),
      );
    }
  }

  void _syncLastSnapshot() {
    _lastText = text;
    _lastValue = value;
    _lastMarks = marks;
    _rememberSelection();
  }

  void _rememberSelection() {
    final currentSelection = selection;
    if (currentSelection.isValid) {
      _lastValidSelection = currentSelection;
    }
  }

  void rememberSelection() {
    _rememberSelection();
  }

  void _pushUndo(
    TextEditingValue value,
    List<RichNoteMark> marks, {
    bool clearRedo = true,
  }) {
    _undoStack.add(
      RichNoteEditingSnapshot(
        value,
        marks.map((mark) => mark.copyWith()).toList(),
      ),
    );
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    if (clearRedo) {
      _redoStack.clear();
    }
  }

  void _pushRedo(TextEditingValue value, List<RichNoteMark> marks) {
    _redoStack.add(
      RichNoteEditingSnapshot(
        value,
        marks.map((mark) => mark.copyWith()).toList(),
      ),
    );
    if (_redoStack.length > 50) {
      _redoStack.removeAt(0);
    }
  }

  void _pushCurrentUndo() {
    _pushUndo(value, marks);
  }

  TextRange normalizedSelectionRange() {
    final currentText = text;
    var selection = this.selection;
    if (!selection.isValid && _lastValidSelection != null) {
      selection = _lastValidSelection!;
    }
    if (!selection.isValid) {
      return TextRange.collapsed(currentText.length);
    }
    final start = math
        .min(selection.start, selection.end)
        .clamp(0, currentText.length)
        .toInt();
    final end = math
        .max(selection.start, selection.end)
        .clamp(0, currentText.length)
        .toInt();
    return TextRange(start: start, end: end);
  }

  TextRange currentLineRange() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    return TextRange(start: lineStart, end: lineEnd);
  }

  void replaceSelection(
    String replacement, {
    Map<String, dynamic>? attributes,
  }) {
    final range = normalizedSelectionRange();
    _pushCurrentUndo();
    _applyingChange = true;
    final nextText = text.replaceRange(range.start, range.end, replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: range.start,
      oldEnd: range.end,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    if (attributes != null && attributes.isNotEmpty && replacement.isNotEmpty) {
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.start + replacement.length,
          attributes: Map<String, dynamic>.from(attributes),
        ),
      );
    }
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: range.start + replacement.length,
      ),
    );
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void _applyInternalReplacement(RichNoteAutoEdit edit) {
    _applyingChange = true;
    final nextText = text.replaceRange(edit.start, edit.end, edit.replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: edit.start,
      oldEnd: edit.end,
      replacementLength: edit.replacement.length,
      textLength: nextText.length,
    );
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: edit.cursorOffset.clamp(0, nextText.length).toInt(),
      ),
    );
    _applyingChange = false;
  }

  void isolateEmbedBlocks({List<Map<String, dynamic>> images = const []}) {
    _isolateEmbedBlocks(images: images);
    _syncLastSnapshot();
  }

  void _isolateEmbedBlocks({List<Map<String, dynamic>> images = const []}) {
    var guard = 0;
    while (guard < text.length + 8) {
      guard++;
      final currentText = text;
      var applied = false;
      for (var index = 0; index < currentText.length; index++) {
        if (currentText[index] != richNoteEmbedObject) {
          continue;
        }
        if (index > 0 && currentText[index - 1] != '\n') {
          _insertInternalLineBreak(index);
          applied = true;
          break;
        }
        final after = index + 1;
        const requiredNewlines = 1;
        var existingNewlines = 0;
        while (after + existingNewlines < currentText.length &&
            currentText[after + existingNewlines] == '\n') {
          existingNewlines++;
        }
        if (existingNewlines < requiredNewlines) {
          _insertInternalText(
            after + existingNewlines,
            '\n' * (requiredNewlines - existingNewlines),
          );
          applied = true;
          break;
        }
      }
      if (!applied) {
        return;
      }
    }
  }

  void _insertInternalLineBreak(int offset) {
    _insertInternalText(offset, '\n');
  }

  void _insertInternalText(int offset, String replacement) {
    final currentSelection = selection;
    final selectionOffset = currentSelection.isValid
        ? currentSelection.extentOffset
        : text.length;
    final nextCursor =
        selectionOffset + (offset <= selectionOffset ? replacement.length : 0);
    _applyInternalReplacement(
      RichNoteAutoEdit(
        start: offset,
        end: offset,
        replacement: replacement,
        cursorOffset: nextCursor,
      ),
    );
  }

  void applyInlineAttribute(String attribute, Object value) {
    var range = normalizedSelectionRange();
    if (range.isCollapsed) {
      toggleTypingAttribute(attribute, value);
      return;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    if (selectionHasAttribute(attribute, value: value)) {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
    } else {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
      final opposite = oppositeScriptAttribute(attribute);
      if (opposite != null) {
        _marks = removeRichNoteAttribute(_marks, range, opposite, text.length);
      }
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.end,
          attributes: {attribute: value},
        ),
      );
      _marks = normalizeRichNoteMarks(_marks, text.length);
    }
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void applyLineAttribute(String attribute, Object value) {
    final selectionRange = normalizedSelectionRange();
    if (selectionRange.isCollapsed) {
      toggleTypingAttribute(attribute, value);
      return;
    }
    var range = currentLineRange();
    _pushCurrentUndo();
    _applyingChange = true;
    if (rangeHasAttribute(range, attribute, value: value)) {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
    } else {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.end,
          attributes: {attribute: value},
        ),
      );
      _marks = normalizeRichNoteMarks(_marks, text.length);
    }
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void toggleTypingAttribute(String attribute, Object value) {
    final currentOverride = _typingAttributeOverrides[attribute];
    if (currentOverride == value) {
      _typingAttributeOverrides.remove(attribute);
    } else if (currentOverride == false) {
      _typingAttributeOverrides[attribute] = value;
    } else if (selectionHasExistingAttribute(attribute, value: value)) {
      _typingAttributeOverrides[attribute] = false;
    } else {
      _typingAttributeOverrides[attribute] = value;
    }
    final opposite = oppositeScriptAttribute(attribute);
    if (opposite != null && _typingAttributeOverrides[attribute] == value) {
      _typingAttributeOverrides[opposite] = false;
      final range = normalizedSelectionRange();
      if (!range.isCollapsed) {
        _marks = removeRichNoteAttribute(_marks, range, opposite, text.length);
      }
    }
    notifyListeners();
  }

  void insertTodoCheckbox([String label = '']) {
    final textBefore = text;
    final range = normalizedSelectionRange();
    final needsNewLine = range.start > 0 && textBefore[range.start - 1] != '\n';
    final replacement = '${needsNewLine ? '\n' : ''}☐ ${label.trim()}';
    replaceSelection(replacement);
  }

  bool toggleTodoCheckboxAtOffset(int markerIndex) {
    final currentText = text;
    if (markerIndex < 0 || markerIndex >= currentText.length) {
      return false;
    }
    final marker = currentText[markerIndex];
    if (marker != '☐' && marker != '☑') {
      return false;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    final replacement = marker == '☐' ? '☑' : '☐';
    final nextText = currentText.replaceRange(
      markerIndex,
      markerIndex + 1,
      replacement,
    );
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: markerIndex + 1),
    );
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
    return true;
  }

  bool toggleTodoCheckboxAtSelection() {
    final currentText = text;
    final selection = this.selection;
    if (!selection.isValid || !selection.isCollapsed || currentText.isEmpty) {
      return false;
    }
    final position = selection.extentOffset
        .clamp(0, currentText.length)
        .toInt();
    final lineStart = position <= 0
        ? 0
        : currentText.lastIndexOf('\n', position - 1) + 1;
    final lineEndRaw = currentText.indexOf('\n', lineStart);
    final lineEnd = lineEndRaw == -1 ? currentText.length : lineEndRaw;
    var markerIndex = lineStart;
    while (markerIndex < lineEnd && currentText[markerIndex] == ' ') {
      markerIndex++;
    }
    if (markerIndex >= lineEnd) {
      return false;
    }
    final marker = currentText[markerIndex];
    if (marker != '☐' && marker != '☑') {
      return false;
    }
    final prefixEnd = math.min(markerIndex + 2, lineEnd);
    if (position > prefixEnd) {
      return false;
    }
    return toggleTodoCheckboxAtOffset(markerIndex);
  }

  void prefixSelectedLines(String prefix) {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final block = currentText.substring(lineStart, lineEnd);
    final replacement = block
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  void replaceTextRange(int start, int end, String replacement) {
    _pushCurrentUndo();
    _applyingChange = true;
    final nextText = text.replaceRange(start, end, replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: start,
      oldEnd: end,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void outdentSelectedLines() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final replacement = currentText
        .substring(lineStart, lineEnd)
        .split('\n')
        .map((line) {
          if (line.startsWith('  ')) return line.substring(2);
          if (line.startsWith('\t')) return line.substring(1);
          return line;
        })
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  void applyOrderedList() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final replacement = currentText
        .substring(lineStart, lineEnd)
        .split('\n')
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  bool selectionHasAttribute(String attribute, {Object? value}) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      if (_typingAttributeOverrides.containsKey(attribute)) {
        final override = _typingAttributeOverrides[attribute];
        return override != false && (value == null || override == value);
      }
      return selectionHasExistingAttribute(attribute, value: value);
    }
    return rangeHasAttribute(range, attribute, value: value);
  }

  bool selectionHasExistingAttribute(String attribute, {Object? value}) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      final position = range.start.clamp(0, text.length).toInt();
      return _marks.any((mark) {
        final covers = position == text.length
            ? mark.start < position && mark.end >= position
            : mark.start <= position && mark.end > position;
        return covers &&
            mark.attributes.containsKey(attribute) &&
            (value == null || mark.attributes[attribute] == value);
      });
    }
    return rangeHasAttribute(range, attribute, value: value);
  }

  bool rangeHasAttribute(TextRange range, String attribute, {Object? value}) {
    for (var index = range.start; index < range.end; index++) {
      if (text[index] == '\n') {
        continue;
      }
      final covered = _marks.any(
        (mark) =>
            mark.start <= index &&
            mark.end > index &&
            mark.attributes.containsKey(attribute) &&
            (value == null || mark.attributes[attribute] == value),
      );
      if (!covered) {
        return false;
      }
    }
    return true;
  }

  void undoRichChange() {
    if (_undoStack.isEmpty) {
      return;
    }
    _applyingChange = true;
    _pushRedo(value, marks);
    final previous = _undoStack.removeLast();
    _marks = previous.marks.map((mark) => mark.copyWith()).toList();
    value = previous.value;
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void redoRichChange() {
    if (_redoStack.isEmpty) {
      return;
    }
    _applyingChange = true;
    _pushUndo(value, marks, clearRedo: false);
    final next = _redoStack.removeLast();
    _marks = next.marks.map((mark) => mark.copyWith()).toList();
    value = next.value;
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    bool isTodoMarkerAt(int index) {
      if (index < 0 || index >= currentText.length) {
        return false;
      }
      final marker = currentText[index];
      if (marker != '☐' && marker != '☑') {
        return false;
      }
      final lineStart = index <= 0
          ? 0
          : currentText.lastIndexOf('\n', index - 1) + 1;
      for (var i = lineStart; i < index; i++) {
        if (currentText[i] != ' ') {
          return false;
        }
      }
      return true;
    }

    final boundaries = <int>{0, currentText.length};
    for (final mark in _marks) {
      boundaries.add(mark.start.clamp(0, currentText.length).toInt());
      boundaries.add(mark.end.clamp(0, currentText.length).toInt());
    }
    for (var index = 0; index < currentText.length; index++) {
      if (currentText[index] == richNoteEmbedObject || isTodoMarkerAt(index)) {
        boundaries.add(index);
        boundaries.add(index + 1);
      }
    }
    final ordered = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var i = 0; i < ordered.length - 1; i++) {
      final start = ordered[i];
      final end = ordered[i + 1];
      if (end <= start) {
        continue;
      }
      final attributes = <String, dynamic>{};
      for (final mark in _marks) {
        if (mark.start <= start && mark.end >= end) {
          attributes.addAll(mark.attributes);
        }
      }
      if (end == start + 1 && isTodoMarkerAt(start)) {
        final checked = currentText[start] == '☑';
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InlineRichTodoCheckbox(
              checked: checked,
              readOnly: _renderReadOnly,
              onChanged: () => toggleTodoCheckboxAtOffset(start),
            ),
          ),
        );
        continue;
      }
      if (end == start + 1 && currentText[start] == richNoteEmbedObject) {
        final type = readString(attributes[RichNoteAttribute.embedType]);
        final id = readString(attributes[RichNoteAttribute.embedId]);
        final selected = _selectedEmbedType == type && _selectedEmbedId == id;
        if (type == richNoteEmbedTypeImage) {
          final image = firstMapById(_renderImages, id);
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: InlineRichImageBlock(
                image: image,
                selected: selected,
                readOnly: _renderReadOnly,
                moveEnabled: false,
                contentWidth: _renderContentWidth,
                onSelect: () => _onEmbedSelected?.call(type, id),
                onBlockTap: () => _onEmbedBlockTapped?.call(type, id),
                onLayoutChanged: (target) =>
                    _onImageLayoutChanged?.call(target),
                onChanged: (value) => _onInlineImageChanged?.call(value),
              ),
            ),
          );
          continue;
        }
        if (type == richNoteEmbedTypeAttachment) {
          final attachment = firstMapById(_renderAttachments, id);
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InlineRichAttachmentBlock(
                attachment: attachment,
                selected: selected,
                readOnly: _renderReadOnly,
                onSelect: () => _onEmbedSelected?.call(type, id),
                onChanged: (value) => _onInlineAttachmentChanged?.call(value),
              ),
            ),
          );
          continue;
        }
      }
      children.add(
        TextSpan(
          text: currentText.substring(start, end),
          style: richNoteTextStyleForAttributes(context, baseStyle, attributes),
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

List<RichNoteMark> normalizeRichNoteMarks(
  List<RichNoteMark> marks,
  int textLength,
) {
  final normalized = <RichNoteMark>[];
  for (final mark in marks) {
    final start = mark.start.clamp(0, textLength).toInt();
    final end = mark.end.clamp(0, textLength).toInt();
    final next = RichNoteMark(
      start: math.min(start, end),
      end: math.max(start, end),
      attributes: Map<String, dynamic>.from(mark.attributes),
    );
    if (next.isValid) {
      normalized.add(next);
    }
  }
  normalized.sort((a, b) {
    final start = a.start.compareTo(b.start);
    if (start != 0) return start;
    return a.end.compareTo(b.end);
  });
  return normalized;
}

Set<String> embedKeysFromRichNoteMarks(List<RichNoteMark> marks) {
  final keys = <String>{};
  for (final mark in marks) {
    final type = readString(mark.attributes[RichNoteAttribute.embedType]);
    final id = readString(mark.attributes[RichNoteAttribute.embedId]);
    if (type.isNotEmpty && id.isNotEmpty) {
      keys.add('$type\n$id');
    }
  }
  return keys;
}

List<RichNoteMark> adjustRichNoteMarksAfterTextChange(
  List<RichNoteMark> marks, {
  required String oldText,
  required String newText,
}) {
  final change = richNoteTextChange(oldText: oldText, newText: newText);
  return adjustRichNoteMarksForReplacement(
    marks,
    oldStart: change.oldStart,
    oldEnd: change.oldEnd,
    replacementLength: change.replacementLength,
    textLength: change.textLength,
  );
}

RichNoteTextChange richNoteTextChange({
  required String oldText,
  required String newText,
}) {
  var prefix = 0;
  while (prefix < oldText.length &&
      prefix < newText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText.codeUnitAt(oldText.length - 1 - suffix) ==
          newText.codeUnitAt(newText.length - 1 - suffix)) {
    suffix++;
  }
  return RichNoteTextChange(
    oldStart: prefix,
    oldEnd: oldText.length - suffix,
    replacementLength: newText.length - prefix - suffix,
    textLength: newText.length,
  );
}

String? oppositeScriptAttribute(String attribute) {
  return switch (attribute) {
    RichNoteAttribute.subscript => RichNoteAttribute.superscript,
    RichNoteAttribute.superscript => RichNoteAttribute.subscript,
    _ => null,
  };
}

RichNoteAutoEdit? richListContinuationEdit(
  String currentText,
  RichNoteTextChange change,
) {
  if (change.replacementLength < 1 ||
      change.replacementEnd > currentText.length) {
    return null;
  }
  final inserted = currentText.substring(
    change.oldStart,
    change.replacementEnd,
  );
  if (!inserted.startsWith('\n')) {
    return null;
  }
  final lineStart = change.oldStart <= 0
      ? 0
      : currentText.lastIndexOf('\n', change.oldStart - 1) + 1;
  final previousLine = currentText.substring(lineStart, change.oldStart);
  final afterInsertedNewLine = change.oldStart + 1;

  final emptyNumbered = RegExp(r'^(\s*)\d+\.\s*$').firstMatch(previousLine);
  if (emptyNumbered != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final numbered = RegExp(r'^(\s*)(\d+)\.\s+(.+)$').firstMatch(previousLine);
  if (numbered != null) {
    final indent = numbered.group(1) ?? '';
    final nextNumber = (int.tryParse(numbered.group(2) ?? '') ?? 0) + 1;
    final prefix = '$indent$nextNumber. ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  final emptyBullet = RegExp(r'^(\s*)•\s*$').firstMatch(previousLine);
  if (emptyBullet != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final bullet = RegExp(r'^(\s*)•\s+(.+)$').firstMatch(previousLine);
  if (bullet != null) {
    final prefix = '${bullet.group(1) ?? ''}• ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  final emptyTodo = RegExp(r'^(\s*)[☐☑]\s*$').firstMatch(previousLine);
  if (emptyTodo != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final todo = RegExp(r'^(\s*)[☐☑]\s+(.+)$').firstMatch(previousLine);
  if (todo != null) {
    final prefix = '${todo.group(1) ?? ''}☐ ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  return null;
}

List<RichNoteMark> adjustRichNoteMarksForReplacement(
  List<RichNoteMark> marks, {
  required int oldStart,
  required int oldEnd,
  required int replacementLength,
  required int textLength,
}) {
  final delta = replacementLength - (oldEnd - oldStart);
  final changedNewEnd = oldStart + replacementLength;
  final next = <RichNoteMark>[];
  for (final mark in marks) {
    if (mark.end <= oldStart) {
      next.add(mark);
    } else if (mark.start >= oldEnd) {
      next.add(mark.copyWith(start: mark.start + delta, end: mark.end + delta));
    } else {
      final start = mark.start <= oldStart ? mark.start : changedNewEnd;
      final end = mark.end >= oldEnd ? mark.end + delta : oldStart;
      if (end > start) {
        next.add(mark.copyWith(start: start, end: end));
      }
    }
  }
  return normalizeRichNoteMarks(next, textLength);
}

List<RichNoteMark> removeRichNoteAttribute(
  List<RichNoteMark> marks,
  TextRange range,
  String attribute,
  int textLength,
) {
  final next = <RichNoteMark>[];
  for (final mark in marks) {
    if (mark.end <= range.start ||
        mark.start >= range.end ||
        !mark.attributes.containsKey(attribute)) {
      next.add(mark);
      continue;
    }
    if (mark.start < range.start) {
      next.add(mark.copyWith(end: range.start));
    }
    final middleAttributes = Map<String, dynamic>.from(mark.attributes)
      ..remove(attribute);
    if (middleAttributes.isNotEmpty) {
      next.add(
        RichNoteMark(
          start: math.max(mark.start, range.start),
          end: math.min(mark.end, range.end),
          attributes: middleAttributes,
        ),
      );
    }
    if (mark.end > range.end) {
      next.add(mark.copyWith(start: range.end));
    }
  }
  return normalizeRichNoteMarks(next, textLength);
}

RichNoteSeed richNoteSeedFromTemplateData(
  String body,
  Map<String, dynamic> templateData,
) {
  final richText = readStringMap(templateData['richText']);
  final storedPlainText = readString(richText['plainText']);
  final plainText = storedPlainText.isEmpty && body.trim().isNotEmpty
      ? body
      : storedPlainText;
  final spans = readMapList(richText['spans'])
      .map((item) => RichNoteMark.fromJson(item, plainText.length))
      .whereType<RichNoteMark>()
      .toList();
  if (spans.isNotEmpty || richText['format'] == richTextFormatVersion) {
    return RichNoteSeed(text: plainText, marks: spans);
  }
  return migrateLegacyRichTextMarkers(body);
}

RichNoteSeed migrateLegacyRichTextMarkers(String body) {
  var text = body;
  final marks = <RichNoteMark>[];

  void removeRange(int start, int length) {
    text = text.replaceRange(start, start + length, '');
    final shifted = adjustRichNoteMarksForReplacement(
      marks,
      oldStart: start,
      oldEnd: start + length,
      replacementLength: 0,
      textLength: text.length,
    );
    marks
      ..clear()
      ..addAll(shifted);
  }

  void consumePair(String open, String close, Map<String, dynamic> attributes) {
    var index = 0;
    while (index < text.length) {
      final start = text.indexOf(open, index);
      if (start < 0) break;
      final contentStart = start + open.length;
      final end = text.indexOf(close, contentStart);
      if (end < 0) break;
      removeRange(end, close.length);
      removeRange(start, open.length);
      final markEnd = end - open.length;
      if (markEnd > start) {
        marks.add(
          RichNoteMark(
            start: start,
            end: markEnd,
            attributes: Map<String, dynamic>.from(attributes),
          ),
        );
      }
      index = math.max(start + 1, markEnd);
    }
  }

  consumePair('```\n', '\n```', {RichNoteAttribute.codeBlock: true});
  consumePair('**', '**', {RichNoteAttribute.bold: true});
  consumePair('~~', '~~', {RichNoteAttribute.strikethrough: true});
  consumePair('<u>', '</u>', {RichNoteAttribute.underline: true});
  consumePair('<sub>', '</sub>', {RichNoteAttribute.subscript: true});
  consumePair('<sup>', '</sup>', {RichNoteAttribute.superscript: true});
  consumePair('`', '`', {RichNoteAttribute.inlineCode: true});

  return RichNoteSeed(
    text: text,
    marks: normalizeRichNoteMarks(marks, text.length),
  );
}

Map<String, dynamic> richTextTemplateData(
  Map<String, dynamic> current,
  RichNoteTextController controller,
) {
  final next = Map<String, dynamic>.from(current);
  next['schema'] = 'general.v2';
  next['richText'] = controller.toRichTextJson();
  return next;
}

Map<String, dynamic> generalNoteTemplateData(
  Map<String, dynamic> current,
  RichNoteTextController controller,
  List<Map<String, dynamic>> images,
  List<Map<String, dynamic>> attachments,
) {
  final next = richTextTemplateData(current, controller);
  next['appflowy'] = appFlowyMirrorJson(
    controller: controller,
    images: images,
    attachments: attachments,
  );
  return next;
}

Map<String, dynamic> blankAppFlowyMirrorJson() {
  return {
    'format': appFlowyMirrorFormatVersion,
    'document': appFlowyDocumentJson([appFlowyParagraphNodeJson('')]),
    'migration': 'blank',
  };
}

Map<String, dynamic> appFlowyMirrorJson({
  required RichNoteTextController controller,
  required List<Map<String, dynamic>> images,
  required List<Map<String, dynamic>> attachments,
}) {
  final nodes = <Map<String, dynamic>>[];
  final text = controller.text;
  final marks = controller.marks;
  final buffer = StringBuffer();

  void flushParagraph({bool force = false}) {
    if (!force && buffer.isEmpty) {
      return;
    }
    nodes.add(appFlowyParagraphNodeJson(buffer.toString()));
    buffer.clear();
  }

  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (character == richNoteEmbedObject) {
      flushParagraph();
      final mark = firstRichNoteMarkAtOffset(marks, index);
      final type = readString(mark?.attributes[RichNoteAttribute.embedType]);
      final id = readString(mark?.attributes[RichNoteAttribute.embedId]);
      if (type == richNoteEmbedTypeImage) {
        final image = nullableMapById(images, id);
        if (image != null) {
          nodes.add(appFlowyImageNodeFromNoteImage(image));
        }
      } else if (type == richNoteEmbedTypeAttachment) {
        final attachment = nullableMapById(attachments, id);
        if (attachment != null) {
          nodes.add(
            afe.paragraphNode(
              text: '附件：${readString(attachment['name'], fallback: '未命名附件')}',
            ),
          );
        }
      }
      continue;
    }
    if (character == '\n') {
      flushParagraph(force: true);
      continue;
    }
    buffer.write(character);
  }
  flushParagraph(force: nodes.isEmpty);
  return {
    'format': appFlowyMirrorFormatVersion,
    'document': appFlowyDocumentJson(nodes),
    'imageBlockCount': images.length,
    'attachmentParagraphCount': attachments.length,
    'migration': 'richTextMirror',
  };
}

Map<String, dynamic> appFlowyDocumentJson(List<Map<String, dynamic>> nodes) {
  return {
    'document': {'type': 'page', if (nodes.isNotEmpty) 'children': nodes},
  };
}

Map<String, dynamic> appFlowyParagraphNodeJson(String text) {
  return {
    'type': 'paragraph',
    'data': {
      'delta': [
        {'insert': text},
      ],
    },
  };
}

final afe = _AppFlowyJsonCompat();

class _AppFlowyJsonCompat {
  Map<String, dynamic> paragraphNode({String? text}) =>
      appFlowyParagraphNodeJson(text ?? '');
}

RichNoteMark? firstRichNoteMarkAtOffset(List<RichNoteMark> marks, int offset) {
  for (final mark in marks) {
    if (mark.start <= offset && mark.end > offset) {
      return mark;
    }
  }
  return null;
}

Map<String, dynamic> appFlowyImageNodeFromNoteImage(
  Map<String, dynamic> image,
) {
  final bytesBase64 = readString(image['bytesBase64']);
  final name = readString(image['name'], fallback: 'image');
  final url = bytesBase64.isNotEmpty
      ? 'data:image/*;base64,$bytesBase64'
      : readString(image['path'], fallback: name);
  final alignment = readEnum(
    NoteImageAlignment.values,
    image['alignment'],
    NoteImageAlignment.left,
  );
  final align = switch (alignment) {
    NoteImageAlignment.center => 'center',
    NoteImageAlignment.right => 'right',
    _ => 'left',
  };
  return {
    'type': 'image',
    'data': {
      'url': url,
      'align': align,
      'width': readDouble(image['width'], fallback: 240),
      'height': readDouble(image['height'], fallback: 160),
    },
  };
}

TextStyle richNoteTextStyleForAttributes(
  BuildContext context,
  TextStyle base,
  Map<String, dynamic> attributes,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final decorations = <TextDecoration>[];
  if (attributes[RichNoteAttribute.underline] == true) {
    decorations.add(TextDecoration.underline);
  }
  if (attributes[RichNoteAttribute.strikethrough] == true) {
    decorations.add(TextDecoration.lineThrough);
  }
  var style = base.copyWith(
    fontWeight: attributes[RichNoteAttribute.bold] == true
        ? FontWeight.w800
        : base.fontWeight,
    fontStyle:
        attributes[RichNoteAttribute.italic] == true ||
            attributes[RichNoteAttribute.quote] == true
        ? FontStyle.italic
        : base.fontStyle,
    decoration: decorations.isEmpty
        ? base.decoration
        : TextDecoration.combine(decorations),
  );
  if (attributes[RichNoteAttribute.inlineCode] == true ||
      attributes[RichNoteAttribute.codeBlock] == true) {
    style = style.copyWith(
      fontFamily: 'monospace',
      color: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
    );
  }
  if (attributes[RichNoteAttribute.subscript] == true) {
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * 0.62,
      fontWeight: FontWeight.w800,
      color: colorScheme.primary,
      fontFeatures: const [FontFeature.subscripts()],
    );
  }
  if (attributes[RichNoteAttribute.superscript] == true) {
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * 0.62,
      fontWeight: FontWeight.w800,
      color: colorScheme.primary,
      fontFeatures: const [FontFeature.superscripts()],
    );
  }
  final heading = readInt(attributes[RichNoteAttribute.heading]);
  if (heading > 0) {
    final multiplier = switch (heading) {
      1 => 1.55,
      2 => 1.32,
      _ => 1.16,
    };
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * multiplier,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
  }
  if (attributes[RichNoteAttribute.quote] == true) {
    style = style.copyWith(color: colorScheme.onSurfaceVariant);
  }
  return style;
}

class RichImageTapTarget {
  const RichImageTapTarget({
    required this.id,
    required this.blockGlobalRect,
    required this.visualGlobalRect,
    required this.visualLocalRect,
    required this.imageBlockHeight,
  });

  final String id;
  final Rect blockGlobalRect;
  final Rect visualGlobalRect;
  final Rect visualLocalRect;
  final double imageBlockHeight;

  bool containsVisualPoint(Offset globalPosition) =>
      visualGlobalRect.contains(globalPosition);

  bool containsBlockPoint(Offset globalPosition) =>
      blockGlobalRect.contains(globalPosition);

  String visualTapDebugLog() {
    return 'IMAGE_VISUAL_TAP id=$id '
        'imageBlock.y=${visualLocalRect.top.toStringAsFixed(1)} '
        'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)} '
        'imageVisualRect=${visualLocalRect.left.toStringAsFixed(1)},'
        '${visualLocalRect.top.toStringAsFixed(1)},'
        '${visualLocalRect.width.toStringAsFixed(1)},'
        '${visualLocalRect.height.toStringAsFixed(1)} '
        'nextParagraph.y>=${imageBlockHeight.toStringAsFixed(1)}';
  }

  String blockTapDebugLog() {
    return 'IMAGE_BLOCK_BACKGROUND_TAP id=$id '
        'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)}';
  }
}

enum RichNoteFlowBlockType { text, image, attachment }

class RichNoteFlowBlock {
  const RichNoteFlowBlock({
    required this.type,
    required this.order,
    required this.start,
    required this.end,
    this.text = '',
    this.id = '',
  });

  final RichNoteFlowBlockType type;
  final int order;
  final int start;
  final int end;
  final String text;
  final String id;
}

List<RichNoteFlowBlock> richNoteFlowBlocks(RichNoteTextController controller) {
  final text = controller.text;
  final marks = controller.marks;
  final blocks = <RichNoteFlowBlock>[];
  var order = 0;
  var textStart = 0;

  void addTextBlock(int start, int end, {bool force = false}) {
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(safeStart, text.length).toInt();
    if (!force && safeEnd <= safeStart && blocks.isNotEmpty) {
      return;
    }
    blocks.add(
      RichNoteFlowBlock(
        type: RichNoteFlowBlockType.text,
        order: order++,
        start: safeStart,
        end: safeEnd,
        text: text.substring(safeStart, safeEnd),
      ),
    );
  }

  for (var index = 0; index < text.length; index++) {
    if (text[index] != richNoteEmbedObject) {
      continue;
    }
    final textEnd = index > textStart && text[index - 1] == '\n'
        ? index - 1
        : index;
    addTextBlock(textStart, textEnd);

    final mark = firstRichNoteMarkAtOffset(marks, index);
    final type = readString(mark?.attributes[RichNoteAttribute.embedType]);
    final id = readString(mark?.attributes[RichNoteAttribute.embedId]);
    if (type == richNoteEmbedTypeImage) {
      blocks.add(
        RichNoteFlowBlock(
          type: RichNoteFlowBlockType.image,
          order: order++,
          start: index,
          end: index + 1,
          id: id,
        ),
      );
    } else if (type == richNoteEmbedTypeAttachment) {
      blocks.add(
        RichNoteFlowBlock(
          type: RichNoteFlowBlockType.attachment,
          order: order++,
          start: index,
          end: index + 1,
          id: id,
        ),
      );
    }

    textStart = index + 1;
    if (textStart < text.length && text[textStart] == '\n') {
      textStart++;
    }
  }

  final needsTrailingText =
      blocks.isEmpty || blocks.last.type != RichNoteFlowBlockType.text;
  addTextBlock(
    textStart,
    text.length,
    force: needsTrailingText && textStart >= text.length,
  );
  if (blocks.isEmpty) {
    addTextBlock(0, 0, force: true);
  }
  return blocks;
}

class GeneralRichTextEditorPanel extends StatefulWidget {
  const GeneralRichTextEditorPanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.style,
    required this.images,
    required this.attachments,
    required this.background,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final RichNoteTextController controller;
  final bool readOnly;
  final Map<String, dynamic> style;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> background;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  State<GeneralRichTextEditorPanel> createState() =>
      _GeneralRichTextEditorPanelState();
}

class _GeneralRichTextEditorPanelState
    extends State<GeneralRichTextEditorPanel> {
  String? selectedEmbedType;
  String? selectedEmbedId;
  final FocusNode bodyFocusNode = FocusNode(debugLabel: 'rich-note-body');
  final Map<int, TextEditingController> flowTextControllers = {};
  final Map<int, FocusNode> flowTextFocusNodes = {};
  final Map<int, TextRange> flowTextRanges = {};
  final Map<String, RichImageTapTarget> imageTapTargets = {};
  Timer? restoreBodyFocusTimer;
  Timer? clearSuppressedParagraphTapTimer;
  bool suppressNextParagraphTap = false;
  bool imageMoveEnabled = false;
  DateTime? lastImageMoveRequestAt;

  Map<String, dynamic>? get selectedImage =>
      selectedEmbedType == richNoteEmbedTypeImage
      ? nullableMapById(widget.images, selectedEmbedId ?? '')
      : null;

  Map<String, dynamic>? get selectedAttachment =>
      selectedEmbedType == richNoteEmbedTypeAttachment
      ? nullableMapById(widget.attachments, selectedEmbedId ?? '')
      : null;

  @override
  void dispose() {
    restoreBodyFocusTimer?.cancel();
    clearSuppressedParagraphTapTimer?.cancel();
    for (final controller in flowTextControllers.values) {
      controller.dispose();
    }
    for (final focusNode in flowTextFocusNodes.values) {
      focusNode.dispose();
    }
    bodyFocusNode.dispose();
    super.dispose();
  }

  void selectEmbed(String type, String id) {
    if (widget.readOnly) {
      return;
    }
    if (type == richNoteEmbedTypeImage) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.controller.clearTextSelectionForImageInteraction();
    }
    final isSameSelection = selectedEmbedType == type && selectedEmbedId == id;
    setState(() {
      selectedEmbedType = type;
      selectedEmbedId = id;
      if (!isSameSelection || type != richNoteEmbedTypeImage) {
        imageMoveEnabled = false;
      }
    });
  }

  void blockEmbedBackgroundTap(String type, String id) {
    if (type == richNoteEmbedTypeImage) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.controller.clearTextSelectionForImageInteraction();
      clearEmbedSelection();
    }
  }

  void registerImageTapTarget(RichImageTapTarget target) {
    imageTapTargets[target.id] = target;
  }

  void removeStaleImageTapTargets() {
    final activeIds = widget.images
        .map((image) => readString(image['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    imageTapTargets.removeWhere((id, _) => !activeIds.contains(id));
  }

  RichImageTapTarget? imageTapTargetAt(Offset globalPosition) {
    final targets = imageTapTargets.values.toList(growable: false).reversed;
    for (final target in targets) {
      if (target.containsVisualPoint(globalPosition)) {
        return target;
      }
    }
    for (final target in targets) {
      if (target.containsBlockPoint(globalPosition)) {
        return target;
      }
    }
    return null;
  }

  void temporarilyDisableBodyFocus() {
    bodyFocusNode.canRequestFocus = false;
    restoreBodyFocusTimer?.cancel();
    restoreBodyFocusTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        bodyFocusNode.canRequestFocus = true;
      }
    });
  }

  void suppressUpcomingParagraphTap() {
    suppressNextParagraphTap = true;
    clearSuppressedParagraphTapTimer?.cancel();
    clearSuppressedParagraphTapTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        if (mounted) {
          suppressNextParagraphTap = false;
        }
      },
    );
  }

  void handleBodyPointerDown(PointerDownEvent event) {
    if (widget.readOnly) {
      return;
    }
    final target = imageTapTargetAt(event.position);
    if (target == null) {
      return;
    }
    suppressUpcomingParagraphTap();
    temporarilyDisableBodyFocus();
    widget.controller.suppressSelectionChangeLogForImageInteraction();
    if (target.containsVisualPoint(event.position)) {
      debugPrint(target.visualTapDebugLog());
      selectEmbed(richNoteEmbedTypeImage, target.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          selectEmbed(richNoteEmbedTypeImage, target.id);
        }
      });
    } else {
      debugPrint(target.blockTapDebugLog());
      blockEmbedBackgroundTap(richNoteEmbedTypeImage, target.id);
    }
  }

  void clearEmbedSelection() {
    if (selectedEmbedType != null || selectedEmbedId != null) {
      setState(() {
        selectedEmbedType = null;
        selectedEmbedId = null;
        imageMoveEnabled = false;
      });
    }
  }

  void updateImage(Map<String, dynamic> image) {
    final id = readString(image['id']);
    final next = widget.images
        .map((item) => readString(item['id']) == id ? image : item)
        .toList(growable: false);
    widget.controller.isolateEmbedBlocks(images: next);
    widget.onImagesChanged(next);
  }

  void requestImageBlockMove(String id, int direction) {
    final now = DateTime.now();
    final last = lastImageMoveRequestAt;
    if (last != null && now.difference(last).inMilliseconds < 450) {
      return;
    }
    lastImageMoveRequestAt = now;
    final moved = widget.controller.moveEmbedBlock(
      type: richNoteEmbedTypeImage,
      id: id,
      direction: direction,
    );
    if (!moved) {
      return;
    }
    final image = nullableMapById(widget.images, id);
    if (image != null) {
      updateImage({...image, 'y': 0.0});
    } else {
      setState(() {});
    }
  }

  void updateAttachment(Map<String, dynamic> attachment) {
    final id = readString(attachment['id']);
    final next = widget.attachments
        .map((item) => readString(item['id']) == id ? attachment : item)
        .toList(growable: false);
    widget.onAttachmentsChanged(next);
  }

  void deleteSelectedImage() {
    final image = selectedImage;
    if (image == null) {
      return;
    }
    final id = readString(image['id']);
    widget.controller.removeEmbedBlock(type: richNoteEmbedTypeImage, id: id);
    widget.onImagesChanged(
      widget.images.where((item) => readString(item['id']) != id).toList(),
    );
    clearEmbedSelection();
  }

  void deleteSelectedAttachment() {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final id = readString(attachment['id']);
    widget.controller.removeEmbedBlock(
      type: richNoteEmbedTypeAttachment,
      id: id,
    );
    widget.onAttachmentsChanged(
      widget.attachments.where((item) => readString(item['id']) != id).toList(),
    );
    clearEmbedSelection();
  }

  void removeKeyboardDeletedEmbed(String type, String id) {
    if (type == richNoteEmbedTypeImage) {
      widget.onImagesChanged(
        widget.images.where((item) => readString(item['id']) != id).toList(),
      );
    } else if (type == richNoteEmbedTypeAttachment) {
      widget.onAttachmentsChanged(
        widget.attachments
            .where((item) => readString(item['id']) != id)
            .toList(),
      );
    }
    if (selectedEmbedType == type && selectedEmbedId == id) {
      clearEmbedSelection();
    }
  }

  TextEditingController flowTextControllerFor(RichNoteFlowBlock block) {
    final controller = flowTextControllers.putIfAbsent(
      block.order,
      () => TextEditingController(text: block.text),
    );
    final focusNode = flowTextFocusNodes[block.order];
    if ((focusNode == null || !focusNode.hasFocus) &&
        controller.text != block.text) {
      final selectionOffset = controller.selection.extentOffset
          .clamp(0, block.text.length)
          .toInt();
      controller.value = TextEditingValue(
        text: block.text,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
    }
    if (focusNode == null || !focusNode.hasFocus) {
      flowTextRanges[block.order] = TextRange(
        start: block.start,
        end: block.end,
      );
    } else {
      flowTextRanges.putIfAbsent(
        block.order,
        () => TextRange(start: block.start, end: block.end),
      );
    }
    return controller;
  }

  FocusNode flowTextFocusNodeFor(RichNoteFlowBlock block) {
    return flowTextFocusNodes.putIfAbsent(
      block.order,
      () => FocusNode(debugLabel: 'rich-note-flow-${block.order}'),
    );
  }

  void replaceFlowTextBlock(RichNoteFlowBlock block, String nextText) {
    final range =
        flowTextRanges[block.order] ??
        TextRange(start: block.start, end: block.end);
    widget.controller.replaceTextRange(range.start, range.end, nextText);
    flowTextRanges[block.order] = TextRange(
      start: range.start,
      end: range.start + nextText.length,
    );
    setState(() {});
  }

  void syncFlowSelection(RichNoteFlowBlock block) {
    final controller = flowTextControllers[block.order];
    if (controller == null || !controller.selection.isValid) {
      return;
    }
    final range =
        flowTextRanges[block.order] ??
        TextRange(start: block.start, end: block.end);
    widget.controller.value = widget.controller.value.copyWith(
      selection: TextSelection(
        baseOffset: range.start + controller.selection.baseOffset,
        extentOffset: range.start + controller.selection.extentOffset,
      ),
      composing: TextRange.empty,
    );
    widget.controller.rememberSelection();
  }

  Future<void> cropSelectedImage() async {
    final image = selectedImage;
    if (image == null) {
      return;
    }
    final sourcePath = readString(image['path']);
    if (sourcePath.isEmpty) {
      showToast(context, '目前平台無法取得圖片路徑，請重新插入圖片後再裁切');
      return;
    }
    final cropped = await NoteFileService.cropImage(context, sourcePath);
    if (!mounted || cropped == null) {
      return;
    }
    final bytes = await cropped.readAsBytes();
    updateImage({
      ...image,
      'bytesBase64': base64Encode(bytes),
      'size': bytes.length,
      'path': cropped.path,
    });
  }

  Future<void> openSelectedAttachment() async {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final bytes = decodeBase64BytesOrNull(
      readString(attachment['bytesBase64']),
    );
    final preview = bytes == null
        ? ''
        : utf8.decode(bytes.take(4096).toList(), allowMalformed: true);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(readString(attachment['name'], fallback: '附件')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Text(
              preview.trim().isEmpty ? '此附件已插入筆記，可下載後使用其他 App 開啟。' : preview,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Future<void> downloadSelectedAttachment() async {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final bytes = decodeBase64BytesOrNull(
      readString(attachment['bytesBase64']),
    );
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '附件內容無法下載');
      return;
    }
    final savedPath = await NoteFileService.saveBytes(
      fileName: readString(attachment['name'], fallback: 'attachment'),
      bytes: bytes,
    );
    if (!mounted) {
      return;
    }
    showToast(context, savedPath == null ? '已取消下載' : '附件已儲存');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = effectiveNoteBackgroundColor(
      context,
      widget.background,
    );
    removeStaleImageTapTargets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.readOnly) ...[
          if (selectedImage != null)
            ModernRichImageEditToolbar(
              image: selectedImage!,
              moveEnabled: imageMoveEnabled,
              onImageChanged: updateImage,
              onMoveEnabledChanged: (value) =>
                  setState(() => imageMoveEnabled = value),
              onCrop: cropSelectedImage,
              onDelete: deleteSelectedImage,
              onDone: clearEmbedSelection,
            )
          else if (selectedAttachment != null)
            RichAttachmentEditToolbar(
              attachment: selectedAttachment!,
              onOpen: openSelectedAttachment,
              onDownload: downloadSelectedAttachment,
              onDelete: deleteSelectedAttachment,
              onDone: clearEmbedSelection,
            )
          else
            RichTextTemplateToolbar(
              controller: widget.controller,
              style: widget.style,
              onStyleChanged: widget.onStyleChanged,
              onAddImage: widget.onAddImage,
              onAddAttachment: widget.onAddAttachment,
              onInsertTodo: widget.onInsertTodo,
            ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: Material(
            color: backgroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : null;
                        widget.controller.configureInlineContent(
                          images: widget.images,
                          attachments: widget.attachments,
                          readOnly: widget.readOnly,
                          selectedType: selectedEmbedType,
                          selectedId: selectedEmbedId,
                          onEmbedSelected: selectEmbed,
                          onEmbedBlockTapped: blockEmbedBackgroundTap,
                          onImageLayoutChanged: registerImageTapTarget,
                          onImageChanged: updateImage,
                          onAttachmentChanged: updateAttachment,
                          onEmbedDeleted: removeKeyboardDeletedEmbed,
                          contentWidth: contentWidth,
                        );
                        final blocks = richNoteFlowBlocks(widget.controller);
                        final bodyStyle = noteBodyTextStyle(
                          widget.style,
                          context: context,
                        );
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final block in blocks)
                                  switch (block.type) {
                                    RichNoteFlowBlockType.text => Builder(
                                      builder: (context) {
                                        final controller =
                                            flowTextControllerFor(block);
                                        final focusNode = flowTextFocusNodeFor(
                                          block,
                                        );
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          readOnly: widget.readOnly,
                                          maxLines: null,
                                          minLines:
                                              blocks.length == 1 &&
                                                  block.text.isEmpty
                                              ? 10
                                              : 1,
                                          style: bodyStyle,
                                          onChanged: widget.readOnly
                                              ? null
                                              : (value) => replaceFlowTextBlock(
                                                  block,
                                                  value,
                                                ),
                                          onTap: widget.readOnly
                                              ? null
                                              : () {
                                                  debugPrint('PARAGRAPH_TAP');
                                                  clearEmbedSelection();
                                                  syncFlowSelection(block);
                                                },
                                          decoration: const InputDecoration(
                                            hintText: '開始輸入筆記內容',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            filled: false,
                                            isCollapsed: true,
                                          ),
                                        );
                                      },
                                    ),
                                    RichNoteFlowBlockType.image =>
                                      InlineRichImageBlock(
                                        image: firstMapById(
                                          widget.images,
                                          block.id,
                                        ),
                                        selected:
                                            selectedEmbedType ==
                                                richNoteEmbedTypeImage &&
                                            selectedEmbedId == block.id,
                                        readOnly: widget.readOnly,
                                        moveEnabled: imageMoveEnabled,
                                        contentWidth: contentWidth,
                                        onSelect: () => selectEmbed(
                                          richNoteEmbedTypeImage,
                                          block.id,
                                        ),
                                        onBlockTap: () =>
                                            blockEmbedBackgroundTap(
                                              richNoteEmbedTypeImage,
                                              block.id,
                                            ),
                                        onLayoutChanged: registerImageTapTarget,
                                        onChanged: updateImage,
                                        onMoveRequest: (direction) =>
                                            requestImageBlockMove(
                                              block.id,
                                              direction,
                                            ),
                                      ),
                                    RichNoteFlowBlockType.attachment =>
                                      InlineRichAttachmentBlock(
                                        attachment: firstMapById(
                                          widget.attachments,
                                          block.id,
                                        ),
                                        selected:
                                            selectedEmbedType ==
                                                richNoteEmbedTypeAttachment &&
                                            selectedEmbedId == block.id,
                                        readOnly: widget.readOnly,
                                        onSelect: () => selectEmbed(
                                          richNoteEmbedTypeAttachment,
                                          block.id,
                                        ),
                                        onChanged: updateAttachment,
                                      ),
                                  },
                                const SizedBox(height: 96),
                              ],
                            ),
                          ),
                        );
                        /*
                        return Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: handleBodyPointerDown,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: bodyFocusNode,
                            readOnly: widget.readOnly,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            style: noteBodyTextStyle(
                              widget.style,
                              context: context,
                            ),
                            onTap: widget.readOnly
                                ? null
                                : () {
                                    if (suppressNextParagraphTap) {
                                      suppressNextParagraphTap = false;
                                      return;
                                    }
                                    debugPrint('PARAGRAPH_TAP');
                                    widget.controller.rememberSelection();
                                    clearEmbedSelection();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          widget.controller.rememberSelection();
                                          widget.controller
                                              .toggleTodoCheckboxAtSelection();
                                        });
                                  },
                            decoration: const InputDecoration(
                              hintText: '開始輸入筆記內容',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isCollapsed: true,
                            ),
                          ),
                        );
                        */
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NoteInlineAssetsStrip extends StatelessWidget {
  const NoteInlineAssetsStrip({
    super.key,
    required this.images,
    required this.attachments,
    required this.readOnly,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final image in images)
              NoteInlineImageTile(
                image: image,
                readOnly: readOnly,
                onDelete: () {
                  final next = List<Map<String, dynamic>>.from(images)
                    ..remove(image);
                  onImagesChanged(next);
                },
              ),
            for (final attachment in attachments)
              NoteInlineAttachmentTile(
                attachment: attachment,
                readOnly: readOnly,
                onDelete: () {
                  final next = List<Map<String, dynamic>>.from(attachments)
                    ..remove(attachment);
                  onAttachmentsChanged(next);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class NoteInlineImageTile extends StatelessWidget {
  const NoteInlineImageTile({
    super.key,
    required this.image,
    required this.readOnly,
    required this.onDelete,
  });

  final Map<String, dynamic> image;
  final bool readOnly;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bytesText = readString(image['bytesBase64']);
    final bytes = decodeBase64BytesOrNull(bytesText);
    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: bytes == null
                        ? const Center(child: Icon(Icons.broken_image_outlined))
                        : Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      readString(image['name'], fallback: '圖片'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              if (!readOnly)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    tooltip: '移除圖片',
                    onPressed: onDelete,
                    icon: const Icon(Icons.close, size: 18),
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
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

class NoteInlineAttachmentTile extends StatelessWidget {
  const NoteInlineAttachmentTile({
    super.key,
    required this.attachment,
    required this.readOnly,
    required this.onDelete,
  });

  final Map<String, dynamic> attachment;
  final bool readOnly;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final size = readInt(attachment['size']);
    return InputChip(
      avatar: const Icon(Icons.attach_file, size: 18),
      label: Text(
        '${readString(attachment['name'], fallback: '附件')}'
        '${size > 0 ? ' · ${formatFileSize(size)}' : ''}',
      ),
      onDeleted: readOnly ? null : onDelete,
    );
  }
}

class InlineRichTodoCheckbox extends StatelessWidget {
  const InlineRichTodoCheckbox({
    super.key,
    required this.checked,
    required this.readOnly,
    required this.onChanged,
  });

  final bool checked;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Checkbox(
        value: checked,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: readOnly ? null : (_) => onChanged(),
      ),
    );
  }
}

class InlineRichImageBlock extends StatelessWidget {
  const InlineRichImageBlock({
    super.key,
    required this.image,
    required this.selected,
    required this.readOnly,
    required this.moveEnabled,
    required this.contentWidth,
    required this.onSelect,
    required this.onBlockTap,
    required this.onLayoutChanged,
    required this.onChanged,
    this.onMoveRequest,
  });

  final Map<String, dynamic> image;
  final bool selected;
  final bool readOnly;
  final bool moveEnabled;
  final double? contentWidth;
  final VoidCallback onSelect;
  final VoidCallback onBlockTap;
  final ValueChanged<RichImageTapTarget> onLayoutChanged;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<int>? onMoveRequest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = decodeBase64BytesOrNull(readString(image['bytesBase64']));
    final locked = image['locked'] == true;
    final alignment = readEnum(
      NoteImageAlignment.values,
      image['alignment'],
      NoteImageAlignment.left,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = math
            .max(
              160.0,
              contentWidth ??
                  (constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 680.0),
            )
            .toDouble();
        final maxImageWidth = math.max(80.0, blockWidth);
        final width = readDouble(
          image['width'],
          fallback: 240,
        ).clamp(80.0, maxImageWidth).toDouble();
        final height = readDouble(
          image['height'],
          fallback: 160,
        ).clamp(60.0, 900.0).toDouble();
        final visualWidth = width;
        final visualHeight = height;
        final borderWidth = readDouble(image['borderWidth']);
        final borderColor = colorFromHex(
          readString(image['borderColor'], fallback: '#5967D8'),
        );
        const blockVerticalPadding = 10.0;
        const handlePadding = 18.0;
        final fixedLeft = switch (alignment) {
          NoteImageAlignment.center => (blockWidth - visualWidth) / 2,
          NoteImageAlignment.right => blockWidth - visualWidth,
          _ => 0.0,
        };
        final freeLeft = readDouble(image['x'], fallback: fixedLeft);
        final imageLeft =
            (alignment == NoteImageAlignment.free ? freeLeft : fixedLeft)
                .clamp(0.0, math.max(0, blockWidth - visualWidth))
                .toDouble();
        const imageOffsetY = 0.0;
        final imageTop = blockVerticalPadding + handlePadding + imageOffsetY;
        final imageBlockHeight =
            imageTop + visualHeight + blockVerticalPadding + handlePadding;
        final clampingHeight = math.max(
          imageBlockHeight + 320.0,
          visualHeight + blockVerticalPadding + (handlePadding * 2) + 120.0,
        );
        final imageRect = Rect.fromLTWH(
          imageLeft.toDouble(),
          imageTop,
          visualWidth,
          visualHeight,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final renderObject = context.findRenderObject();
          if (renderObject is! RenderBox ||
              !renderObject.attached ||
              !renderObject.hasSize) {
            return;
          }
          final blockTopLeft = renderObject.localToGlobal(Offset.zero);
          onLayoutChanged(
            RichImageTapTarget(
              id: readString(image['id']),
              blockGlobalRect:
                  blockTopLeft & Size(blockWidth, imageBlockHeight),
              visualGlobalRect: imageRect.shift(blockTopLeft),
              visualLocalRect: imageRect,
              imageBlockHeight: imageBlockHeight,
            ),
          );
        });

        void handleImageVisualTap() {
          final blockBottom = imageBlockHeight;
          debugPrint(
            'IMAGE_VISUAL_TAP id=${readString(image['id'])} '
            'imageBlock.y=${imageTop.toStringAsFixed(1)} '
            'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)} '
            'imageVisualRect=${imageRect.left.toStringAsFixed(1)},'
            '${imageRect.top.toStringAsFixed(1)},'
            '${imageRect.width.toStringAsFixed(1)},'
            '${imageRect.height.toStringAsFixed(1)} '
            'nextParagraph.y>=${blockBottom.toStringAsFixed(1)}',
          );
          onSelect();
        }

        void handleImageBlockBackgroundTap() {
          debugPrint(
            'IMAGE_BLOCK_BACKGROUND_TAP id=${readString(image['id'])} '
            'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)}',
          );
          onBlockTap();
        }

        void applyTransformRect(Rect rect) {
          final nextWidth = rect.width.clamp(80.0, maxImageWidth).toDouble();
          final nextHeight = rect.height.clamp(60.0, 900.0).toDouble();
          final nextX = rect.left
              .clamp(0.0, math.max(0.0, blockWidth - nextWidth))
              .toDouble();
          onChanged({
            ...image,
            'alignment': NoteImageAlignment.free.name,
            'x': nextX,
            'y': 0.0,
            'width': nextWidth,
            'height': nextHeight,
          });
        }

        Widget buildImageBox(Size size) {
          return MouseRegion(
            cursor: selected && !readOnly && moveEnabled && !locked
                ? SystemMouseCursors.move
                : SystemMouseCursors.click,
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? colorScheme.primary : borderColor,
                  width: selected ? math.max(2, borderWidth) : borderWidth,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes == null
                  ? const Center(child: Icon(Icons.broken_image_outlined))
                  : Image.memory(bytes, fit: BoxFit.fill),
            ),
          );
        }

        final handleSet = <fbt.HandlePosition>{
          fbt.HandlePosition.topLeft,
          fbt.HandlePosition.top,
          fbt.HandlePosition.topRight,
          fbt.HandlePosition.left,
          fbt.HandlePosition.right,
          fbt.HandlePosition.bottomLeft,
          fbt.HandlePosition.bottom,
          fbt.HandlePosition.bottomRight,
        };
        final transformableImage = selected && !readOnly && !locked
            ? fbt.TransformableBox(
                rect: imageRect,
                clampingRect: Rect.fromLTWH(0, 0, blockWidth, clampingHeight),
                constraints: BoxConstraints(
                  minWidth: 80,
                  minHeight: 60,
                  maxWidth: maxImageWidth,
                  maxHeight: 900,
                ),
                resizeModeResolver: () => fbt.ResizeMode.freeform,
                draggable: moveEnabled,
                resizable: true,
                allowFlippingWhileResizing: false,
                enabledHandles: handleSet,
                visibleHandles: handleSet,
                onTap: handleImageVisualTap,
                onDragUpdate: (result, event) {
                  if (!moveEnabled) {
                    return;
                  }
                  if (event.delta.dy < -8) {
                    onMoveRequest?.call(-1);
                  } else if (event.delta.dy > 8) {
                    onMoveRequest?.call(1);
                  }
                },
                onChanged: (result, event) => applyTransformRect(result.rect),
                cornerHandleBuilder: richImageTransformHandle,
                sideHandleBuilder: richImageTransformHandle,
                contentBuilder: (context, rect, flip) =>
                    buildImageBox(rect.size),
              )
            : Positioned(
                left: imageRect.left,
                top: imageRect.top,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleImageVisualTap,
                  child: buildImageBox(imageRect.size),
                ),
              );
        return SizedBox(
          width: blockWidth,
          height: imageBlockHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleImageBlockBackgroundTap,
                  child: const SizedBox.expand(),
                ),
              ),
              transformableImage,
            ],
          ),
        );
      },
    );
  }
}

Widget richImageTransformHandle(
  BuildContext context,
  fbt.HandlePosition handle,
) {
  return Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        border: Border.all(color: Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const SizedBox(width: 14, height: 14),
    ),
  );
}

class InlineRichAttachmentBlock extends StatelessWidget {
  const InlineRichAttachmentBlock({
    super.key,
    required this.attachment,
    required this.selected,
    required this.readOnly,
    required this.onSelect,
    required this.onChanged,
  });

  final Map<String, dynamic> attachment;
  final bool selected;
  final bool readOnly;
  final VoidCallback onSelect;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = readInt(attachment['size']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ActionChip(
        avatar: Icon(
          Icons.attach_file,
          color: selected ? colorScheme.onPrimaryContainer : null,
        ),
        label: Text(
          '${readString(attachment['name'], fallback: '附件')}'
          '${size > 0 ? ' · ${formatFileSize(size)}' : ''}',
        ),
        onPressed: onSelect,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        backgroundColor: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLowest,
      ),
    );
  }
}

class RichImageEditToolbar extends StatefulWidget {
  const RichImageEditToolbar({
    super.key,
    required this.image,
    required this.moveEnabled,
    required this.onImageChanged,
    required this.onMoveEnabledChanged,
    required this.onCrop,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> image;
  final bool moveEnabled;
  final ValueChanged<Map<String, dynamic>> onImageChanged;
  final ValueChanged<bool> onMoveEnabledChanged;
  final VoidCallback onCrop;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  State<RichImageEditToolbar> createState() => _RichImageEditToolbarState();
}

class _RichImageEditToolbarState extends State<RichImageEditToolbar> {
  Map<String, dynamic> get image => widget.image;
  ValueChanged<Map<String, dynamic>> get onImageChanged =>
      widget.onImageChanged;
  VoidCallback get onCrop => widget.onCrop;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onDone => widget.onDone;

  void setValue(String key, Object value) {
    widget.onImageChanged({...widget.image, key: value});
  }

  Future<void> editBorderWidth() async {
    final current = readDouble(widget.image['borderWidth']);
    final controller = TextEditingController(
      text: current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('框線線徑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            suffixText: 'px',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('套用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      setValue('borderWidth', value.clamp(0.0, 24.0).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = readDouble(widget.image['borderWidth']);
    final alignment = readEnum(
      NoteImageAlignment.values,
      widget.image['alignment'],
      NoteImageAlignment.left,
    );
    return _RichAssetToolbarShell(
      children: [
        RichToolbarIconButton(
          tooltip: '裁切',
          icon: Icons.crop,
          onPressed: onCrop,
        ),
        RichToolbarIconButton(
          tooltip: '縮小',
          icon: Icons.open_with,
          active: alignment == NoteImageAlignment.free,
          onPressed: () => setValue('alignment', NoteImageAlignment.free.name),
        ),
        RichToolbarIconButton(
          tooltip: '放大',
          icon: Icons.add,
          onPressed: () {
            onImageChanged({
              ...image,
              'width': readDouble(image['width'], fallback: 240) + 24,
              'height': readDouble(image['height'], fallback: 160) + 16,
            });
          },
        ),
        RichToolbarMenuButton<double>(
          label: '框 $borderWidth',
          tooltip: '框線線徑',
          values: const [0, 1, 2, 4],
          labelBuilder: (value) => value.toStringAsFixed(0),
          onSelected: (value) => setValue('borderWidth', value),
        ),
        RichToolbarColorButton(
          tooltip: '框線顏色',
          selectedColor: readString(image['borderColor'], fallback: '#5967D8'),
          values: const ['#5967D8', '#202522', '#D92D20', '#16803C'],
          onSelected: (value) => setValue('borderColor', value),
        ),
        RichToolbarIconButton(
          tooltip: '靠左',
          icon: Icons.format_align_left,
          active: alignment == NoteImageAlignment.left,
          onPressed: () => setValue('alignment', NoteImageAlignment.left.name),
        ),
        RichToolbarIconButton(
          tooltip: '置中',
          icon: Icons.format_align_center,
          active: alignment == NoteImageAlignment.center,
          onPressed: () =>
              setValue('alignment', NoteImageAlignment.center.name),
        ),
        RichToolbarIconButton(
          tooltip: '靠右',
          icon: Icons.format_align_right,
          active: alignment == NoteImageAlignment.right,
          onPressed: () => setValue('alignment', NoteImageAlignment.right.name),
        ),
        RichToolbarIconButton(
          tooltip: '自由移動',
          icon: Icons.open_with,
          active: alignment == NoteImageAlignment.free,
          onPressed: () => setValue('alignment', NoteImageAlignment.free.name),
        ),
        RichToolbarIconButton(
          tooltip: '刪除圖片',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
        RichToolbarIconButton(
          tooltip: '完成',
          icon: Icons.check,
          onPressed: onDone,
        ),
      ],
    );
  }
}

class ModernRichImageEditToolbar extends StatefulWidget {
  const ModernRichImageEditToolbar({
    super.key,
    required this.image,
    required this.moveEnabled,
    required this.onImageChanged,
    required this.onMoveEnabledChanged,
    required this.onCrop,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> image;
  final bool moveEnabled;
  final ValueChanged<Map<String, dynamic>> onImageChanged;
  final ValueChanged<bool> onMoveEnabledChanged;
  final VoidCallback onCrop;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  State<ModernRichImageEditToolbar> createState() =>
      _ModernRichImageEditToolbarState();
}

class _ModernRichImageEditToolbarState
    extends State<ModernRichImageEditToolbar> {
  bool showColorToolbar = false;
  bool showBorderToolbar = false;
  late final TextEditingController borderWidthController;

  static const borderColors = [
    '#202522',
    '#FFFFFF',
    '#8A8F98',
    '#5967D8',
    '#D92D20',
    '#F79009',
    '#FEE440',
    '#16803C',
    '#12B5CB',
  ];

  @override
  void initState() {
    super.initState();
    borderWidthController = TextEditingController(text: formattedBorderWidth);
  }

  @override
  void didUpdateWidget(covariant ModernRichImageEditToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imageChanged =
        readString(oldWidget.image['id']) != readString(widget.image['id']);
    final widthChanged =
        readDouble(oldWidget.image['borderWidth']) !=
        readDouble(widget.image['borderWidth']);
    if (imageChanged || (!showBorderToolbar && widthChanged)) {
      borderWidthController.text = formattedBorderWidth;
    }
  }

  @override
  void dispose() {
    borderWidthController.dispose();
    super.dispose();
  }

  String get formattedBorderWidth {
    final current = readDouble(widget.image['borderWidth']);
    return current == current.roundToDouble()
        ? current.toStringAsFixed(0)
        : current.toStringAsFixed(1);
  }

  void setValue(String key, Object value) {
    widget.onImageChanged({...widget.image, key: value});
  }

  void lockImage() {
    widget.onMoveEnabledChanged(false);
    setState(() {
      showBorderToolbar = false;
      showColorToolbar = false;
    });
    setValue('locked', true);
  }

  void toggleBorderWidthEditor() {
    setState(() {
      showBorderToolbar = !showBorderToolbar;
      if (showBorderToolbar) {
        showColorToolbar = false;
        borderWidthController.text = formattedBorderWidth;
      }
    });
  }

  void cancelBorderWidthEdit() {
    setState(() {
      borderWidthController.text = formattedBorderWidth;
      showBorderToolbar = false;
    });
  }

  void applyBorderWidthEdit() {
    final parsed = double.tryParse(borderWidthController.text.trim());
    setValue('borderWidth', (parsed ?? 0).clamp(0.0, 24.0).toDouble());
    setState(() => showBorderToolbar = false);
  }

  Future<void> editBorderWidth() async {
    final current = readDouble(widget.image['borderWidth']);
    final controller = TextEditingController(
      text: current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('框線線徑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            suffixText: 'px',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('套用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      setValue('borderWidth', value.clamp(0.0, 24.0).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.image['locked'] == true;
    if (locked) {
      return _RichAssetToolbarShell(
        children: [
          RichToolbarIconButton(
            tooltip: '解除鎖定',
            icon: Icons.lock,
            active: true,
            onPressed: () => setValue('locked', false),
          ),
        ],
      );
    }

    final borderWidth = readDouble(widget.image['borderWidth']);
    final borderColor = readString(
      widget.image['borderColor'],
      fallback: '#5967D8',
    );
    final alignment = readEnum(
      NoteImageAlignment.values,
      widget.image['alignment'],
      NoteImageAlignment.left,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RichAssetToolbarShell(
          children: [
            RichToolbarIconButton(
              tooltip: '裁切',
              icon: Icons.crop,
              onPressed: widget.onCrop,
            ),
            RichToolbarIconButton(
              tooltip: '移動',
              icon: Icons.open_with,
              active: widget.moveEnabled,
              onPressed: () => widget.onMoveEnabledChanged(!widget.moveEnabled),
            ),
            RichToolbarIconButton(
              tooltip: '框線線徑 ${borderWidth.toStringAsFixed(1)}',
              icon: Icons.border_outer,
              active: showBorderToolbar || borderWidth > 0,
              onPressed: toggleBorderWidthEditor,
            ),
            RichToolbarColorToggleButton(
              tooltip: '框線顏色',
              selectedColor: borderColor,
              active: showColorToolbar,
              onPressed: () => setState(() {
                showColorToolbar = !showColorToolbar;
                if (showColorToolbar) {
                  showBorderToolbar = false;
                }
              }),
            ),
            RichToolbarIconButton(
              tooltip: '靠左',
              icon: Icons.format_align_left,
              active: alignment == NoteImageAlignment.left,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.left.name),
            ),
            RichToolbarIconButton(
              tooltip: '置中',
              icon: Icons.format_align_center,
              active: alignment == NoteImageAlignment.center,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.center.name),
            ),
            RichToolbarIconButton(
              tooltip: '靠右',
              icon: Icons.format_align_right,
              active: alignment == NoteImageAlignment.right,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.right.name),
            ),
            RichToolbarIconButton(
              tooltip: '鎖定圖片',
              icon: Icons.lock_open,
              onPressed: lockImage,
            ),
            RichToolbarIconButton(
              tooltip: '刪除圖片',
              icon: Icons.delete_outline,
              onPressed: widget.onDelete,
            ),
            RichToolbarIconButton(
              tooltip: '完成',
              icon: Icons.check,
              onPressed: widget.onDone,
            ),
          ],
        ),
        if (showBorderToolbar) ...[
          const SizedBox(height: 6),
          _RichAssetToolbarShell(
            children: [
              SizedBox(
                width: 112,
                height: 40,
                child: TextField(
                  controller: borderWidthController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onSubmitted: (_) => applyBorderWidthEdit(),
                  decoration: const InputDecoration(
                    suffixText: 'px',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              RichToolbarIconButton(
                tooltip: '取消',
                icon: Icons.close,
                onPressed: cancelBorderWidthEdit,
              ),
              RichToolbarIconButton(
                tooltip: '套用',
                icon: Icons.check,
                onPressed: applyBorderWidthEdit,
              ),
            ],
          ),
        ],
        if (showColorToolbar) ...[
          const SizedBox(height: 6),
          _RichAssetToolbarShell(
            children: [
              for (final color in borderColors)
                RichToolbarColorChoiceButton(
                  color: color,
                  selected: borderColor.toUpperCase() == color.toUpperCase(),
                  onPressed: () {
                    setValue('borderColor', color);
                    setState(() => showColorToolbar = false);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class RichAttachmentEditToolbar extends StatelessWidget {
  const RichAttachmentEditToolbar({
    super.key,
    required this.attachment,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> attachment;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _RichAssetToolbarShell(
      children: [
        RichToolbarIconButton(
          tooltip: '開啟',
          icon: Icons.open_in_new,
          onPressed: onOpen,
        ),
        RichToolbarIconButton(
          tooltip: '下載',
          icon: Icons.download_outlined,
          onPressed: onDownload,
        ),
        RichToolbarIconButton(
          tooltip: '刪除附件',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
        RichToolbarIconButton(
          tooltip: '完成',
          icon: Icons.check,
          onPressed: onDone,
        ),
      ],
    );
  }
}

class _RichAssetToolbarShell extends StatefulWidget {
  const _RichAssetToolbarShell({required this.children});

  final List<Widget> children;

  @override
  State<_RichAssetToolbarShell> createState() => _RichAssetToolbarShellState();
}

class _RichAssetToolbarShellState extends State<_RichAssetToolbarShell> {
  final ScrollController scrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateScrollButtons);
  }

  @override
  void didUpdateWidget(covariant _RichAssetToolbarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleScrollButtonUpdate();
  }

  @override
  void dispose() {
    scrollController.removeListener(updateScrollButtons);
    scrollController.dispose();
    super.dispose();
  }

  void updateScrollButtons() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    final nextLeft = position.pixels > 1;
    final nextRight = position.pixels < position.maxScrollExtent - 1;
    if (nextLeft != canScrollLeft || nextRight != canScrollRight) {
      setState(() {
        canScrollLeft = nextLeft;
        canScrollRight = nextRight;
      });
    }
  }

  void scheduleScrollButtonUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        updateScrollButtons();
      }
    });
  }

  void scrollBy(double delta) {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleScrollButtonUpdate();
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (canScrollLeft)
              RichToolbarScrollButton(
                tooltip: '向左捲動',
                icon: Icons.chevron_left,
                onPressed: () => scrollBy(-260),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.children,
                  ),
                ),
              ),
            ),
            if (canScrollRight)
              RichToolbarScrollButton(
                tooltip: '向右捲動',
                icon: Icons.chevron_right,
                onPressed: () => scrollBy(260),
              ),
          ],
        ),
      ),
    );
  }
}

class RichTextTemplateToolbar extends StatefulWidget {
  const RichTextTemplateToolbar({
    super.key,
    required this.controller,
    required this.style,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
  });

  final RichNoteTextController controller;
  final Map<String, dynamic> style;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;

  @override
  State<RichTextTemplateToolbar> createState() =>
      _RichTextTemplateToolbarState();
}

class _RichTextTemplateToolbarState extends State<RichTextTemplateToolbar> {
  final ScrollController toolbarScrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
    toolbarScrollController.addListener(updateScrollButtons);
  }

  @override
  void didUpdateWidget(covariant RichTextTemplateToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(refresh);
      widget.controller.addListener(refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    toolbarScrollController.removeListener(updateScrollButtons);
    toolbarScrollController.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void applyInline(String attribute, Object value) {
    widget.controller.applyInlineAttribute(attribute, value);
  }

  void applyLine(String attribute, Object value) {
    widget.controller.applyLineAttribute(attribute, value);
  }

  void updateScrollButtons() {
    if (!toolbarScrollController.hasClients) {
      return;
    }
    final position = toolbarScrollController.position;
    final nextLeft = position.pixels > 1;
    final nextRight = position.pixels < position.maxScrollExtent - 1;
    if (nextLeft != canScrollLeft || nextRight != canScrollRight) {
      setState(() {
        canScrollLeft = nextLeft;
        canScrollRight = nextRight;
      });
    }
  }

  void scheduleScrollButtonUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        updateScrollButtons();
      }
    });
  }

  void scrollToolbar(double delta) {
    if (!toolbarScrollController.hasClients) {
      return;
    }
    final position = toolbarScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    toolbarScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleScrollButtonUpdate();
    final colorScheme = Theme.of(context).colorScheme;
    final fontSize = readDouble(widget.style['fontSize'], fallback: 16).round();
    final lineHeight = readDouble(widget.style['lineHeight'], fallback: 1.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (canScrollLeft)
              RichToolbarScrollButton(
                tooltip: '向左',
                icon: Icons.chevron_left,
                onPressed: () => scrollToolbar(-260),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: toolbarScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichToolbarIconButton(
                      tooltip: '復原',
                      icon: Icons.undo,
                      enabled: widget.controller.canUndoRichChange,
                      onPressed: widget.controller.undoRichChange,
                    ),
                    RichToolbarIconButton(
                      tooltip: '再製',
                      icon: Icons.redo,
                      enabled: widget.controller.canRedoRichChange,
                      onPressed: widget.controller.redoRichChange,
                    ),
                    RichToolbarMenuButton<int>(
                      label: '$fontSize',
                      tooltip: '字級',
                      values: const [14, 16, 18, 22, 28],
                      labelBuilder: (value) => '$value',
                      onSelected: (value) => widget.onStyleChanged({
                        ...widget.style,
                        'fontSize': value.toDouble(),
                      }),
                    ),
                    RichToolbarTextButton(
                      label: 'B',
                      tooltip: '粗體',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.bold,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.bold, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '斜體',
                      icon: Icons.format_italic,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.italic,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.italic, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '底線',
                      icon: Icons.format_underlined,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.underline,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.underline, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '刪除線',
                      icon: Icons.format_strikethrough,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.strikethrough,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.strikethrough, true),
                    ),
                    RichToolbarTextButton(
                      label: '<>',
                      tooltip: '行內程式碼',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.inlineCode,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.inlineCode, true),
                    ),
                    RichToolbarTextButton(
                      label: 'X₂',
                      tooltip: '下標',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.subscript,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.subscript, true),
                    ),
                    RichToolbarTextButton(
                      label: 'X²',
                      tooltip: '上標',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.superscript,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.superscript, true),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarMenuButton<double>(
                      label: lineHeight.toStringAsFixed(2),
                      tooltip: '行距',
                      values: const [1.2, 1.45, 1.7, 2.0],
                      labelBuilder: (value) => value.toStringAsFixed(2),
                      onSelected: (value) => widget.onStyleChanged({
                        ...widget.style,
                        'lineHeight': value,
                      }),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '編號清單',
                      icon: Icons.format_list_numbered,
                      onPressed: widget.controller.applyOrderedList,
                    ),
                    RichToolbarIconButton(
                      tooltip: '項目清單',
                      icon: Icons.format_list_bulleted,
                      onPressed: () =>
                          widget.controller.prefixSelectedLines('• '),
                    ),
                    RichToolbarIconButton(
                      tooltip: '待辦清單',
                      icon: Icons.check_box,
                      onPressed: widget.controller.insertTodoCheckbox,
                    ),
                    RichToolbarTextButton(
                      label: '<>',
                      tooltip: '程式碼區塊',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.codeBlock,
                        value: true,
                      ),
                      onPressed: () =>
                          applyLine(RichNoteAttribute.codeBlock, true),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '引用',
                      icon: Icons.format_quote,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.quote,
                        value: true,
                      ),
                      onPressed: () => applyLine(RichNoteAttribute.quote, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '增加縮排',
                      icon: Icons.format_indent_increase,
                      onPressed: () =>
                          widget.controller.prefixSelectedLines('  '),
                    ),
                    RichToolbarIconButton(
                      tooltip: '減少縮排',
                      icon: Icons.format_indent_decrease,
                      onPressed: widget.controller.outdentSelectedLines,
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '上傳圖片',
                      icon: Icons.image_outlined,
                      onPressed: widget.onAddImage,
                    ),
                    RichToolbarIconButton(
                      tooltip: '上傳附件',
                      icon: Icons.attach_file,
                      onPressed: widget.onAddAttachment,
                    ),
                    RichToolbarIconButton(
                      tooltip: '插入待辦',
                      icon: Icons.add_task,
                      onPressed: widget.onInsertTodo,
                    ),
                  ],
                ),
              ),
            ),
            if (canScrollRight)
              RichToolbarScrollButton(
                tooltip: '向右',
                icon: Icons.chevron_right,
                onPressed: () => scrollToolbar(260),
              ),
          ],
        ),
      ),
    );
  }
}

class RichToolbarIconButton extends StatelessWidget {
  const RichToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      color: active ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      disabledColor: colorScheme.onSurface.withValues(alpha: 0.32),
      style: IconButton.styleFrom(
        backgroundColor: active ? colorScheme.primaryContainer : null,
      ),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 48),
      icon: Icon(icon),
    );
  }
}

class RichToolbarTextButton extends StatelessWidget {
  const RichToolbarTextButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: 42,
              height: 48,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RichToolbarScrollButton extends StatelessWidget {
  const RichToolbarScrollButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: colorScheme.primary,
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 48),
      icon: Icon(icon),
    );
  }
}

class RichToolbarColorToggleButton extends StatelessWidget {
  const RichToolbarColorToggleButton({
    super.key,
    required this.tooltip,
    required this.selectedColor,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final String selectedColor;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 42,
            height: 48,
            child: Center(
              child: _ColorSwatch(value: selectedColor, selected: true),
            ),
          ),
        ),
      ),
    );
  }
}

class RichToolbarColorChoiceButton extends StatelessWidget {
  const RichToolbarColorChoiceButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: colorLabel(color),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 48,
          child: Center(
            child: _ColorSwatch(value: color, selected: selected),
          ),
        ),
      ),
    );
  }
}

class RichToolbarColorButton extends StatelessWidget {
  const RichToolbarColorButton({
    super.key,
    required this.tooltip,
    required this.selectedColor,
    required this.values,
    required this.onSelected,
  });

  final String tooltip;
  final String selectedColor;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedColor.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem<String>(
            value: value,
            child: Row(
              children: [
                _ColorSwatch(
                  value: value,
                  selected: selected == value.toUpperCase(),
                ),
                const SizedBox(width: 10),
                Text(colorLabel(value)),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 42,
        height: 48,
        child: Center(
          child: _ColorSwatch(value: selectedColor, selected: true),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.value, required this.selected});

  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(value);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
    );
  }
}

class RichToolbarMenuButton<T> extends StatelessWidget {
  const RichToolbarMenuButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.values,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: PopupMenuButton<T>(
        color: colorScheme.surface,
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final value in values)
            PopupMenuItem<T>(
              value: value,
              child: Text(
                labelBuilder(value),
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
        ],
        child: SizedBox(
          width: 78,
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                color: colorScheme.onSurface,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RichToolbarDivider extends StatelessWidget {
  const RichToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    super.key,
    required this.style,
    required this.imageCount,
    required this.attachmentCount,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
  });

  final Map<String, dynamic> style;
  final int imageCount;
  final int attachmentCount;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xff5967d8)),
              const SizedBox(width: 8),
              Text(
                '編輯工具',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '字型、大小、顏色、行高',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xff687386),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<String>(
                initialSelection: readString(
                  style['fontFamily'],
                  fallback: 'System',
                ),
                label: const Text('字型'),
                width: 132,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'System', label: '系統'),
                  DropdownMenuEntry(value: 'Serif', label: '襯線'),
                  DropdownMenuEntry(value: 'Mono', label: '等寬'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'fontFamily': value});
                  }
                },
              ),
              DropdownMenu<double>(
                initialSelection: readDouble(style['fontSize'], fallback: 16),
                label: const Text('大小'),
                width: 112,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 14, label: '14'),
                  DropdownMenuEntry(value: 16, label: '16'),
                  DropdownMenuEntry(value: 18, label: '18'),
                  DropdownMenuEntry(value: 22, label: '22'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'fontSize': value});
                  }
                },
              ),
              DropdownMenu<String>(
                initialSelection: readString(
                  style['color'],
                  fallback: '#202522',
                ),
                label: const Text('顏色'),
                width: 128,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: '#202522', label: '黑色'),
                  DropdownMenuEntry(value: '#8B2F2F', label: '紅色'),
                  DropdownMenuEntry(value: '#235A93', label: '藍色'),
                  DropdownMenuEntry(value: '#4F6F35', label: '綠色'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'color': value});
                  }
                },
              ),
              DropdownMenu<double>(
                initialSelection: readDouble(
                  style['lineHeight'],
                  fallback: 1.45,
                ),
                label: const Text('行高'),
                width: 112,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 1.2, label: '1.2'),
                  DropdownMenuEntry(value: 1.45, label: '1.45'),
                  DropdownMenuEntry(value: 1.7, label: '1.7'),
                  DropdownMenuEntry(value: 2.0, label: '2.0'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'lineHeight': value});
                  }
                },
              ),
              IconButton.filledTonal(
                tooltip: '上傳圖片',
                onPressed: onAddImage,
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton.filledTonal(
                tooltip: '上傳附件',
                onPressed: onAddAttachment,
                icon: const Icon(Icons.attach_file),
              ),
              IconButton.filledTonal(
                tooltip: '插入待辦',
                onPressed: onInsertTodo,
                icon: const Icon(Icons.check_box_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoteTemplateFields extends StatelessWidget {
  const NoteTemplateFields({
    super.key,
    required this.type,
    required this.data,
    required this.onChanged,
  });

  final NoteTemplateType type;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void setValue(String key, Object? value) {
    onChanged({...data, key: value});
  }

  @override
  Widget build(BuildContext context) {
    if (type == NoteTemplateType.general) {
      return const SizedBox.shrink();
    }
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(noteTemplateIcon(type)),
              const SizedBox(width: 8),
              Text(
                noteTemplateLabel(type),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...switch (type) {
            NoteTemplateType.plan => buildPlanFields(),
            NoteTemplateType.mindMap => buildMindMapFields(),
            NoteTemplateType.lifeSheet => buildLifeSheetFields(),
            NoteTemplateType.general => <Widget>[],
          },
        ],
      ),
    );
  }

  List<Widget> buildPlanFields() {
    final tasks = readMapList(data['tasks']);
    final done = tasks.where((item) => item['done'] == true).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return [
      TemplateTextField(
        label: '目標',
        value: readString(data['goal']),
        onChanged: (value) => setValue('goal', value),
      ),
      TemplateTextField(
        label: '階段',
        value: readString(data['phase']),
        onChanged: (value) => setValue('phase', value),
      ),
      TemplateTextField(
        label: '任務',
        value: tasks
            .map(
              (item) => '${item['done'] == true ? 'x ' : ''}${item['title']}',
            )
            .join('\n'),
        minLines: 3,
        onChanged: (value) {
          setValue(
            'tasks',
            value
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .map(
                  (line) => {
                    'title': line.replaceFirst(RegExp(r'^x\s+'), '').trim(),
                    'done': line.trim().toLowerCase().startsWith('x '),
                  },
                )
                .toList(),
          );
        },
      ),
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text('完成率 ${(progress * 100).round()}%'),
      TemplateTextField(
        label: '開始日期',
        value: readString(data['startDate']),
        onChanged: (value) => setValue('startDate', value),
      ),
      TemplateTextField(
        label: '截止日期',
        value: readString(data['dueDate']),
        onChanged: (value) => setValue('dueDate', value),
      ),
      TemplateTextField(
        label: '進行時間',
        value: readString(data['spentHours'], fallback: '0'),
        onChanged: (value) =>
            setValue('spentHours', double.tryParse(value) ?? 0),
      ),
      TemplateTextField(
        label: '備註',
        value: readString(data['notes']),
        minLines: 2,
        onChanged: (value) => setValue('notes', value),
      ),
    ];
  }

  List<Widget> buildMindMapFields() {
    return [
      TemplateTextField(
        label: '主題',
        value: readString(data['topic']),
        onChanged: (value) => setValue('topic', value),
      ),
      TemplateTextField(
        label: '節點（標題 | 次標 | 說明 | x,y | 顏色 | 展開/收合）',
        value: readMapList(data['nodes'])
            .map(
              (item) =>
                  '${item['title']} | ${item['subtitle']} | ${item['description']} | ${item['x']},${item['y']} | ${item['color']} | ${item['expanded'] == true ? '展開' : '收合'}',
            )
            .join('\n'),
        minLines: 4,
        onChanged: (value) => setValue(
          'nodes',
          value
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map(parseMindMapNodeLine)
              .toList(),
        ),
      ),
    ];
  }

  List<Widget> buildLifeSheetFields() {
    final items = readMapList(data['items']);
    final totalTarget = items.fold<double>(
      0,
      (sum, item) => sum + readDouble(item['targetAmount']),
    );
    final totalCurrent = items.fold<double>(
      0,
      (sum, item) => sum + readDouble(item['currentAmount']),
    );
    final progress = totalTarget <= 0
        ? 0.0
        : (totalCurrent / totalTarget).clamp(0.0, 1.0);
    return [
      TemplateTextField(
        label: '連結計劃',
        value: readStringList(data['linkedPlanIds']).join(', '),
        onChanged: (value) => setValue(
          'linkedPlanIds',
          value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        ),
      ),
      TemplateTextField(
        label: '項目（名稱 | 目標金額 | 目前金額 | 實際花費）',
        value: items
            .map(
              (item) =>
                  '${item['name']} | ${item['targetAmount']} | ${item['currentAmount']} | ${item['actualCost']}',
            )
            .join('\n'),
        minLines: 4,
        onChanged: (value) => setValue(
          'items',
          value
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map(parseLifeSheetItemLine)
              .toList(),
        ),
      ),
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text('金額對比'),
      const SizedBox(height: 8),
      SizedBox(
        height: 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountBar(label: '目標金額', value: totalTarget, maxValue: totalTarget),
            const SizedBox(width: 12),
            AmountBar(
              label: '目前金額',
              value: totalCurrent,
              maxValue: totalTarget,
            ),
          ],
        ),
      ),
      TemplateTextField(
        label: '開始時間',
        value: readString(data['startDate']),
        onChanged: (value) => setValue('startDate', value),
      ),
      TemplateTextField(
        label: '進行時間',
        value: readString(data['spentHours'], fallback: '0'),
        onChanged: (value) =>
            setValue('spentHours', double.tryParse(value) ?? 0),
      ),
      TemplateTextField(
        label: '備註',
        value: readString(data['notes']),
        minLines: 2,
        onChanged: (value) => setValue('notes', value),
      ),
    ];
  }
}

class TemplateTextField extends StatefulWidget {
  const TemplateTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;

  @override
  State<TemplateTextField> createState() => _TemplateTextFieldState();
}

class _TemplateTextFieldState extends State<TemplateTextField> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TemplateTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: widget.minLines,
        maxLines: widget.minLines == 1 ? 1 : null,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class NoteAssetsSummary extends StatelessWidget {
  const NoteAssetsSummary({
    super.key,
    required this.images,
    required this.attachments,
    required this.background,
    this.readOnly = false,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> background;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty &&
        attachments.isEmpty &&
        readString(background['image']).isEmpty) {
      return const SizedBox.shrink();
    }
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('附件', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final image in images)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: Text(readString(image['name'])),
              subtitle: Text(
                '${noteImageAlignmentLabel(readEnum(NoteImageAlignment.values, image['alignment'], NoteImageAlignment.left))}  ${readDouble(image['width']).round()} x ${readDouble(image['height']).round()}',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = List<Map<String, dynamic>>.from(images)
                          ..remove(image);
                        onImagesChanged(next);
                      },
                    ),
            ),
          for (final attachment in attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(readString(attachment['name'])),
              subtitle: Text(
                readString(attachment['mode']) == 'content' ? '插入內容' : '附件檔案',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = List<Map<String, dynamic>>.from(
                          attachments,
                        )..remove(attachment);
                        onAttachmentsChanged(next);
                      },
                    ),
            ),
          if (readString(background['image']).isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('下載'),
              subtitle: Text(
                '${background['image']}  ${noteBackgroundModeLabel(readEnum(NoteBackgroundMode.values, background['mode'], NoteBackgroundMode.fill))}',
              ),
            ),
        ],
      ),
    );
  }
}

class AmountBar extends StatelessWidget {
  const AmountBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxValue <= 0
        ? 0.0
        : (value / maxValue).clamp(0.05, 1.0);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

TextStyle noteBodyTextStyle(
  Map<String, dynamic> style, {
  BuildContext? context,
}) {
  final family = readString(style['fontFamily'], fallback: 'System');
  final colorValue = readString(style['color'], fallback: '#202522');
  final usesDefaultColor =
      colorValue.toUpperCase() == '#202522' || colorValue.trim().isEmpty;
  return TextStyle(
    fontFamily: family == 'System' ? null : family,
    fontSize: readDouble(style['fontSize'], fallback: 16),
    color: usesDefaultColor && context != null
        ? Theme.of(context).colorScheme.onSurface
        : colorFromHex(colorValue),
    height: readDouble(style['lineHeight'], fallback: 1.45),
  );
}

Color effectiveNoteBackgroundColor(
  BuildContext context,
  Map<String, dynamic> background,
) {
  final colorValue = readString(background['color'], fallback: '#FFFFFF');
  final usesDefaultColor =
      colorValue.toUpperCase() == '#FFFFFF' || colorValue.trim().isEmpty;
  if (usesDefaultColor) {
    return Theme.of(context).colorScheme.surface;
  }
  return colorFromHex(colorValue);
}

Color colorFromHex(String value) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
  return Color(parsed ?? 0xff202522);
}

String colorLabel(String value) {
  return switch (value.toUpperCase()) {
    '#5967D8' => '主題藍',
    '#202522' => '深灰',
    '#D92D20' => '紅色',
    '#16803C' => '綠色',
    _ => '自訂色',
  };
}

class NoteFileService {
  const NoteFileService._();

  static Future<PlatformFile?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    return result?.files.single;
  }

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    return result?.files.single;
  }

  static Future<CroppedFile?> cropImage(
    BuildContext context,
    String sourcePath,
  ) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁切圖片',
          toolbarColor: const Color(0xff5967d8),
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.white,
          activeControlsWidgetColor: const Color(0xff5967d8),
          cropFrameColor: const Color(0xff5967d8),
          cropGridColor: const Color(0x665967d8),
          cropFrameStrokeWidth: 3,
          cropGridStrokeWidth: 1,
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          title: '裁切圖片',
          doneButtonTitle: '✓',
          cancelButtonTitle: '✕',
        ),
        WebUiSettings(
          context: context,
          size: const CropperSize(width: 420, height: 420),
          presentStyle: WebPresentStyle.dialog,
        ),
      ],
    );
  }

  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: '儲存附件',
      fileName: fileName,
      bytes: bytes,
    );
  }

  static Future<Uint8List> buildNotePdf({
    required String title,
    required String body,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title.trim().isEmpty ? '未命名筆記' : title.trim(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(body),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> printNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${safeExportFileName(title)}.pdf',
    );
  }

  static Future<void> shareText({
    required String title,
    required String body,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: title.trim().isEmpty ? 'My Note' : title.trim(),
        text: body,
      ),
    );
  }
}

String safeExportFileName(String value) {
  final clean = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return clean.isEmpty ? 'my_note' : clean;
}

Uint8List? decodeBase64BytesOrNull(String value) {
  if (value.trim().isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

Future<Size?> decodeImageDimensions(Uint8List bytes) async {
  if (bytes.isEmpty) {
    return null;
  }
  final completer = Completer<Size?>();
  try {
    ui.decodeImageFromList(bytes, (image) {
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      if (!completer.isCompleted) {
        completer.complete(size);
      }
    });
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }
  return completer.future.timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
}

Size fittedImageDisplaySize({
  required double boxWidth,
  required double boxHeight,
  required double naturalWidth,
  required double naturalHeight,
}) {
  if (boxWidth <= 0 ||
      boxHeight <= 0 ||
      naturalWidth <= 0 ||
      naturalHeight <= 0) {
    return Size(boxWidth, boxHeight);
  }
  final naturalRatio = naturalWidth / naturalHeight;
  final boxRatio = boxWidth / boxHeight;
  if (boxRatio > naturalRatio) {
    return Size(boxHeight * naturalRatio, boxHeight);
  }
  return Size(boxWidth, boxWidth / naturalRatio);
}

Map<String, dynamic> firstMapById(List<Map<String, dynamic>> items, String id) {
  return nullableMapById(items, id) ?? <String, dynamic>{'id': id};
}

Map<String, dynamic>? nullableMapById(
  List<Map<String, dynamic>> items,
  String id,
) {
  for (final item in items) {
    if (readString(item['id']) == id) {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

String formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Map<String, dynamic> parseMindMapNodeLine(String line) {
  final parts = line.split('|').map((item) => item.trim()).toList();
  final position = parts.length > 3 ? parts[3].split(',') : const <String>[];
  return {
    'title': parts.isNotEmpty ? parts[0] : '',
    'subtitle': parts.length > 1 ? parts[1] : '',
    'description': parts.length > 2 ? parts[2] : '',
    'x': position.isNotEmpty ? double.tryParse(position[0]) ?? 0 : 0,
    'y': position.length > 1 ? double.tryParse(position[1]) ?? 0 : 0,
    'color': parts.length > 4 ? parts[4] : '#7C8B5F',
    'expanded': parts.length <= 5 || parts[5] != 'false',
  };
}

Map<String, dynamic> parseLifeSheetItemLine(String line) {
  final parts = line.split('|').map((item) => item.trim()).toList();
  return {
    'name': parts.isNotEmpty ? parts[0] : '',
    'targetAmount': parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 0,
    'currentAmount': parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0,
    'actualCost': parts.length > 3 ? double.tryParse(parts[3]) ?? 0 : 0,
  };
}

String noteTemplateLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '筆記',
    NoteTemplateType.plan => '計劃',
    NoteTemplateType.mindMap => '心智圖',
    NoteTemplateType.lifeSheet => '人生試算表',
  };
}

String noteTemplateDescription(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '自由文字、圖片、附件與背景設定',
    NoteTemplateType.plan => '目標、階段、任務、進度、日期與備註',
    NoteTemplateType.mindMap => '主題、節點、座標、顏色與展開狀態',
    NoteTemplateType.lifeSheet => '計劃連結、金額目標、目前金額與圖表資料',
  };
}

String noteBodyLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '內文',
    NoteTemplateType.plan => '計劃補充內容',
    NoteTemplateType.mindMap => '心智圖補充內容',
    NoteTemplateType.lifeSheet => '試算表補充內容',
  };
}

IconData noteTemplateIcon(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => Icons.notes,
    NoteTemplateType.plan => Icons.flag_outlined,
    NoteTemplateType.mindMap => Icons.account_tree_outlined,
    NoteTemplateType.lifeSheet => Icons.stacked_bar_chart,
  };
}

String noteImageAlignmentLabel(NoteImageAlignment value) {
  return switch (value) {
    NoteImageAlignment.free => '自由移動',
    NoteImageAlignment.left => '靠左',
    NoteImageAlignment.center => '置中',
    NoteImageAlignment.right => '靠右',
  };
}

String noteBackgroundModeLabel(NoteBackgroundMode value) {
  return switch (value) {
    NoteBackgroundMode.fill => '填滿',
    NoteBackgroundMode.stretch => '延伸',
    NoteBackgroundMode.repeat => '重複',
  };
}

class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({super.key, this.event, this.initialDate});

  final ScheduleItem? event;
  final DateTime? initialDate;

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  late final TextEditingController title;
  late final TextEditingController location;
  late final TextEditingController notes;
  late DateTime date;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late int reminder;
  late DateTime initialDateValue;
  late TimeOfDay initialStartTime;
  late TimeOfDay initialEndTime;
  late int initialReminder;
  bool allowPop = false;
  bool didSave = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    title = TextEditingController(text: event?.title ?? '');
    location = TextEditingController(text: event?.location ?? '');
    notes = TextEditingController(text: event?.notes ?? '');
    date = event?.start ?? widget.initialDate ?? DateTime.now();
    final defaultStart = DateTime.now().add(const Duration(hours: 1));
    startTime = event == null
        ? timeOfDate(defaultStart)
        : timeOfDate(event.start);
    endTime = event == null
        ? timeOfDate(defaultStart.add(const Duration(hours: 1)))
        : timeOfDate(event.end);
    reminder = event?.remindBeforeMinutes ?? 30;
    initialDateValue = date;
    initialStartTime = startTime;
    initialEndTime = endTime;
    initialReminder = reminder;
  }

  @override
  void dispose() {
    title.dispose();
    location.dispose();
    notes.dispose();
    super.dispose();
  }

  bool get hasChanges {
    final event = widget.event;
    final nextTitle = title.text.trim();
    final nextLocation = location.text.trim();
    final nextNotes = notes.text.trim();
    final nextStart = combineDateAndTime(date, startTime);
    final nextEnd = combineDateAndTime(date, endTime);
    if (event == null) {
      return nextTitle.isNotEmpty ||
          nextLocation.isNotEmpty ||
          nextNotes.isNotEmpty ||
          !isSameDate(date, initialDateValue) ||
          startTime != initialStartTime ||
          endTime != initialEndTime ||
          reminder != initialReminder;
    }
    return nextTitle != event.title ||
        nextLocation != event.location ||
        nextNotes != event.notes ||
        nextStart != event.start ||
        nextEnd != event.end ||
        reminder != event.remindBeforeMinutes;
  }

  void saveSchedule() {
    if (didSave) {
      return;
    }
    if (!hasChanges) {
      didSave = true;
      return;
    }
    final store = AppStoreScope.of(context);
    final event = widget.event;
    final start = combineDateAndTime(date, startTime);
    var end = combineDateAndTime(date, endTime);
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    store.upsertSchedule(
      ScheduleItem(
        id: event?.id ?? store.newId('s'),
        title: title.text.trim().isEmpty ? '未命名行程' : title.text.trim(),
        start: start,
        end: end,
        location: location.text.trim(),
        notes: notes.text.trim(),
        remindBeforeMinutes: reminder,
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    saveSchedule();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (!hasChanges) {
      discardAndExit();
      return;
    }
    final shouldSave = await confirmSaveChanges(
      context,
      title: '儲存行程？',
      message: '這筆行程有尚未儲存的變更。',
    );
    if (!mounted) {
      return;
    }
    if (shouldSave) {
      saveAndExit();
    } else {
      discardAndExit();
    }
  }

  Future<void> deleteAndExit() async {
    final event = widget.event;
    if (event == null) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除行程？',
      message: '確定要刪除這筆行程嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    AppStoreScope.of(context).deleteSchedule(event);
    didSave = true;
    allowPop = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: widget.event == null ? '新增行程' : '編輯行程',
            subtitle: '時間、地點與提醒',
            leading: PageBackButton(onPressed: requestExit),
            actions: [
              if (widget.event != null)
                IconButton(
                  tooltip: '刪除行程',
                  onPressed: deleteAndExit,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
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
                    if (picked != null) {
                      setState(() => date = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('開始時間'),
                  subtitle: Text(formatTimeOfDayValue(startTime)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showAppTimePicker(
                      context,
                      initialTime: startTime,
                      helpText: '選擇開始時間',
                    );
                    if (picked != null) {
                      setState(() {
                        startTime = picked;
                        final start = combineDateAndTime(date, startTime);
                        final end = combineDateAndTime(date, endTime);
                        if (!end.isAfter(start)) {
                          endTime = timeOfDate(
                            start.add(const Duration(hours: 1)),
                          );
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.update),
                  title: const Text('結束時間'),
                  subtitle: Text(formatTimeOfDayValue(endTime)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showAppTimePicker(
                      context,
                      initialTime: endTime,
                      helpText: '選擇結束時間',
                    );
                    if (picked != null) {
                      setState(() => endTime = picked);
                    }
                  },
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
                  minLines: 3,
                  maxLines: 6,
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
                      setState(() => reminder = value ?? reminder),
                ),
                const SizedBox(height: 16),
                EditorActionButtons(
                  onCancel: discardAndExit,
                  onSave: saveAndExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceEditorPage extends StatefulWidget {
  const FinanceEditorPage({super.key, this.entry});

  final FinanceEntry? entry;

  @override
  State<FinanceEditorPage> createState() => _FinanceEditorPageState();
}

class _FinanceEditorPageState extends State<FinanceEditorPage> {
  late final TextEditingController title;
  late final TextEditingController amount;
  late final TextEditingController note;
  late EntryType type;
  late String category;
  late String account;
  late DateTime date;
  late final String initialTitle;
  late final String initialAmount;
  late final String initialNote;
  late final EntryType initialType;
  late final String initialCategory;
  late String initialAccount;
  late final DateTime initialDate;
  bool allowPop = false;
  bool didSave = false;
  bool syncedDefaultAccount = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    title = TextEditingController(text: entry?.title ?? '');
    amount = TextEditingController(
      text: entry == null ? '' : entry.amount.toStringAsFixed(0),
    );
    note = TextEditingController(text: entry?.note ?? '');
    type = entry?.type ?? EntryType.expense;
    category = entry?.category ?? '食物';
    account = entry?.account ?? '';
    date = entry?.date ?? DateTime.now();
    initialTitle = title.text.trim();
    initialAmount = amount.text.trim();
    initialNote = note.text.trim();
    initialType = type;
    initialCategory = category;
    initialAccount = account;
    initialDate = date;
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  bool get hasChanges {
    return title.text.trim() != initialTitle ||
        amount.text.trim() != initialAmount ||
        note.text.trim() != initialNote ||
        type != initialType ||
        category != initialCategory ||
        account != initialAccount ||
        !isSameMinute(date, initialDate);
  }

  void saveFinanceEntry() {
    if (didSave) {
      return;
    }
    final store = AppStoreScope.of(context);
    final entry = widget.entry;
    final accountOptions = financeAccountOptions(
      store,
      currentAccount: account,
      includeCurrent: entry != null,
    );
    final selectedAccount = accountOptions.contains(account)
        ? account
        : accountOptions.first;
    store.upsertFinanceEntry(
      FinanceEntry(
        id: entry?.id ?? store.newId('f'),
        type: type,
        title: title.text.trim().isEmpty ? '未命名記帳' : title.text.trim(),
        amount: double.tryParse(amount.text) ?? 0,
        category: type == EntryType.income ? '收入' : category,
        account: selectedAccount,
        date: date,
        note: note.text.trim(),
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    saveFinanceEntry();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (!hasChanges) {
      discardAndExit();
      return;
    }
    final shouldSave = await confirmSaveChanges(
      context,
      title: '儲存記帳？',
      message: '這筆記帳有尚未儲存的變更。',
    );
    if (!mounted) {
      return;
    }
    if (shouldSave) {
      saveAndExit();
    } else {
      discardAndExit();
    }
  }

  Future<void> pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: date,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => date = combinePickedDateWithCurrentTime(picked, date));
  }

  Future<void> pickTime() async {
    final picked = await showAppTimePicker(
      context,
      initialTime: timeOfDate(date),
      helpText: '選擇記帳時間',
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => date = combineDateAndTime(date, picked));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final accountOptions = financeAccountOptions(
      store,
      currentAccount: account,
      includeCurrent: widget.entry != null,
    );
    if (!accountOptions.contains(account)) {
      account = accountOptions.first;
      if (widget.entry == null &&
          initialAccount.isEmpty &&
          !syncedDefaultAccount) {
        initialAccount = account;
        syncedDefaultAccount = true;
      }
    }
    Widget fieldBox(Widget child, {double width = 156}) {
      return SizedBox(width: width, child: child);
    }

    Widget metaButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
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

    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: widget.entry == null ? '新增記帳' : '編輯記帳',
            subtitle: '收入、支出、分類與帳戶',
            leading: PageBackButton(onPressed: requestExit),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
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
                      setState(() => type = value.first),
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
                          onSelected: (value) =>
                              setState(() => category = value ?? category),
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
                            setState(() => account = value ?? account),
                      ),
                    ),
                    metaButton(
                      icon: Icons.today_outlined,
                      label: formatDate(date),
                      onPressed: pickDate,
                    ),
                    metaButton(
                      icon: Icons.schedule,
                      label: formatTime(date),
                      onPressed: pickTime,
                      width: 128,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '備註',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                EditorActionButtons(
                  onCancel: discardAndExit,
                  onSave: saveAndExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  final store = AppStoreScope.of(context);
  final name = TextEditingController(text: subscription?.name ?? '');
  final amount = TextEditingController(
    text: subscription == null ? '' : subscription.amount.toStringAsFixed(0),
  );
  final paymentMethod = TextEditingController(text: '信用卡');
  final category = TextEditingController(text: subscription?.category ?? '訂閱');
  var cycle = subscription?.cycle ?? SubscriptionCycle.monthly;
  var date =
      subscription?.nextPaymentDate ??
      DateTime.now().add(const Duration(days: 30));
  var reminderDays = subscription?.reminderDays ?? 3;
  var active = subscription?.isActive ?? true;

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
                  subscription == null ? '新增訂閱' : '編輯訂閱',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: '訂閱名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '金額',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<SubscriptionCycle>(
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
                      setLocalState(() => cycle = value.first),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat),
                  title: Text('下次付款日'),
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
                TextField(
                  controller: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: '付款方式',
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
                      setLocalState(() => reminderDays = value ?? reminderDays),
                ),
                SwitchListTile(
                  value: active,
                  onChanged: (value) => setLocalState(() => active = value),
                  title: const Text('啟用訂閱'),
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      store.upsertSubscription(
                        SubscriptionItem(
                          id: subscription?.id ?? store.newId('sub'),
                          name: name.text.trim().isEmpty
                              ? '未命名訂閱'
                              : name.text.trim(),
                          amount: double.tryParse(amount.text) ?? 0,
                          cycle: cycle,
                          nextPaymentDate: date,
                          paymentMethod: paymentMethod.text.trim(),
                          category: category.text.trim(),
                          reminderDays: reminderDays,
                          isActive: active,
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
  final store = AppStoreScope.of(context);
  final controller = TextEditingController(
    text: store.monthlyBudget.toStringAsFixed(0),
  );
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '調整月預算',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '月預算',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  store.updateBudget(double.tryParse(controller.text) ?? 0);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('套用'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
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
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => TodoEditorPage(todo: todo)));
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
    Navigator.of(context).pop();
  }

  Future<void> deleteAndClose() async {
    final todo = widget.todo;
    if (todo == null) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除待辦事項？',
      message: '確定要刪除這個待辦事項嗎？',
    );
    if (!mounted || !confirmed) {
      return;
    }
    AppStoreScope.of(context).deleteTodo(todo);
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
                      onPressed: () => Navigator.of(context).pop(),
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
                    if (isEditing)
                      IconButton(
                        tooltip: '刪除',
                        onPressed: deleteAndClose,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    IconButton(
                      tooltip: '儲存',
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
                        autofocus: true,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: saveAndClose,
                      child: Text(isEditing ? '儲存' : '新增'),
                    ),
                  ),
                ],
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

String normalizeFolderPath(String value) {
  return value
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('/');
}

String folderBaseName(String value) {
  final path = normalizeFolderPath(value);
  if (path.isEmpty) {
    return '';
  }
  return path.split('/').last;
}

String folderParentPath(String value) {
  final parts = normalizeFolderPath(value).split('/');
  if (parts.length <= 1 || parts.first.isEmpty) {
    return '';
  }
  return parts.take(parts.length - 1).join('/');
}

String joinFolderPath(String parent, String child) {
  final cleanParent = normalizeFolderPath(parent);
  final cleanChild = normalizeFolderPath(child);
  if (cleanChild.isEmpty) {
    return cleanParent;
  }
  return cleanParent.isEmpty ? cleanChild : '$cleanParent/$cleanChild';
}

bool folderContains(String folder, String candidate) {
  final parent = normalizeFolderPath(folder);
  final child = normalizeFolderPath(candidate);
  return parent.isNotEmpty && (child == parent || child.startsWith('$parent/'));
}

String replaceFolderPrefix(String value, String oldPrefix, String newPrefix) {
  final path = normalizeFolderPath(value);
  final oldPath = normalizeFolderPath(oldPrefix);
  final newPath = normalizeFolderPath(newPrefix);
  if (path == oldPath) {
    return newPath;
  }
  if (path.startsWith('$oldPath/')) {
    return joinFolderPath(newPath, path.substring(oldPath.length + 1));
  }
  return path;
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

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool isSameMinute(DateTime a, DateTime b) {
  return isSameDate(a, b) && a.hour == b.hour && a.minute == b.minute;
}
