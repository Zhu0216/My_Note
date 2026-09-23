part of 'my_note_data.dart';

const richTextFormatVersion = 'my_note.rich_text.v1';
const appFlowyMirrorFormatVersion = 'my_note.appflowy.v1';

Map<String, dynamic> blankAppFlowyMirrorJson() {
  return {
    'format': appFlowyMirrorFormatVersion,
    'document': {
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': ''},
              ],
            },
          },
        ],
      },
    },
    'migration': 'blank',
  };
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
    'lineHeight': 1.5,
  };
}

const noteLineHeightValues = <double>[1.0, 1.25, 1.5, 1.75, 2.0];

double nearestNoteLineHeight(double value) {
  return noteLineHeightValues.reduce(
    (closest, candidate) => (candidate - value).abs() < (closest - value).abs()
        ? candidate
        : closest,
  );
}

Map<String, dynamic> migratedNoteStyle(Object? value) {
  final style = readStringMap(value, fallback: defaultNoteStyle());
  style['lineHeight'] = nearestNoteLineHeight(
    readDouble(style['lineHeight'], fallback: 1.5),
  );
  return style;
}

Map<String, dynamic> defaultNoteBackground() {
  return {
    'type': 'color',
    'color': '#FFFFFF',
    'image': '',
    'imageBytesBase64': '',
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

String normalizeFolderPath(String value) {
  return value
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('/');
}

String joinFolderPath(String parent, String child) {
  final cleanParent = normalizeFolderPath(parent);
  final cleanChild = normalizeFolderPath(child);
  if (cleanChild.isEmpty) return cleanParent;
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
  if (path == oldPath) return newPath;
  if (path.startsWith('$oldPath/')) {
    return joinFolderPath(newPath, path.substring(oldPath.length + 1));
  }
  return path;
}

String limitFolderPathForStorage(String value) {
  return normalizeFolderPath(value)
      .split('/')
      .map(limitFolderNameForStorage)
      .where((part) => part.isNotEmpty)
      .join('/');
}

String limitFolderNameForStorage(String value) {
  const maxUnits = 36;
  var usedUnits = 0;
  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    final units = rune > 0xff ? 3 : 2;
    if (usedUnits + units > maxUnits) break;
    buffer.write(String.fromCharCode(rune));
    usedUnits += units;
  }
  return buffer.toString();
}

String folderBaseName(String value) {
  final path = normalizeFolderPath(value);
  return path.isEmpty ? '' : path.split('/').last;
}

String folderParentPath(String value) {
  final parts = normalizeFolderPath(value).split('/');
  if (parts.length <= 1 || parts.first.isEmpty) return '';
  return parts.take(parts.length - 1).join('/');
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
