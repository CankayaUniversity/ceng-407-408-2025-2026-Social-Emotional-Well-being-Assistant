import 'package:flutter/material.dart';
import 'package:ui_prototype/features/mood/models/mood_models.dart';


class MoodRepository extends ChangeNotifier {
  final Map<DateTime, MoodEntry> _byDay = <DateTime, MoodEntry>{};

  MoodPalette palette = kDefaultMoodPalette;

  MoodEntry? entryOf(DateTime day) => _byDay[dateOnly(day)];

  void upsertEntry(MoodEntry entry) {
    _byDay[dateOnly(entry.day)] = entry.copyWith(day: dateOnly(entry.day));
    notifyListeners();
  }

  void removeEntry(DateTime day) {
    _byDay.remove(dateOnly(day));
    notifyListeners();
  }

  /// Month counts for distribution charts.
  /// Order in UI should follow [kMoodOptions].
  Map<MoodType, int> monthCounts(DateTime month) {
    final m = <MoodType, int>{
      for (final o in kMoodOptions) o.type: 0,
    };

    for (final e in _byDay.entries) {
      final d = e.key;
      if (d.year == month.year && d.month == month.month) {
        m[e.value.mood] = (m[e.value.mood] ?? 0) + 1;
      }
    }
    return m;
  }

  void setPalette(MoodPalette p) {
    palette = p;
    notifyListeners();
  }

  void seedDemo() {
    if (_byDay.isNotEmpty) return;

    final now = dateOnly(DateTime.now());

    upsertEntry(
      MoodEntry(
        day: now,
        mood: MoodType.good,
        intensity: 4,
        tags: const ["Üretken", "Odak"],
        title: "Verimli Gün",
        note: "İşler yolunda gitti, motivasyon yüksekti.",
      ),
    );

    upsertEntry(
      MoodEntry(
        day: dateOnly(now.subtract(const Duration(days: 1))),
        mood: MoodType.okay,
        intensity: 3,
        tags: const ["Normal", "Rutin"],
        title: "Standart",
        note: "Bugün ortalama bir gündü.",
      ),
    );

    upsertEntry(
      MoodEntry(
        day: dateOnly(now.subtract(const Duration(days: 2))),
        mood: MoodType.great,
        intensity: 5,
        tags: const ["Aile", "Mutlu"],
        title: "Harika!",
        note: "Güzel haberler aldım, enerjim yüksekti.",
      ),
    );

    upsertEntry(
      MoodEntry(
        day: dateOnly(now.subtract(const Duration(days: 3))),
        mood: MoodType.bad,
        intensity: 2,
        tags: const ["Uykusuz", "Stres"],
        title: "Zor Bir Gün",
        note: "Bugün yorgundum.",
      ),
    );
  }
}
