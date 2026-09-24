part of 'my_note_data.dart';

class _StoredSnapshot {
  const _StoredSnapshot({
    required this.raw,
    required this.source,
    required this.priority,
    this.savedAt,
  });

  final String raw;
  final String source;
  final int priority;
  final DateTime? savedAt;
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
    int persistenceRevision = 0,
    DateTime? lastChangedAt,
    String lastChangeAction = 'load',
    bool persistenceLocked = false,
  }) {
    _persistenceRevision = persistenceRevision;
    _lastChangedAt = lastChangedAt;
    _lastChangeAction = lastChangeAction;
    _persistenceLocked = persistenceLocked;
    _syncNoteFolders();
    _removeLegacySeedTodos();
    _cleanupCompletedTodos();
    _normalizeTodoOrder();
    _nextId = _calculateNextId();
    _scheduleCompletedTodoCleanup();
  }

  factory AppStore.seeded({bool persistenceLocked = false}) {
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
      persistenceLocked: persistenceLocked,
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
  static const String _backupStorageKey = 'my_note_local_v1_backup';
  static const String _backupHistoryStorageKey =
      'my_note_local_v1_backup_history';
  static const String _recoveryStorageKey = 'my_note_local_v1_recovery';
  static const String _checkpointStorageKey = 'my_note_local_v1_checkpoint';
  static const String _changeJournalStorageKey =
      'my_note_local_v1_change_journal';
  static const int _maxBackupSnapshots = 12;
  static const int _maxChangeJournalEntries = 200;

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
    final primaryRaw = prefs.getString(_storageKey);
    final candidates = _readStoredSnapshots(prefs);
    _StoredSnapshot? selectedSnapshot;
    AppStore? selectedStore;

    for (final candidate in candidates) {
      if (_rawIsLegacySeedSnapshot(candidate.raw)) {
        continue;
      }
      final loaded = _tryLoadFromRaw(candidate.raw);
      if (loaded == null) {
        continue;
      }
      final isPrimaryOrCheckpoint =
          candidate.source == 'primary' || candidate.source == 'checkpoint';
      if (!isPrimaryOrCheckpoint &&
          !_rawHasRecoverableUserContent(candidate.raw)) {
        continue;
      }
      if (selectedSnapshot == null ||
          _isSnapshotNewer(candidate, selectedSnapshot)) {
        selectedSnapshot = candidate;
        selectedStore = loaded;
      }
    }

    if (selectedSnapshot == null || selectedStore == null) {
      if (primaryRaw != null) {
        await prefs.setString(_recoveryStorageKey, primaryRaw);
        return AppStore.seeded(persistenceLocked: true);
      }
      return AppStore.seeded();
    }

    final migratedRaw = jsonEncode(selectedStore.toJson());
    if (primaryRaw != null &&
        primaryRaw != migratedRaw &&
        _rawHasRecoverableUserContent(primaryRaw)) {
      await _writeBackupSnapshot(prefs, primaryRaw);
    }
    await prefs.setString(_checkpointStorageKey, migratedRaw);
    await prefs.setString(_storageKey, migratedRaw);
    await _writeBackupSnapshot(prefs, migratedRaw);
    return selectedStore;
  }

  static bool _isSnapshotNewer(
    _StoredSnapshot candidate,
    _StoredSnapshot current,
  ) {
    final candidateRevision = _rawRevision(candidate.raw);
    final currentRevision = _rawRevision(current.raw);
    if (candidateRevision != currentRevision) {
      return candidateRevision > currentRevision;
    }
    if (candidateRevision == 0) {
      final candidateScore = _rawContentScore(candidate.raw);
      final currentScore = _rawContentScore(current.raw);
      if (candidateScore != currentScore) {
        return candidateScore > currentScore;
      }
    }
    final candidateTime =
        _rawChangedAt(candidate.raw) ??
        candidate.savedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final currentTime =
        _rawChangedAt(current.raw) ??
        current.savedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final timeOrder = candidateTime.compareTo(currentTime);
    if (timeOrder != 0) {
      return timeOrder > 0;
    }
    return candidate.priority > current.priority;
  }

  static int _rawContentScore(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        return 0;
      }
      var score = 0;
      for (final key in const [
        'notes',
        'schedules',
        'subscriptions',
        'financeEntries',
        'savingsAccounts',
        'todos',
        'noteFolders',
      ]) {
        final value = data[key];
        if (value is List) {
          score += value.length;
        }
      }
      return score;
    } catch (_) {
      return 0;
    }
  }

  static List<_StoredSnapshot> _readStoredSnapshots(SharedPreferences prefs) {
    final snapshots = <_StoredSnapshot>[];

    void add(
      String? raw, {
      required String source,
      required int priority,
      DateTime? savedAt,
    }) {
      if (raw == null || raw.isEmpty) {
        return;
      }
      snapshots.add(
        _StoredSnapshot(
          raw: raw,
          source: source,
          priority: priority,
          savedAt: savedAt,
        ),
      );
    }

    add(
      prefs.getString(_checkpointStorageKey),
      source: 'checkpoint',
      priority: 4,
    );
    add(prefs.getString(_storageKey), source: 'primary', priority: 3);
    add(
      prefs.getString(_backupStorageKey),
      source: 'latestBackup',
      priority: 2,
    );

    final rawHistory = prefs.getString(_backupHistoryStorageKey);
    if (rawHistory != null) {
      try {
        final decoded = jsonDecode(rawHistory);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map && item['raw'] is String) {
              add(
                item['raw'] as String,
                source: 'backupHistory',
                priority: 1,
                savedAt: DateTime.tryParse(item['savedAt']?.toString() ?? ''),
              );
            } else if (item is String) {
              add(item, source: 'backupHistory', priority: 1);
            }
          }
        }
      } catch (_) {
        // Keep the independently stored primary and checkpoint candidates.
      }
    }
    return snapshots;
  }

  static List<String> _readBackupSnapshots(SharedPreferences prefs) {
    final snapshots = <String>[];
    final latest = prefs.getString(_backupStorageKey);
    if (latest != null) {
      snapshots.add(latest);
    }
    final rawHistory = prefs.getString(_backupHistoryStorageKey);
    if (rawHistory == null) {
      return snapshots;
    }
    try {
      final decoded = jsonDecode(rawHistory);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map && item['raw'] is String) {
            snapshots.add(item['raw'] as String);
          } else if (item is String) {
            snapshots.add(item);
          }
        }
      }
    } catch (_) {
      return snapshots;
    }
    return [
      ...{for (final snapshot in snapshots) snapshot},
    ];
  }

  static Future<void> _writeBackupSnapshot(
    SharedPreferences prefs,
    String raw,
  ) async {
    if (!_rawHasRecoverableUserContent(raw)) {
      return;
    }
    await prefs.setString(_backupStorageKey, raw);
    final snapshotLimit = raw.length >= 1024 * 1024
        ? 2
        : raw.length >= 256 * 1024
        ? 4
        : _maxBackupSnapshots;
    final history = <Map<String, dynamic>>[
      {'savedAt': DateTime.now().toIso8601String(), 'raw': raw},
    ];
    for (final snapshot in _readBackupSnapshots(prefs)) {
      if (snapshot == raw || !_rawHasRecoverableUserContent(snapshot)) {
        continue;
      }
      history.add({
        'savedAt': DateTime.now().toIso8601String(),
        'raw': snapshot,
      });
      if (history.length >= snapshotLimit) {
        break;
      }
    }
    await prefs.setString(_backupHistoryStorageKey, jsonEncode(history));
  }

  static AppStore? _tryLoadFromRaw(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final persistence = data['_persistence'];
      final persistenceData = persistence is Map
          ? Map<String, dynamic>.from(persistence)
          : const <String, dynamic>{};
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
        persistenceRevision:
            (persistenceData['revision'] as num?)?.toInt() ?? 0,
        lastChangedAt: DateTime.tryParse(
          persistenceData['changedAt']?.toString() ?? '',
        ),
        lastChangeAction:
            persistenceData['action']?.toString() ?? 'legacy.load',
      );
    } catch (_) {
      return null;
    }
  }

  static int _rawRevision(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        return 0;
      }
      final persistence = data['_persistence'];
      if (persistence is! Map) {
        return 0;
      }
      return (persistence['revision'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static DateTime? _rawChangedAt(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        return null;
      }
      final persistence = data['_persistence'];
      if (persistence is! Map) {
        return null;
      }
      return DateTime.tryParse(persistence['changedAt']?.toString() ?? '');
    } catch (_) {
      return null;
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
  Future<void> _persistenceQueue = Future<void>.value();
  Timer? _todoCleanupTimer;
  bool _persistenceLocked = false;
  int _persistenceRevision = 0;
  DateTime? _lastChangedAt;
  String _lastChangeAction = 'load';

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
      '_persistence': {
        'revision': _persistenceRevision,
        'changedAt': _lastChangedAt?.toIso8601String(),
        'action': _lastChangeAction,
      },
    };
  }

  /// Creates a portable snapshot. This never changes current app state.
  Future<String> exportBundle() async {
    await flushPersistence();
    return LocalDataBundle(
      createdAt: DateTime.now(),
      data: cloneJsonMap(toJson()),
    ).encode();
  }

  /// Validates and replaces the in-memory state from an export or legacy local
  /// snapshot. The previous state is checkpointed before the imported one is
  /// committed, so a failed or unwanted import remains recoverable.
  Future<LocalImportResult> importBundle(String raw) async {
    final bundle = LocalDataBundle.decode(raw);
    final candidateRaw = jsonEncode(bundle.data);
    final candidate = _tryLoadFromRaw(candidateRaw);
    if (candidate == null) {
      throw const FormatException('匯入資料無法讀取。');
    }

    await flushPersistence();
    if (!_persistenceLocked) {
      final prefs = await SharedPreferences.getInstance();
      final previousRaw = jsonEncode(toJson());
      await prefs.setString(_checkpointStorageKey, previousRaw);
      await _writeBackupSnapshot(prefs, previousRaw);
    }

    notes
      ..clear()
      ..addAll(candidate.notes);
    schedules
      ..clear()
      ..addAll(candidate.schedules);
    subscriptions
      ..clear()
      ..addAll(candidate.subscriptions);
    financeEntries
      ..clear()
      ..addAll(candidate.financeEntries);
    savingsAccounts
      ..clear()
      ..addAll(candidate.savingsAccounts);
    todos
      ..clear()
      ..addAll(candidate.todos);
    noteFolders
      ..clear()
      ..addAll(candidate.noteFolders);
    homeSectionOrder
      ..clear()
      ..addAll(candidate.homeSectionOrder);
    collapsedHomeSections
      ..clear()
      ..addAll(candidate.collapsedHomeSections);
    hiddenHomeSections
      ..clear()
      ..addAll(candidate.hiddenHomeSections);
    hiddenUpcomingItems
      ..clear()
      ..addAll(candidate.hiddenUpcomingItems);
    homeSectionStyles
      ..clear()
      ..addAll(candidate.homeSectionStyles);
    monthlyBudget = candidate.monthlyBudget;
    _nextId = _calculateNextId();
    _normalizeTodoOrder();
    candidate.dispose();
    _commit('data.import.local_export');

    return LocalImportResult(
      createdAt: bundle.createdAt,
      noteCount: notes.length,
      scheduleCount: schedules.length,
      todoCount: todos.length,
    );
  }

  Future<List<LocalBackupSnapshot>> recoverySnapshots() async {
    await flushPersistence();
    final prefs = await SharedPreferences.getInstance();
    final snapshots = <LocalBackupSnapshot>[];
    final seen = <String>{};
    for (final raw in _readBackupSnapshots(prefs)) {
      if (!seen.add(raw)) continue;
      final candidate = _tryLoadFromRaw(raw);
      if (candidate == null || !_rawHasRecoverableUserContent(raw)) {
        candidate?.dispose();
        continue;
      }
      snapshots.add(
        LocalBackupSnapshot(
          raw: raw,
          savedAt: _rawChangedAt(raw) ?? DateTime.now(),
          noteCount: candidate.notes.length,
          scheduleCount: candidate.schedules.length,
          todoCount: candidate.todos.length,
        ),
      );
      candidate.dispose();
    }
    return snapshots;
  }

  Future<LocalImportResult> restoreRecoverySnapshot(
    LocalBackupSnapshot snapshot,
  ) => importBundle(snapshot.raw);

  Future<void> _persistSnapshot({
    required String raw,
    required String action,
    required int revision,
    required DateTime changedAt,
  }) async {
    if (_persistenceLocked) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final currentRaw = prefs.getString(_storageKey);
    await prefs.setString(_checkpointStorageKey, raw);
    await _appendChangeJournal(
      prefs,
      raw: raw,
      action: action,
      revision: revision,
      changedAt: changedAt,
    );
    if (currentRaw != null &&
        currentRaw != raw &&
        _rawHasRecoverableUserContent(currentRaw)) {
      await _writeBackupSnapshot(prefs, currentRaw);
    }
    await prefs.setString(_storageKey, raw);
    await _writeBackupSnapshot(prefs, raw);
  }

  static Future<void> _appendChangeJournal(
    SharedPreferences prefs, {
    required String raw,
    required String action,
    required int revision,
    required DateTime changedAt,
  }) async {
    final entries = <Map<String, dynamic>>[];
    final existingRaw = prefs.getString(_changeJournalStorageKey);
    if (existingRaw != null) {
      try {
        final decoded = jsonDecode(existingRaw);
        if (decoded is List) {
          entries.addAll(
            decoded.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
      } catch (_) {
        // A damaged journal must never block the state checkpoint.
      }
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    entries.insert(0, {
      'revision': revision,
      'changedAt': changedAt.toIso8601String(),
      'action': action,
      'counts': {
        'notes': (data['notes'] as List?)?.length ?? 0,
        'folders': (data['noteFolders'] as List?)?.length ?? 0,
        'schedules': (data['schedules'] as List?)?.length ?? 0,
        'todos': (data['todos'] as List?)?.length ?? 0,
        'subscriptions': (data['subscriptions'] as List?)?.length ?? 0,
        'financeEntries': (data['financeEntries'] as List?)?.length ?? 0,
        'savingsAccounts': (data['savingsAccounts'] as List?)?.length ?? 0,
      },
    });
    if (entries.length > _maxChangeJournalEntries) {
      entries.removeRange(_maxChangeJournalEntries, entries.length);
    }
    await prefs.setString(_changeJournalStorageKey, jsonEncode(entries));
  }

  void _commit([String action = 'state.update']) {
    _persistenceRevision++;
    _lastChangedAt = DateTime.now();
    _lastChangeAction = action;
    final raw = jsonEncode(toJson());
    final revision = _persistenceRevision;
    final changedAt = _lastChangedAt!;
    notifyListeners();
    _persistenceQueue = _persistenceQueue
        .catchError((_) {
          // A prior failed write must not prevent later checkpoints.
        })
        .then(
          (_) => _persistSnapshot(
            raw: raw,
            action: action,
            revision: revision,
            changedAt: changedAt,
          ),
        );
  }

  Future<void> flushPersistence() => _persistenceQueue;

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
        _commit('todo.cleanup.completed');
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
    _todoCleanupTimer?.cancel();
    unawaited(flushPersistence());
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
    _commit('note.upsert:${note.id}');
  }

  void createNoteFolder(String name, {bool notify = true}) {
    final folder = limitFolderPathForStorage(name);
    if (folder.isEmpty) {
      return;
    }
    if (!noteFolders.contains(folder)) {
      noteFolders.add(folder);
      if (notify) {
        _commit('folder.create:$folder');
      }
    }
  }

  void deleteNotesById(Set<String> ids) {
    final now = DateTime.now();
    for (final note in notes.where((item) => ids.contains(item.id))) {
      note.deletedAt = now;
      note.updatedAt = now;
    }
    _commit('note.trash:${ids.join(',')}');
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
    _commit('note.restore:${ids.join(',')}');
  }

  void permanentlyDeleteNotesById(Set<String> ids) {
    notes.removeWhere(
      (item) => ids.contains(item.id) && item.deletedAt != null,
    );
    _commit('note.delete.permanent:${ids.join(',')}');
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
    _commit('note.move:${ids.join(',')}:$target');
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
    _commit('note.rename:${note.id}:$value');
  }

  void renameNoteFolder(String oldName, String newName) {
    final oldPath = normalizeFolderPath(oldName);
    final folderName = limitFolderNameForStorage(folderBaseName(newName));
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
    _commit('folder.rename:$oldPath:$newPath');
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
    _commit('folder.move:$oldPath:$newPath');
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
    _commit('folder.delete:$path');
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
    _commit('note.pin:${note.id}:${note.isPinned}');
  }

  void deleteNote(NoteItem note) {
    note.deletedAt = DateTime.now();
    note.updatedAt = DateTime.now();
    _commit('note.trash:${note.id}');
  }

  void clearTrashNotes() {
    notes.removeWhere((item) => item.deletedAt != null);
    _commit('note.trash.clear');
  }

  void upsertSchedule(ScheduleItem item) {
    final index = schedules.indexWhere((schedule) => schedule.id == item.id);
    if (index >= 0) {
      schedules[index] = item;
    } else {
      schedules.add(item);
    }
    _commit('schedule.upsert:${item.id}:${item.title}');
  }

  void deleteSchedule(ScheduleItem item) {
    schedules.removeWhere((schedule) => schedule.id == item.id);
    _commit('schedule.delete:${item.id}:${item.title}');
  }

  void upsertSubscription(SubscriptionItem item) {
    final index = subscriptions.indexWhere((sub) => sub.id == item.id);
    if (index >= 0) {
      subscriptions[index] = item;
    } else {
      subscriptions.add(item);
    }
    _commit('subscription.upsert:${item.id}:${item.name}');
  }

  void deleteSubscription(SubscriptionItem item) {
    subscriptions.removeWhere((sub) => sub.id == item.id);
    _commit('subscription.delete:${item.id}:${item.name}');
  }

  void upsertFinanceEntry(FinanceEntry item) {
    final index = financeEntries.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      financeEntries[index] = item;
    } else {
      financeEntries.add(item);
    }
    _commit('finance.upsert:${item.id}');
  }

  void deleteFinanceEntry(FinanceEntry item) {
    financeEntries.removeWhere((entry) => entry.id == item.id);
    _commit('finance.delete:${item.id}');
  }

  void upsertSavingsAccount(SavingsAccount account) {
    final index = savingsAccounts.indexWhere((item) => item.id == account.id);
    if (index >= 0) {
      savingsAccounts[index] = account;
    } else {
      savingsAccounts.add(account);
    }
    _commit('savings.upsert:${account.id}:${account.name}');
  }

  void deleteSavingsAccount(SavingsAccount account) {
    savingsAccounts.removeWhere((item) => item.id == account.id);
    _commit('savings.delete:${account.id}:${account.name}');
  }

  void toggleTodo(TodoItem todo) {
    todo.done = !todo.done;
    todo.completedAt = todo.done ? DateTime.now() : null;
    if (!todo.done) {
      todo.sortOrder = _nextActiveTodoSortOrder();
    }
    _commit('todo.toggle:${todo.id}:${todo.done}');
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
    _commit('todo.upsert:${todo.id}:${todo.title}');
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
    _commit('todo.reorder');
  }

  void addTodo(
    String title, {
    DateTime? dueDate,
    bool reminderEnabled = false,
    TimeOfDay? reminderTime,
    List<RelatedItemLink>? links,
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
        links: links,
      ),
    );
    _commit('todo.add:${todos.last.id}:${todos.last.title}');
  }

  void deleteTodo(TodoItem todo) {
    todos.removeWhere((item) => item.id == todo.id);
    _commit('todo.delete:${todo.id}:${todo.title}');
  }

  void updateBudget(double value) {
    monthlyBudget = value;
    _commit('budget.update:$value');
  }

  void toggleHomeSection(HomeSectionId section) {
    if (collapsedHomeSections.contains(section)) {
      collapsedHomeSections.remove(section);
    } else {
      collapsedHomeSections.add(section);
    }
    _commit('home.section.collapse:${section.name}');
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
    _commit('home.section.move:${section.name}:$delta');
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
    _commit('home.section.reorder');
  }

  void toggleHomeSectionVisible(HomeSectionId section) {
    if (hiddenHomeSections.contains(section)) {
      hiddenHomeSections.remove(section);
    } else {
      hiddenHomeSections.add(section);
    }
    _commit('home.section.visible:${section.name}');
  }

  void setUpcomingItemHidden(String key, bool hidden) {
    if (hidden) {
      hiddenUpcomingItems.add(key);
    } else {
      hiddenUpcomingItems.remove(key);
    }
    _commit('home.upcoming.hidden:$key:$hidden');
  }

  void setHomeSectionStyle(HomeSectionId section, HomeSectionStyle style) {
    homeSectionStyles[section] = style;
    _commit('home.section.style:${section.name}:${style.name}');
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
