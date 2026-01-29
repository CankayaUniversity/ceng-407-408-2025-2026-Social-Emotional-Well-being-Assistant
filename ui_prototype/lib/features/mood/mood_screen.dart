import 'dart:math';
import 'package:flutter/material.dart';

import 'data/mood_repository.dart';
import 'models/mood_models.dart';
import 'mood_theme_screen.dart';

import 'ui/mood_add_entry_sheet.dart';
import 'ui/mood_calendar_card.dart';
import 'ui/mood_distribution_card.dart';
import 'ui/mood_journal_card.dart';
import 'ui/mood_quick_selector.dart';

import 'ui/widgets/mood_card.dart';

class MoodScreen extends StatefulWidget {
  /// loginUsername/email veya userId string (Home'da kullandığınız userKey neyse onu verin)
  final String userKey;

  const MoodScreen({super.key, required this.userKey});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final repo = MoodRepository();

  DateTime focusedDay = dateOnly(DateTime.now());
  DateTime selectedDay = dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();

    // ✅ Default dolu gelmesin diye demo veriyi KALDIRDIK
    // repo.seedDemo();

    // ✅ User'a özel mood (kalıcı) yükle
    // Not: userKey'i login'den (email/username/userId) verin.
    Future.microtask(() async {
      await repo.bindUser(widget.userKey);
    });
  }

  Future<void> _addOrEditForSelectedDay() async {
    final existing = repo.entryOf(selectedDay);

    final entry = await MoodAddEntrySheet.open(
      context,
      day: selectedDay,
      existing: existing,
      palette: repo.palette,
    );

    if (!mounted) return;
    if (entry == null) return;

    repo.upsertEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mood kaydedildi")),
    );
  }

  // MoodType -> score (1..5)
  int _scoreOf(MoodType t) => t.index + 1;

  MoodType _typeFromScore(int score) {
    final i = (score - 1).clamp(0, MoodType.values.length - 1);
    return MoodType.values[i];
  }

  List<MoodEntry> _entriesOfMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final list = <MoodEntry>[];
    for (DateTime d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final e = repo.entryOf(dateOnly(d));
      if (e != null) list.add(e);
    }
    return list;
  }

  int _currentStreak() {
    int streak = 0;
    DateTime d = dateOnly(DateTime.now());
    while (true) {
      final e = repo.entryOf(d);
      if (e == null) break;
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreakInMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    int best = 0;
    int cur = 0;

    for (DateTime d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final e = repo.entryOf(dateOnly(d));
      if (e != null) {
        cur++;
        best = max(best, cur);
      } else {
        cur = 0;
      }
    }
    return best;
  }

  double _avgMood(List<MoodEntry> entries) {
    if (entries.isEmpty) return 0;
    final sum = entries.fold<double>(0, (p, e) => p + _scoreOf(e.mood).toDouble());
    return sum / entries.length;
  }

  double _stabilityStd(List<MoodEntry> entries) {
    if (entries.length < 2) return 0;
    final avg = _avgMood(entries);
    double v = 0;
    for (final e in entries) {
      final diff = _scoreOf(e.mood).toDouble() - avg;
      v += diff * diff;
    }
    v /= (entries.length - 1);
    return sqrt(v);
  }

  List<double> _weekdayAverages(DateTime month) {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    for (DateTime d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final e = repo.entryOf(dateOnly(d));
      if (e == null) continue;
      final wd = (d.weekday - 1) % 7;
      sums[wd] += _scoreOf(e.mood).toDouble();
      counts[wd] += 1;
    }

    return List<double>.generate(7, (i) => counts[i] == 0 ? 0 : sums[i] / counts[i]);
  }

  List<MoodEntry> _recentByScanning() {
    final out = <MoodEntry>[];
    DateTime d = dateOnly(DateTime.now());
    int guard = 0;

    while (out.length < 10 && guard < 120) {
      final e = repo.entryOf(d);
      if (e != null) out.add(e);
      d = d.subtract(const Duration(days: 1));
      guard++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood"),
        actions: [
          IconButton(
            tooltip: "Tema",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MoodThemeScreen(repo: repo)),
            ),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrEditForSelectedDay,
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: repo,
        builder: (context, _) {
          if (!repo.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final entry = repo.entryOf(selectedDay);
          final monthCounts = repo.monthCounts(focusedDay);

          final monthEntries = _entriesOfMonth(focusedDay);
          final avg = _avgMood(monthEntries);
          final std = _stabilityStd(monthEntries);
          final currentStreak = _currentStreak();
          final bestStreak = _bestStreakInMonth(focusedDay);
          final weekdayAvg = _weekdayAverages(focusedDay);
          final recent = _recentByScanning();

          // ✅ Bu ay hiç kayıt yok mu?
          final monthHasAny = monthEntries.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Quick Selector
              MoodQuickSelector(
                options: kMoodOptions,
                selected: entry?.mood,
                palette: repo.palette,
                onSelect: (t) {
                  final current = repo.entryOf(selectedDay);
                  repo.upsertEntry(
                    (current ??
                        MoodEntry(
                          day: selectedDay,
                          mood: t,
                          intensity: 3,
                          tags: const [],
                          title: "Bugün",
                          note: "",
                        ))
                        .copyWith(mood: t),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Calendar
              MoodCalendarCard(
                focusedDay: focusedDay,
                selectedDay: selectedDay,
                entryOf: repo.entryOf,
                onPageChanged: (d) {
                  if (!mounted) return;
                  setState(() => focusedDay = dateOnly(d));
                },
                onDaySelected: (selected, focused) {
                  if (!mounted) return;
                  setState(() {
                    selectedDay = dateOnly(selected);
                    focusedDay = dateOnly(focused);
                  });
                },
              ),
              const SizedBox(height: 14),

              // ✅ Kayıt yoksa: sadece boş state göster
              if (!monthHasAny) ...[
                MoodCard(
                  title: "Henüz kayıt yok",
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bu ay için mood kaydın bulunmuyor."),
                        SizedBox(height: 8),
                        Text("İlk kaydını sağ alttaki + ile ekleyebilirsin."),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Distribution
                MoodDistributionCard(
                  counts: monthCounts,
                  palette: repo.palette,
                ),
                const SizedBox(height: 14),

                // Haftalık Özet
                MoodCard(
                  title: "Haftalık Özet",
                  child: _WeeklyKpiRow(
                    entriesMonth: monthEntries,
                    avg: avg,
                    std: std,
                    scoreOf: _scoreOf,
                  ),
                ),
                const SizedBox(height: 14),

                // Trend
                MoodCard(
                  title: "Ruh Hali Trendi",
                  child: _MoodTrendLine(
                    entries: monthEntries,
                    scoreOf: _scoreOf,
                  ),
                ),
                const SizedBox(height: 14),

                // Haftanın Günleri
                MoodCard(
                  title: "Haftanın Günleri Ortalaması",
                  child: _WeekdayBars(
                    palette: repo.palette,
                    values: weekdayAvg,
                    typeFromScore: _typeFromScore,
                  ),
                ),
                const SizedBox(height: 14),

                // Seri
                MoodCard(
                  title: "Seri",
                  child: _StreakRow(current: currentStreak, best: bestStreak),
                ),
                const SizedBox(height: 14),

                // Journal
                MoodJournalCard(
                  entry: entry,
                  palette: repo.palette,
                  onEdit: _addOrEditForSelectedDay,
                  onDelete: () => repo.removeEntry(selectedDay),
                ),
                const SizedBox(height: 14),

                // Son Kayıtlar
                MoodCard(
                  title: "Son Kayıtlar",
                  child: _RecentList(
                    entries: recent,
                    palette: repo.palette,
                    onTap: (e) {
                      if (!mounted) return;
                      setState(() {
                        selectedDay = e.day;
                        focusedDay = dateOnly(DateTime(e.day.year, e.day.month, 1));
                      });
                      _addOrEditForSelectedDay();
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }
}

// =======================
// Widgets (same file)
// =======================

class _WeeklyKpiRow extends StatelessWidget {
  final List<MoodEntry> entriesMonth;
  final double avg;
  final double std;
  final int Function(MoodType) scoreOf;

  const _WeeklyKpiRow({
    required this.entriesMonth,
    required this.avg,
    required this.std,
    required this.scoreOf,
  });

  @override
  Widget build(BuildContext context) {
    final now = dateOnly(DateTime.now());

    final last7 = <MoodEntry>[];
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final found = entriesMonth.where((x) => x.day == d).toList();
      if (found.isNotEmpty) last7.add(found.first);
    }

    MoodEntry? best;
    MoodEntry? worst;
    for (final e in last7) {
      if (best == null || scoreOf(e.mood) > scoreOf(best!.mood)) best = e;
      if (worst == null || scoreOf(e.mood) < scoreOf(worst!.mood)) worst = e;
    }

    String stability;
    if (std <= 0.55) {
      stability = "Düşük";
    } else if (std <= 0.95) {
      stability = "Orta";
    } else {
      stability = "Yüksek";
    }

    return Row(
      children: [
        Expanded(child: _kpiTile("Ortalama", avg == 0 ? "-" : avg.toStringAsFixed(1))),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile("Stabilite", stability)),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile("En iyi", best == null ? "-" : "${scoreOf(best!.mood)}/5")),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile("En zor", worst == null ? "-" : "${scoreOf(worst!.mood)}/5")),
      ],
    );
  }

  Widget _kpiTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 12)),
        ],
      ),
    );
  }
}

class _MoodTrendLine extends StatelessWidget {
  final List<MoodEntry> entries;
  final int Function(MoodType) scoreOf;

  const _MoodTrendLine({required this.entries, required this.scoreOf});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Text("Bu ay için veri yok."),
      );
    }

    final sorted = [...entries]..sort((a, b) => a.day.compareTo(b.day));
    final values = sorted.map((e) => scoreOf(e.mood).toDouble()).toList();

    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _LinePainter(values: values),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  _LinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.04);
    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dot = Paint()..color = Colors.black.withValues(alpha: 0.8);

    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, bg);

    for (int i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.isEmpty) return;

    const minV = 1.0, maxV = 5.0;
    double normY(double v) => size.height - ((v - minV) / (maxV - minV)) * size.height;

    if (values.length == 1) {
      canvas.drawCircle(Offset(size.width * 0.5, normY(values.first)), 3.2, dot);
      return;
    }

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = normY(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = ((i - 1) / (values.length - 1)) * size.width;
        final prevY = normY(values[i - 1]);
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    canvas.drawPath(path, line);

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = normY(values[i]);
      canvas.drawCircle(Offset(x, y), 3.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.values != values;
}

class _WeekdayBars extends StatelessWidget {
  final MoodPalette palette;
  final List<double> values;
  final MoodType Function(int) typeFromScore;

  const _WeekdayBars({
    required this.palette,
    required this.values,
    required this.typeFromScore,
  });

  @override
  Widget build(BuildContext context) {
    const names = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = values[i];

          final barMax = 105.0;
          final barMin = 8.0;
          final h = (v == 0) ? barMin : (v / 5.0) * barMax;

          final approxScore = (v == 0 ? 3 : v.round()).clamp(1, 5);
          final approxType = typeFromScore(approxScore);
          final color = palette.colorOf(approxType).withValues(alpha: 0.9);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  names[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final int current;
  final int best;

  const _StreakRow({required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _box("Mevcut", "$current gün")),
        const SizedBox(width: 10),
        Expanded(child: _box("En Uzun", "$best gün")),
      ],
    );
  }

  Widget _box(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<MoodEntry> entries;
  final MoodPalette palette;
  final void Function(MoodEntry e) onTap;

  const _RecentList({
    required this.entries,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("Henüz kayıt yok."),
      );
    }

    return Column(
      children: [
        for (final e in entries)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: palette.colorOf(e.mood),
              child: Text(optionOf(e.mood).emoji),
            ),
            title: Text("${e.day.day.toString().padLeft(2, '0')} "
                "${_monthNameTr(e.day.month)}, ${e.day.year}"),
            subtitle: Text(optionOf(e.mood).labelTr),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(e),
          ),
      ],
    );
  }

  static String _monthNameTr(int m) {
    const names = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık"
    ];
    return names[m - 1];
  }
}
