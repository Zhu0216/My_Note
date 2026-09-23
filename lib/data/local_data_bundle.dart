part of '../main.dart';

/// Portable, versioned representation of all local-first user data.
///
/// The bundle deliberately contains a complete snapshot instead of a journal so
/// a user can export, inspect, and restore their data without Firebase.
class LocalDataBundle {
  const LocalDataBundle({
    required this.createdAt,
    required this.data,
    this.schema = schemaName,
  });

  static const schemaName = 'my_note.local_export.v1';

  final String schema;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory LocalDataBundle.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('匯入檔不是 JSON 物件。');
    }
    final map = Map<String, dynamic>.from(decoded);
    final schema = readString(map['schema']);
    if (schema == schemaName) {
      final data = map['data'];
      if (data is! Map) {
        throw const FormatException('匯入檔缺少資料內容。');
      }
      final payload = Map<String, dynamic>.from(data);
      LocalDataValidator.validate(payload);
      return LocalDataBundle(
        schema: schema,
        createdAt: readDate(map['createdAt']),
        data: payload,
      );
    }

    // The earliest local backups stored the app payload directly. Accept them
    // so users can recover without first opening an older build.
    if (map.containsKey('notes') || map.containsKey('_persistence')) {
      LocalDataValidator.validate(map);
      return LocalDataBundle(createdAt: DateTime.now(), data: map);
    }
    throw const FormatException('不支援的匯入檔格式。');
  }
}

/// Rejects structurally unsafe snapshots before [AppStore] mutates live data.
///
/// Legacy fields may be absent, but fields that are present must be internally
/// consistent. This keeps older exports recoverable without silently accepting
/// broken identifiers, references, dates, amounts, trees, or canvases.
class LocalDataValidator {
  const LocalDataValidator._();

  static const _recordCollections = <String>{
    'notes',
    'schedules',
    'subscriptions',
    'financeEntries',
    'savingsAccounts',
    'todos',
  };

  static void validate(Map<String, dynamic> data) {
    final ids = <String, Set<String>>{};
    for (final key in _recordCollections) {
      ids[key] = _validateRecords(data, key);
    }
    _validateFolders(data);
    _validateKnownDatesAndNumbers(data);
    _validateTemplates(data, ids);
  }

  static Set<String> _validateRecords(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return <String>{};
    if (value is! List) {
      throw FormatException('$key 必須是清單。');
    }
    final ids = <String>{};
    for (var index = 0; index < value.length; index++) {
      final item = value[index];
      if (item is! Map) {
        throw FormatException('$key 第 ${index + 1} 筆不是資料物件。');
      }
      final id = item['id'];
      if (id is! String || id.trim().isEmpty) {
        throw FormatException('$key 第 ${index + 1} 筆缺少有效 ID。');
      }
      if (!ids.add(id)) {
        throw FormatException('$key 含有重複 ID：$id。');
      }
    }
    return ids;
  }

  static void _validateFolders(Map<String, dynamic> data) {
    final folders = data['noteFolders'];
    if (folders == null) return;
    if (folders is! List) {
      throw const FormatException('noteFolders 必須是清單。');
    }
    final seen = <String>{};
    for (final value in folders) {
      if (value is! String || !_isValidFolderPath(value)) {
        throw FormatException('資料夾路徑無效：$value。');
      }
      final normalized = value.replaceAll('\\', '/');
      if (!seen.add(normalized)) {
        throw FormatException('資料夾路徑重複：$value。');
      }
    }
    for (final note in _maps(data['notes'])) {
      final category = note['category'];
      if (category is String &&
          category.isNotEmpty &&
          !_isValidFolderPath(category)) {
        throw FormatException('筆記資料夾路徑無效：$category。');
      }
    }
  }

