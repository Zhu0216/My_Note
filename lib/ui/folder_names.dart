import 'package:flutter/services.dart';

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
