import 'package:flutter/material.dart';

/// Keep all model/state types for the Mood feature in a single place.
/// This is a lightweight prototype-friendly model layer.

/// The 5 main mood categories.
enum MoodType { terrible, bad, okay, good, great }

/// UI-facing option metadata (label + emoji). Color comes from [MoodPalette].
@immutable
class MoodOption {
  final MoodType type;

  /// Turkish label used across the UI
  final String labelTr;

  final String emoji;

  const MoodOption({
    required this.type,
    required this.labelTr,
    required this.emoji,
  });

  // ✅ Backward/forward compatible getters (so UI won't crash if "label/title/text" is used)
  String get label => labelTr;
  String get title => labelTr;
  String get text => labelTr;
  String get name => labelTr;
}

/// Stable ordering used everywhere (charts, selectors, etc.)
const List<MoodOption> kMoodOptions = <MoodOption>[
  MoodOption(type: MoodType.terrible, labelTr: 'Berbat', emoji: '😫'),
  MoodOption(type: MoodType.bad, labelTr: 'Kötü', emoji: '😕'),
  MoodOption(type: MoodType.okay, labelTr: 'İdare', emoji: '😐'),
  MoodOption(type: MoodType.good, labelTr: 'İyi', emoji: '🙂'),
  MoodOption(type: MoodType.great, labelTr: 'Harika', emoji: '😄'),
];

MoodOption optionOf(MoodType t) => kMoodOptions.firstWhere((o) => o.type == t);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

@immutable
class MoodEntry {
  final DateTime day; // stored as date-only
  final MoodType mood;
  final int intensity; // 1..5
  final List<String> tags;
  final String title;
  final String note;

  const MoodEntry({
    required this.day,
    required this.mood,
    required this.intensity,
    required this.tags,
    required this.title,
    required this.note,
  });

  MoodEntry copyWith({
    DateTime? day,
    MoodType? mood,
    int? intensity,
    List<String>? tags,
    String? title,
    String? note,
  }) {
    return MoodEntry(
      day: day ?? this.day,
      mood: mood ?? this.mood,
      intensity: intensity ?? this.intensity,
      tags: tags ?? this.tags,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }
}

@immutable
class MoodPalette {
  final String name;
  final Color terrible;
  final Color bad;
  final Color okay;
  final Color good;
  final Color great;

  const MoodPalette({
    required this.name,
    required this.terrible,
    required this.bad,
    required this.okay,
    required this.good,
    required this.great,
  });

  Color colorOf(MoodType t) {
    switch (t) {
      case MoodType.terrible:
        return terrible;
      case MoodType.bad:
        return bad;
      case MoodType.okay:
        return okay;
      case MoodType.good:
        return good;
      case MoodType.great:
        return great;
    }
  }

  List<Color> get colors => <Color>[terrible, bad, okay, good, great];
}

/// Preset palettes shown in Theme screen.
@immutable
class MoodThemePalette {
  final String title;
  final MoodPalette palette;

  const MoodThemePalette({required this.title, required this.palette});

  String get name => palette.name;
  List<Color> get colors => palette.colors;
}

const MoodPalette kDefaultMoodPalette = MoodPalette(
  name: 'Default',
  terrible: Color(0xFFFF5A5F),
  bad: Color(0xFFFF9F1C),
  okay: Color(0xFFFFD166),
  good: Color(0xFF8CE99A),
  great: Color(0xFF2EC4B6),
);

const List<MoodThemePalette> kThemePalettes = <MoodThemePalette>[
  MoodThemePalette(
    title: 'Default',
    palette: kDefaultMoodPalette,
  ),
  MoodThemePalette(
    title: 'Ocean',
    palette: MoodPalette(
      name: 'Ocean',
      terrible: Color(0xFFEF476F),
      bad: Color(0xFF118AB2),
      okay: Color(0xFF06D6A0),
      good: Color(0xFF73A6FF),
      great: Color(0xFF0B132B),
    ),
  ),
  MoodThemePalette(
    title: 'Sunset',
    palette: MoodPalette(
      name: 'Sunset',
      terrible: Color(0xFFFF006E),
      bad: Color(0xFFFFBE0B),
      okay: Color(0xFFFB5607),
      good: Color(0xFF8338EC),
      great: Color(0xFF3A86FF),
    ),
  ),
];
