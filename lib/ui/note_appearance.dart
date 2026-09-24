import 'package:flutter/material.dart';

enum NoteAppearanceTheme { clean, paper, mist, sage, custom }

class NoteAppearancePalette {
  const NoteAppearancePalette({
    required this.label,
    required this.backgroundHex,
    required this.foregroundHex,
  });

  final String label;
  final String backgroundHex;
  final String foregroundHex;
}

const builtInNoteAppearanceThemes =
    <NoteAppearanceTheme, NoteAppearancePalette>{
      NoteAppearanceTheme.clean: NoteAppearancePalette(
        label: '純白',
        backgroundHex: '#FFFFFF',
        foregroundHex: '#202522',
      ),
      NoteAppearanceTheme.paper: NoteAppearancePalette(
        label: '柔紙',
        backgroundHex: '#FFFDF5',
        foregroundHex: '#2D2923',
      ),
      NoteAppearanceTheme.mist: NoteAppearancePalette(
        label: '霧藍',
        backgroundHex: '#F3F6FA',
        foregroundHex: '#1F2937',
      ),
      NoteAppearanceTheme.sage: NoteAppearancePalette(
        label: '淺綠',
        backgroundHex: '#F1F7F3',
        foregroundHex: '#1F2A22',
      ),
    };

NoteAppearanceTheme noteAppearanceThemeFromName(Object? value) {
  if (value is String) {
    for (final theme in NoteAppearanceTheme.values) {
      if (theme.name == value) {
        return theme;
      }
    }
  }
  return NoteAppearanceTheme.custom;
}

Color noteAppearanceColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null || normalized.length != 6) {
    return Colors.white;
  }
  return Color(0xff000000 | parsed);
}

double noteAppearanceContrastRatio(String foreground, String background) {
  final foregroundLuminance = noteAppearanceColor(
    foreground,
  ).computeLuminance();
  final backgroundLuminance = noteAppearanceColor(
    background,
  ).computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
