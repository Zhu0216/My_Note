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
      return LocalDataBundle(
        schema: schema,
        createdAt: readDate(map['createdAt']),
        data: Map<String, dynamic>.from(data),
      );
    }

    // The earliest local backups stored the app payload directly. Accept them
    // so users can recover without first opening an older build.
    if (map.containsKey('notes') || map.containsKey('_persistence')) {
      return LocalDataBundle(createdAt: DateTime.now(), data: map);
    }
    throw const FormatException('不支援的匯入檔格式。');
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
