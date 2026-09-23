import '../data/my_note_data.dart';

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
