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
  const MoodScreen({super.key});

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
    repo.seedDemo();
  }

  Future<void> _addOrEditForSelectedDay() async {
    final existing = repo.entryOf(selectedDay);

    final entry = await MoodAddEntrySheet.open(
      context,
      day: selectedDay,
      existing: existing,
      palette: repo.palette, // ✅ senin sheet zorunlu istiyor
    );

    if (!mounted) return;
    if (entry == null) return;

    repo.upsertEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mood kaydedildi (prototype)")),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood"),
        actions: [
          IconButton(
            tooltip: "Tema",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MoodThemeScreen(repo: repo)), // ✅ repo zorunlu
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
          final entry = repo.entryOf(selectedDay);
          final monthCounts = repo.monthCounts(focusedDay);

          final monthEntries = _entriesOfMonth(focusedDay);
          final avg = _avgMood(monthEntries);
          final std = _stabilityStd(monthEntries);
          final currentStreak = _currentStreak();
          final bestStreak = _bestStreakInMonth(focusedDay);
          final weekdayAvg = _weekdayAverages(focusedDay);
          final recent = _recentByScanning();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Quick Selector (senin API)
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

              MoodDistributionCard(
                counts: monthCounts,
                palette: repo.palette,
              ),
              const SizedBox(height: 14),

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

              MoodCard(
                title: "Ruh Hali Trendi",
                child: _MoodTrendLine(
                  entries: monthEntries,
                  scoreOf: _scoreOf,
                ),
              ),
              const SizedBox(height: 14),

              MoodCard(
                title: "Haftanın Günleri Ortalaması",
                child: _WeekdayBars(
                  palette: repo.palette,
                  values: weekdayAvg,
                  typeFromScore: _typeFromScore,
                ),
              ),
              const SizedBox(height: 14),

              MoodCard(
                title: "Seri",
                child: _StreakRow(current: currentStreak, best: bestStreak),
              ),
              const SizedBox(height: 14),

              MoodJournalCard(
                entry: entry,
                palette: repo.palette,
                onEdit: _addOrEditForSelectedDay,
                onDelete: () => repo.removeEntry(selectedDay),
              ),
              const SizedBox(height: 14),

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

              // küçük debug satırı (darkta görünür)
              Text(
                "Theme: ${Theme.of(context).brightness.name}",
                style: TextStyle(color: cs.onSurface.withOpacity(0.55), fontSize: 12),
              ),
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
    final cs = Theme.of(context).colorScheme;

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
        Expanded(child: _kpiTile(context, "Ortalama", avg == 0 ? "-" : avg.toStringAsFixed(1))),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile(context, "Stabilite", stability)),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile(context, "En iyi", best == null ? "-" : "${scoreOf(best!.mood)}/5")),
        const SizedBox(width: 10),
        Expanded(child: _kpiTile(context, "En zor", worst == null ? "-" : "${scoreOf(worst!.mood)}/5")),
      ],
    );
  }

  Widget _kpiTile(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // ✅ eskiden Colors.black... idi
        color: cs.onSurface.withOpacity(0.06),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: cs.onSurface.withOpacity(0.60), fontSize: 12),
          ),
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
    final cs = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          "Bu ay için veri yok.",
          style: TextStyle(color: cs.onSurface.withOpacity(0.70)),
        ),
      );
    }

    final sorted = [...entries]..sort((a, b) => a.day.compareTo(b.day));
    final values = sorted.map((e) => scoreOf(e.mood).toDouble()).toList();

    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _LinePainter(values: values, cs: cs), // ✅ theme aware
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final ColorScheme cs;

  _LinePainter({required this.values, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = cs.onSurface.withOpacity(0.06);
    final grid = Paint()
      ..color = cs.onSurface.withOpacity(0.10)
      ..strokeWidth = 1;

    final line = Paint()
      ..color = cs.onSurface.withOpacity(0.80)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dot = Paint()..color = cs.onSurface.withOpacity(0.85);

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

class _HeatMapMini extends StatelessWidget {
  final DateTime month;
  final MoodEntry? Function(DateTime) entryOf;
  final MoodPalette palette;

  const _HeatMapMini({
    required this.month,
    required this.entryOf,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final days = end.difference(start).inDays;
    final firstWeekday = start.weekday; // 1..7
    final leadingEmpty = firstWeekday - 1;

    final totalCells = leadingEmpty + days;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _weekdayLabels(cs),
        const SizedBox(height: 10),
        Column(
          children: List.generate(rows, (r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: List.generate(7, (c) {
                  final idx = r * 7 + c;
                  final dayNum = idx - leadingEmpty + 1;
                  if (dayNum < 1 || dayNum > days) {
                    return _cell(cs, null);
                  }

                  final d = dateOnly(DateTime(month.year, month.month, dayNum));
                  final e = entryOf(d);
                  return _cell(cs, e);
                }),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _weekdayLabels(ColorScheme cs) {
    const names = ["P", "S", "Ç", "P", "C", "C", "P"];
    return Row(
      children: names
          .map((t) => Expanded(
        child: Center(
          child: Text(
            t,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.50),
            ),
          ),
        ),
      ))
          .toList(),
    );
  }

  Widget _cell(ColorScheme cs, MoodEntry? e) {
    final bool has = e != null;

    final Color fill = has
        ? palette.colorOf(e!.mood).withValues(alpha: 0.90)
        : cs.onSurface.withOpacity(0.08);

    final Color border = has
        ? palette.colorOf(e!.mood).withValues(alpha: 0.55)
        : cs.onSurface.withOpacity(0.14);

    final String emoji = has ? optionOf(e!.mood).emoji : "";

    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.2),
              boxShadow: has
                  ? [
                BoxShadow(
                  color: cs.onSurface.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
                  : null,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayBars extends StatelessWidget {
  final MoodPalette palette;
  final List<double> values; // 0..6
  final MoodType Function(int) typeFromScore;

  const _WeekdayBars({
    required this.palette,
    required this.values,
    required this.typeFromScore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                  height: h,
                  width: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      names[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
        Expanded(child: _tile(context, "Mevcut Seri", "🔥 $current gün")),
        const SizedBox(width: 10),
        Expanded(child: _tile(context, "En Uzun Seri", "🏆 $best gün")),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.onSurface.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: cs.onSurface.withOpacity(0.60), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<MoodEntry> entries;
  final MoodPalette palette;
  final void Function(MoodEntry) onTap;

  const _RecentList({
    required this.entries,
    required this.palette,
    required this.onTap,
  });

  String _fmt(DateTime d) {
    const months = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    return "${d.day.toString().padLeft(2, "0")} ${months[d.month - 1]}, ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Henüz kayıt yok.",
          style: TextStyle(color: cs.onSurface.withOpacity(0.70)),
        ),
      );
    }

    return Column(
      children: entries.map((e) {
        final c = palette.colorOf(e.mood);

        return InkWell(
          onTap: () => onTap(e),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.withValues(alpha: 0.35)),
                  ),
                  child: Center(
                    child: Text(optionOf(e.mood).emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmt(e.day),
                        style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.title.isEmpty ? "Kayıt" : e.title,
                        style: TextStyle(color: cs.onSurface.withOpacity(0.60), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.40)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
