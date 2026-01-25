import 'dart:math';
import '../models/mood_entry.dart';

class MoodStats {
  final List<MoodEntry> entries;

  MoodStats(this.entries);

  List<MoodEntry> get last7Days => _withinDays(7);
  List<MoodEntry> get last30Days => _withinDays(30);

  List<MoodEntry> _withinDays(int days) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    return entries.where((e) => !e.time.isBefore(from)).toList();
  }

  double avgMood(List<MoodEntry> list) {
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (a, b) => a + b.mood);
    return sum / list.length;
  }

  Map<int, int> distribution(List<MoodEntry> list) {
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final e in list) {
      map[e.mood] = (map[e.mood] ?? 0) + 1;
    }
    return map;
  }

  /// Haftanın günlerine göre ortalama (Pzt..Paz)
  List<double> weekdayAverages(List<MoodEntry> list) {
    // DateTime.weekday: Mon=1..Sun=7
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);

    for (final e in list) {
      final idx = e.time.weekday - 1;
      sums[idx] += e.mood.toDouble();
      counts[idx] += 1;
    }

    return List.generate(7, (i) => counts[i] == 0 ? 0 : sums[i] / counts[i]);
  }

  /// Son 7 gün trend (günlük ortalama) -> 7 eleman
  List<double> last7DailyTrend() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    final values = <double>[];
    for (final d in days) {
      final dayEntries = entries.where((e) =>
      e.time.year == d.year && e.time.month == d.month && e.time.day == d.day).toList();
      values.add(avgMood(dayEntries));
    }
    return values;
  }

  /// Günün saati analizi: Sabah(5-11) / Öğle(12-16) / Akşam(17-21) / Gece(22-4)
  Map<String, double> timeOfDayAverages(List<MoodEntry> list) {
    final buckets = {
      "Sabah": <int>[],
      "Öğle": <int>[],
      "Akşam": <int>[],
      "Gece": <int>[],
    };

    for (final e in list) {
      final h = e.time.hour;
      if (h >= 5 && h <= 11) buckets["Sabah"]!.add(e.mood);
      else if (h >= 12 && h <= 16) buckets["Öğle"]!.add(e.mood);
      else if (h >= 17 && h <= 21) buckets["Akşam"]!.add(e.mood);
      else buckets["Gece"]!.add(e.mood);
    }

    double avg(List<int> arr) => arr.isEmpty ? 0 : arr.reduce((a, b) => a + b) / arr.length;

    return {
      "Sabah": avg(buckets["Sabah"]!),
      "Öğle": avg(buckets["Öğle"]!),
      "Akşam": avg(buckets["Akşam"]!),
      "Gece": avg(buckets["Gece"]!),
    };
  }

  /// Stabilite: standart sapma (daha düşük = daha stabil)
  double stabilityScore(List<MoodEntry> list) {
    if (list.length < 2) return 0;
    final mean = avgMood(list);
    final variance = list
        .map((e) => pow(e.mood - mean, 2).toDouble())
        .reduce((a, b) => a + b) / (list.length - 1);
    return sqrt(variance);
  }

  String stabilityLabel(double std) {
    if (std <= 0.6) return "Düşük Dalgalanma";
    if (std <= 1.1) return "Orta Dalgalanma";
    return "Yüksek Dalgalanma";
  }

  /// Streak: ardışık gün kaydı
  int currentStreak() {
    final daysWithEntry = _daysSet(entries);
    if (daysWithEntry.isEmpty) return 0;

    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    int streak = 0;

    while (daysWithEntry.contains(_key(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int longestStreak() {
    final days = _daysSet(entries).toList()..sort();
    if (days.isEmpty) return 0;

    int best = 1;
    int cur = 1;

    for (int i = 1; i < days.length; i++) {
      final prev = days[i - 1];
      final now = days[i];
      if (_isNextDay(prev, now)) {
        cur++;
        best = max(best, cur);
      } else {
        cur = 1;
      }
    }
    return best;
  }

  /// En iyi / en zor gün (son 7 gün için)
  MoodEntry? bestEntry(List<MoodEntry> list) {
    if (list.isEmpty) return null;
    list.sort((a, b) => b.mood.compareTo(a.mood));
    return list.first;
  }

  MoodEntry? worstEntry(List<MoodEntry> list) {
    if (list.isEmpty) return null;
    list.sort((a, b) => a.mood.compareTo(b.mood));
    return list.first;
  }

  /// Etiketlere göre ortalama
  Map<String, double> tagAverages(List<MoodEntry> list) {
    final map = <String, List<int>>{};
    for (final e in list) {
      for (final t in e.tags) {
        map.putIfAbsent(t, () => []);
        map[t]!.add(e.mood);
      }
    }

    final out = <String, double>{};
    map.forEach((k, v) {
      out[k] = v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    });

    // yüksekten düşüğe
    final sortedKeys = out.keys.toList()
      ..sort((a, b) => out[b]!.compareTo(out[a]!));
    return {for (final k in sortedKeys) k: out[k]!};
  }

  // --- helpers ---
  Set<int> _daysSet(List<MoodEntry> list) {
    final set = <int>{};
    for (final e in list) {
      set.add(_key(DateTime(e.time.year, e.time.month, e.time.day)));
    }
    return set;
  }

  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  bool _isNextDay(int prevKey, int nowKey) {
    // key -> DateTime dönüşmeden basit bir kontrol yapacağız:
    // en güvenlisi DateTime ile:
    DateTime toDate(int key) {
      final y = key ~/ 10000;
      final m = (key % 10000) ~/ 100;
      final d = key % 100;
      return DateTime(y, m, d);
    }

    final prev = toDate(prevKey);
    final now = toDate(nowKey);
    return now.difference(prev).inDays == 1;
  }
}
