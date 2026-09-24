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
