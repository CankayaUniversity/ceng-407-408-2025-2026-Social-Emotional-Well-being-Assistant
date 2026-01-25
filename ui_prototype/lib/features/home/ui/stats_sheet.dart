import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatsSheet {
  static void open({
    required BuildContext context,
    required DateTime day,
    required DateTime Function(DateTime) startOfWeek,
    required List<DateTime> Function(DateTime) daysOfWeek,
    required bool Function(DateTime) isDailyTargetCompleted,
    required double Function(DateTime) weeklySuccessRatio,
    required List<HabitStat> habits,
  }) {
    final weekStart = startOfWeek(day);
    final ratio = weeklySuccessRatio(day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  color: Colors.black.withOpacity(
                    theme.brightness == Brightness.dark ? 0.35 : 0.12,
                  ),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Grabber(),
                    const _Header(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Hafta: ${DateFormat("d MMM", "tr_TR").format(weekStart)} - "
                            "${DateFormat("d MMM", "tr_TR").format(weekStart.add(const Duration(days: 6)))}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _RingProgress(value: ratio),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WeeklyBadge(
                            day: day,
                            daysOfWeek: daysOfWeek,
                            isDailyTargetCompleted: isDailyTargetCompleted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Alışkanlıklarım",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...habits.map((h) => _HabitRow(h)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ================= UI ================= */

class HabitStat {
  final String title;
  final String emoji;
  final double ratio;

  HabitStat({
    required this.title,
    required this.emoji,
    required this.ratio,
  });
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
        ),
        Expanded(
          child: Text(
            "Alışkanlık Geçmişi",
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingProgress extends StatelessWidget {
  final double value;

  const _RingProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = (value * 100).round();

    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: _softBox(context),
      child: Column(
        children: [
          Text(
            "Başarı Oranı",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value.clamp(0, 1),
                  strokeWidth: 10,
                  backgroundColor: cs.outlineVariant.withOpacity(0.35),
                ),
                Text(
                  "%$pct",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBadge extends StatelessWidget {
  final DateTime day;
  final List<DateTime> Function(DateTime) daysOfWeek;
  final bool Function(DateTime) isDailyTargetCompleted;

  const _WeeklyBadge({
    required this.day,
    required this.daysOfWeek,
    required this.isDailyTargetCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final days = daysOfWeek(day);
    final doneDays = days.where(isDailyTargetCompleted).length;
    final badge = doneDays >= 4;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _softBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Haftalık Rozet",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                badge ? Icons.emoji_events_rounded : Icons.lock_rounded,
                color: badge
                    ? const Color(0xFFFFC107)
                    : cs.onSurfaceVariant.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  badge ? "Tebrikler! (4/7 gün)" : "Rozet için 4 gün hedef tamamla",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: days.map((d) {
              final ok = isDailyTargetCompleted(d);
              return Expanded(
                child: Container(
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: ok
                        ? const Color(0xFFFFC107)
                        : cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HabitStat stat;
  const _HabitRow(this.stat);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = (stat.ratio * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _softBox(context),
      child: Row(
        children: [
          Text(stat.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: stat.ratio.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "%$pct",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _softBox(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  final bg = isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest;
  final border = cs.outlineVariant.withOpacity(isDark ? 0.55 : 0.8);

  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 1),
  );
}
