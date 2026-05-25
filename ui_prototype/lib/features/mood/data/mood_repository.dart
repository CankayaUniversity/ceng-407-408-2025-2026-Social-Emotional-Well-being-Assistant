import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui_prototype/features/mood/models/mood_models.dart';
import 'package:ui_prototype/core/services/gamification_service.dart';

class MoodRepository extends ChangeNotifier {
  final Map<DateTime, MoodEntry> _byDay = <DateTime, MoodEntry>{};

  MoodPalette palette = kDefaultMoodPalette;

  String? _userKey;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  String? get userKey => _userKey;

  // ---------- Public API (same as before) ----------
  MoodEntry? entryOf(DateTime day) => _byDay[dateOnly(day)];

  void upsertEntry(MoodEntry entry) {
    _byDay[dateOnly(entry.day)] = entry.copyWith(day: dateOnly(entry.day));
    notifyListeners();

    // Gamification Triggers
    GamificationService().recordMoodEntry();
    GamificationService().recordMoodType(entry.intensity); // intensity maps to 1-5 score

    unawaited(_save()); // ✅ persist
  }

  void removeEntry(DateTime day) {
    _byDay.remove(dateOnly(day));
    notifyListeners();
    unawaited(_save()); // ✅ persist
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
    unawaited(_savePalette()); // ✅ persist palette per user
  }

  /// (Eski demo fonksiyonu durabilir; artık otomatik çağırmayın)
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

  // ---------- NEW: user binding + persistence ----------
  /// ✅ Mood'u user'a özel yapar.
  /// MoodScreen initState içinde bunu çağırın:
  /// await repo.bindUser(loginUsernameOrUserId);
  Future<void> bindUser(String userKey) async {
    if (_userKey == userKey && _loaded) return;

    _userKey = userKey;

    // kullanıcı değişince önce temizle
    _byDay.clear();
    palette = kDefaultMoodPalette;
    _loaded = false;
    notifyListeners();

    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (_userKey == null || _userKey!.isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1) entries
    final raw = prefs.getString(_entriesKey(_userKey!));
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final e = _entryFromJson(item.cast<String, dynamic>());
              _byDay[dateOnly(e.day)] = e;
            }
          }
        }
      } catch (_) {
        // bozuk json varsa görmezden gel
      }
    }

    // 2) palette
    final palName = prefs.getString(_paletteKey(_userKey!));
    if (palName != null && palName.isNotEmpty) {
      final found = kThemePalettes
          .map((x) => x.palette)
          .where((p) => p.name == palName)
          .toList();
      if (found.isNotEmpty) palette = found.first;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    if (_userKey == null || _userKey!.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = _byDay.values
        .map((e) => _entryToJson(e))
        .toList()
      ..sort((a, b) => (a["day"] as String).compareTo(b["day"] as String));

    await prefs.setString(_entriesKey(_userKey!), jsonEncode(list));
  }

  Future<void> _savePalette() async {
    if (_userKey == null || _userKey!.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey(_userKey!), palette.name);
  }

  // ---------- Keys ----------
  static String _entriesKey(String userKey) => "mood_entries_$userKey";
  static String _paletteKey(String userKey) => "mood_palette_$userKey";

  // ---------- JSON helpers ----------
  Map<String, dynamic> _entryToJson(MoodEntry e) => {
    "day": "${e.day.year.toString().padLeft(4, '0')}-"
        "${e.day.month.toString().padLeft(2, '0')}-"
        "${e.day.day.toString().padLeft(2, '0')}",
    "mood": e.mood.name, // "good", "bad" ...
    "intensity": e.intensity,
    "tags": e.tags,
    "title": e.title,
    "note": e.note,
  };

  MoodEntry _entryFromJson(Map<String, dynamic> j) {
    final dayStr = (j["day"] ?? "").toString();
    DateTime day;
    try {
      day = dateOnly(DateTime.parse(dayStr));
    } catch (_) {
      day = dateOnly(DateTime.now());
    }

    final moodStr = (j["mood"] ?? "okay").toString();
    MoodType mood;
    try {
      mood = MoodType.values.byName(moodStr);
    } catch (_) {
      mood = MoodType.okay;
    }

    final intensityRaw = j["intensity"];
    final intensity = (intensityRaw is int)
        ? intensityRaw
        : int.tryParse(intensityRaw?.toString() ?? "") ?? 3;

    final tagsRaw = j["tags"];
    final tags = (tagsRaw is List)
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return MoodEntry(
      day: day,
      mood: mood,
      intensity: intensity,
      tags: tags,
      title: (j["title"] ?? "").toString(),
      note: (j["note"] ?? "").toString(),
    );
  }
}
