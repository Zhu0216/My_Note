part of '../main.dart';

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
    'links': note.links.map((link) => link.toJson()).toList(),
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
    style: migratedNoteStyle(data['style']),
    images: readMapList(data['images']),
    attachments: readMapList(data['attachments']),
    background: readStringMap(
      data['background'],
      fallback: defaultNoteBackground(),
    ),
    links: readRelatedItemLinks(data['links']),
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
    'links': item.links.map((link) => link.toJson()).toList(),
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
    links: readRelatedItemLinks(data['links']),
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
    'links': item.links.map((link) => link.toJson()).toList(),
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
    links: readRelatedItemLinks(data['links']),
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
    'links': item.links.map((link) => link.toJson()).toList(),
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
    links: readRelatedItemLinks(data['links']),
  );
}

Map<String, dynamic> savingsAccountToJson(SavingsAccount item) {
  return {
    'id': item.id,
    'name': item.name,
    'amount': item.amount,
    'links': item.links.map((link) => link.toJson()).toList(),
  };
}

SavingsAccount savingsAccountFromJson(Map<String, dynamic> data) {
  return SavingsAccount(
    id: readString(data['id'], fallback: 'sa-local'),
    name: readString(data['name'], fallback: '未命名帳戶'),
    amount: readDouble(data['amount']),
    links: readRelatedItemLinks(data['links']),
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
    'links': item.links.map((link) => link.toJson()).toList(),
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
    links: readRelatedItemLinks(data['links']),
  );
}

String readString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

bool _rawHasRecoverableUserContent(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return true;
    }
    if (_storeIsLegacySeedSnapshot(decoded)) {
      return false;
    }
    return !_storeHasNoUserContent(decoded);
  } catch (_) {
    return true;
  }
}

bool _rawIsLegacySeedSnapshot(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> &&
        _storeIsLegacySeedSnapshot(decoded);
  } catch (_) {
    return false;
  }
}

bool _storeIsLegacySeedSnapshot(Map<String, dynamic> data) {
  if (_storeHasNoUserContent(data)) {
    return false;
  }
  var matchedSeedItem = false;
  var hasUnknownUserItem = false;

  bool inspectList(
    Object? raw,
    bool Function(Map<String, dynamic> item) isLegacySeed,
  ) {
    if (raw is! List) {
      return true;
    }
    for (final item in raw) {
      if (item is! Map) {
        hasUnknownUserItem = true;
        continue;
      }
      final normalized = Map<String, dynamic>.from(item);
      if (isLegacySeed(normalized)) {
        matchedSeedItem = true;
      } else {
        hasUnknownUserItem = true;
      }
    }
    return true;
  }

  inspectList(data['notes'], _isLegacySeedNote);
  inspectList(data['schedules'], _isLegacySeedSchedule);
  inspectList(data['subscriptions'], _isLegacySeedSubscription);
  inspectList(data['financeEntries'], _isLegacySeedFinanceEntry);
  inspectList(data['savingsAccounts'], _isLegacySeedSavingsAccount);
  inspectList(data['todos'], _isLegacySeedTodo);

  final folders = readStringList(data['noteFolders']);
  if (folders.isNotEmpty) {
    final legacyFolders = {'專案', '學習'};
    if (folders.every(legacyFolders.contains)) {
      matchedSeedItem = true;
    } else {
      hasUnknownUserItem = true;
    }
  }

  return matchedSeedItem && !hasUnknownUserItem;
}

bool _isLegacySeedNote(Map<String, dynamic> item) {
  return (item['id'] == 'n1' && item['title'] == '產品發想：All-in-one 個人管理筆記本') ||
      (item['id'] == 'n2' && item['title'] == '專案規劃');
}

bool _isLegacySeedSchedule(Map<String, dynamic> item) {
  return (item['id'] == 's1' && item['title'] == '團隊會議') ||
      (item['id'] == 's2' && item['title'] == '週末採買');
}

bool _isLegacySeedSubscription(Map<String, dynamic> item) {
  return (item['id'] == 'sub1' && item['name'] == 'ChatGPT') ||
      (item['id'] == 'sub2' && item['name'] == 'Spotify');
}

bool _isLegacySeedFinanceEntry(Map<String, dynamic> item) {
  return (item['id'] == 'f1' && item['title'] == '午餐') ||
      (item['id'] == 'f2' && item['title'] == '咖啡') ||
      (item['id'] == 'f3' && item['title'] == '專案收入');
}

bool _isLegacySeedSavingsAccount(Map<String, dynamic> item) {
  return (item['id'] == 'sa1' && item['name'] == '銀行') ||
      (item['id'] == 'sa2' && item['name'] == '現金');
}

bool _isLegacySeedTodo(Map<String, dynamic> item) {
  return (item['id'] == 't1' && item['title'] == '完成筆記模板整理') ||
      (item['id'] == 't2' && item['title'] == '設定 Firebase 專案') ||
      (item['id'] == 't1' && item['title'] == '讀書計畫');
}

bool _storeHasNoUserContent(Map<String, dynamic> data) {
  const contentKeys = [
    'notes',
    'schedules',
    'subscriptions',
    'financeEntries',
    'savingsAccounts',
    'todos',
    'noteFolders',
  ];
  for (final key in contentKeys) {
    final value = data[key];
    if (value is List && value.isNotEmpty) {
      return false;
    }
  }
  return true;
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