  static bool _isValidFolderPath(String value) {
    if (value.trim() != value || value.isEmpty) return false;
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.endsWith('/')) return false;
    return normalized.split('/').every((part) => part.trim().isNotEmpty);
  }

  static void _validateKnownDatesAndNumbers(Map<String, dynamic> data) {
    for (final note in _maps(data['notes'])) {
      _date(note, 'createdAt', '筆記');
      _date(note, 'updatedAt', '筆記');
      _date(note, 'deletedAt', '筆記', optional: true);
    }
    for (final schedule in _maps(data['schedules'])) {
      final start = _date(schedule, 'start', '行程');
      final end = _date(schedule, 'end', '行程');
      if (start != null && end != null && end.isBefore(start)) {
        throw const FormatException('行程結束時間不可早於開始時間。');
      }
      _number(
        schedule,
        'remindBeforeMinutes',
        '行程提醒分鐘',
        nonNegative: true,
        integer: true,
      );
    }
    for (final subscription in _maps(data['subscriptions'])) {
      _date(subscription, 'nextPaymentDate', '訂閱');
      _number(subscription, 'amount', '訂閱金額', nonNegative: true);
      _number(
        subscription,
        'reminderDays',
        '訂閱提醒天數',
        nonNegative: true,
        integer: true,
      );
    }
    for (final entry in _maps(data['financeEntries'])) {
      _date(entry, 'date', '記帳');
      _number(entry, 'amount', '記帳金額', nonNegative: true);
    }
    for (final account in _maps(data['savingsAccounts'])) {
      _number(account, 'amount', '帳戶金額');
    }
    for (final todo in _maps(data['todos'])) {
      _date(todo, 'dueDate', '待辦', optional: true);
      _date(todo, 'reminderTime', '待辦', optional: true);
      _date(todo, 'completedAt', '待辦', optional: true);
      _number(todo, 'sortOrder', '待辦順序', integer: true);
    }
    _number(data, 'monthlyBudget', '每月預算', nonNegative: true);
  }

  static void _validateTemplates(
    Map<String, dynamic> data,
    Map<String, Set<String>> ids,
  ) {
    final referenceIds = <RelatedItemType, Set<String>>{
      RelatedItemType.note: ids['notes']!,
      RelatedItemType.plan: <String>{},
      RelatedItemType.mindMap: <String>{},
      RelatedItemType.lifeProject: <String>{},
      RelatedItemType.todo: ids['todos']!,
      RelatedItemType.schedule: ids['schedules']!,
      RelatedItemType.finance: ids['financeEntries']!,
      RelatedItemType.subscription: ids['subscriptions']!,
      RelatedItemType.account: ids['savingsAccounts']!,
    };
    final notes = _maps(data['notes']);
    for (final note in notes) {
      final noteId = note['id'] as String;
      switch (note['templateType']) {
        case 'plan':
          referenceIds[RelatedItemType.plan]!.add(noteId);
          break;
        case 'mindMap':
          referenceIds[RelatedItemType.mindMap]!.add(noteId);
          break;
        case 'lifeSheet':
          referenceIds[RelatedItemType.lifeProject]!.add(noteId);
          break;
      }
    }

    for (final note in notes) {
      final templateData = note['templateData'];
      if (templateData == null) continue;
      if (templateData is! Map) {
        throw FormatException('筆記 ${note['id']} 的模板資料格式無效。');
      }
      final template = Map<String, dynamic>.from(templateData);
      switch (note['templateType']) {
        case 'plan':
          _validatePlan(template, referenceIds);
          break;
        case 'mindMap':
          _validateMindMap(template, referenceIds);
          break;
        case 'lifeSheet':
          _validateLifeSheet(template, referenceIds);
          break;
        default:
          _validateLinks(template['links'], referenceIds, '筆記');
      }
    }
  }

  static void _validatePlan(
    Map<String, dynamic> template,
    Map<RelatedItemType, Set<String>> references,
  ) {
    _date(template, 'startDate', '計畫', optional: true);
    _date(template, 'dueDate', '計畫', optional: true);
    final nodes = _maps(template['nodes']);
    final nodeById = _uniqueMaps(nodes, '計畫節點');
    for (final node in nodes) {
      _date(node, 'dueDate', '計畫節點', optional: true);
      _number(node, 'priority', '計畫優先級', integer: true);
      _number(node, 'weight', '計畫權重', nonNegative: true);
      final parentId = _optionalId(node['parentId'], '計畫父節點');
      if (parentId != null && !nodeById.containsKey(parentId)) {
        throw FormatException('計畫節點 ${node['id']} 指向不存在的父節點。');
      }
      if (node['type'] == 'task' &&
          nodes.any((candidate) => candidate['parentId'] == node['id'])) {
        throw FormatException('任務節點 ${node['id']} 不可包含子節點。');
      }
      final linkedTodo = _optionalId(node['linkedTodoId'], '關聯待辦');
      if (linkedTodo != null &&
          !references[RelatedItemType.todo]!.contains(linkedTodo)) {
        throw FormatException('計畫節點 ${node['id']} 指向不存在的待辦。');
      }
      final linkedSchedule = _optionalId(node['linkedScheduleId'], '關聯行程');
      if (linkedSchedule != null &&
          !references[RelatedItemType.schedule]!.contains(linkedSchedule)) {
        throw FormatException('計畫節點 ${node['id']} 指向不存在的行程。');
      }
      _validateLinks(node['links'], references, '計畫節點');
    }
    for (final node in nodes) {
      final visited = <String>{};
      String? current = node['id'] as String;
      while (current != null) {
        if (!visited.add(current)) {
          throw const FormatException('計畫階段不可形成循環。');
        }
        current = _optionalId(nodeById[current]?['parentId'], '計畫父節點');
      }
    }
  }

  static void _validateMindMap(
    Map<String, dynamic> template,
    Map<RelatedItemType, Set<String>> references,
  ) {
    final nodes = _maps(template['nodes']);
    if (nodes.isEmpty && template['schema'] != MindMapDocument.schema) return;
    final nodeById = _uniqueMaps(nodes, '心智圖節點');
    final rootId = _requiredId(template['rootNodeId'], '心智圖中心主題');
    if (!nodeById.containsKey(rootId)) {
      throw const FormatException('心智圖中心主題不存在。');
    }
    for (final node in nodes) {
      _number(node, 'x', '心智圖 X 座標');
      _number(node, 'y', '心智圖 Y 座標');
      final parentId = _optionalId(node['parentId'], '心智圖父節點');
      if (parentId != null && !nodeById.containsKey(parentId)) {
        throw FormatException('心智圖節點 ${node['id']} 指向不存在的父節點。');
      }
      _validateLinks(node['links'], references, '心智圖節點');
    }
    final connections = _maps(template['connections']);
    _uniqueMaps(connections, '心智圖連線');
    for (final connection in connections) {
      final from = _requiredId(connection['fromNodeId'], '心智圖連線起點');
      final to = _requiredId(connection['toNodeId'], '心智圖連線終點');
      if (!nodeById.containsKey(from) || !nodeById.containsKey(to)) {
        throw FormatException('心智圖連線 ${connection['id']} 指向不存在的節點。');
      }
    }
  }

  static void _validateLifeSheet(
    Map<String, dynamic> template,
    Map<RelatedItemType, Set<String>> references,
  ) {
    final items = _maps(template['items']);
    _uniqueMaps(items, '人生試算表項目');
    for (final item in items) {
      _number(item, 'targetAmount', '目標金額', nonNegative: true);
      _number(item, 'manualCurrentAmount', '目前金額');
      _number(item, 'progress', '完成率', nonNegative: true, maximum: 1);
      _number(item, 'weight', '項目權重', nonNegative: true);
      _number(item, 'sortOrder', '項目順序', integer: true);
      final accountIds = item['accountIds'];
      if (accountIds != null && accountIds is! List) {
        throw const FormatException('關聯帳戶必須是清單。');
      }
      for (final accountId in accountIds is List ? accountIds : const []) {
        final id = _requiredId(accountId, '關聯帳戶');
        if (!references[RelatedItemType.account]!.contains(id)) {
          throw FormatException('人生試算表指向不存在的帳戶：$id。');
        }
      }
      _validateLinks(item['links'], references, '人生試算表項目');
    }
  }

  static void _validateLinks(
    Object? value,
    Map<RelatedItemType, Set<String>> references,
    String owner,
  ) {
    if (value == null) return;
    if (value is! List) throw FormatException('$owner 的關聯必須是清單。');
    final seen = <String>{};
    for (final raw in value) {
      if (raw is! Map) throw FormatException('$owner 含有無效關聯。');
      final typeName = raw['type'];
      final targetId = _requiredId(raw['targetId'], '$owner 關聯目標');
      final type = RelatedItemType.values
          .where((candidate) => candidate.name == typeName)
          .firstOrNull;
      if (type == null) throw FormatException('$owner 含有未知關聯類型。');
      if (!seen.add('${type.name}:$targetId')) {
        throw FormatException('$owner 含有重複關聯。');
      }
      if (!references[type]!.contains(targetId)) {
        throw FormatException('$owner 指向不存在的${type.name}資料。');
      }
    }
  }

  static Map<String, Map<dynamic, dynamic>> _uniqueMaps(
    List<Map<dynamic, dynamic>> items,
    String label,
  ) {
    final result = <String, Map<dynamic, dynamic>>{};
    for (final item in items) {
      final id = _requiredId(item['id'], label);
      if (result.containsKey(id)) throw FormatException('$label ID 重複：$id。');
      result[id] = item;
    }
    return result;
  }

  static List<Map<dynamic, dynamic>> _maps(Object? value) {
    if (value == null) return <Map<dynamic, dynamic>>[];
    if (value is! List) throw const FormatException('資料清單格式無效。');
    return value.map((item) {
      if (item is! Map) throw const FormatException('資料項目格式無效。');
      return item;
    }).toList();
  }

  static DateTime? _date(
    Map<dynamic, dynamic> data,
    String key,
    String label, {
    bool optional = false,
  }) {
    final value = data[key];
    if (value == null || (value is String && value.trim().isEmpty)) {
      if (optional || !data.containsKey(key)) return null;
      throw FormatException('$label 缺少 $key。');
    }
    if (value is! String) throw FormatException('$label 的 $key 格式無效。');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('$label 的 $key 格式無效。');
    return parsed;
  }

  static void _number(
    Map<dynamic, dynamic> data,
    String key,
    String label, {
    bool nonNegative = false,
    bool integer = false,
    double? maximum,
  }) {
    if (!data.containsKey(key) || data[key] == null) return;
    final value = data[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('$label 必須是有效數字。');
    }
    if (nonNegative && value < 0) throw FormatException('$label 不可為負數。');
    if (integer && value != value.roundToDouble()) {
      throw FormatException('$label 必須是整數。');
    }
    if (maximum != null && value > maximum) {
      throw FormatException('$label 不可大於 $maximum。');
    }
  }

  static String _requiredId(Object? value, String label) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$label 缺少有效 ID。');
    }
    return value;
  }

  static String? _optionalId(Object? value, String label) {
    if (value == null || value == '') return null;
    return _requiredId(value, label);
  }
}

class LocalImportResult {
  const LocalImportResult({
    required this.createdAt,
    required this.noteCount,
    required this.scheduleCount,
    required this.todoCount,
  });

  final DateTime createdAt;
  final int noteCount;
  final int scheduleCount;
  final int todoCount;
}

/// A validated local recovery snapshot. The raw payload stays private to the
/// app flow and is only used after the user confirms a restore action.
class LocalBackupSnapshot {
  const LocalBackupSnapshot({
    required this.raw,
    required this.savedAt,
    required this.noteCount,
    required this.scheduleCount,
    required this.todoCount,
  });

  final String raw;
  final DateTime savedAt;
  final int noteCount;
  final int scheduleCount;
  final int todoCount;
}
