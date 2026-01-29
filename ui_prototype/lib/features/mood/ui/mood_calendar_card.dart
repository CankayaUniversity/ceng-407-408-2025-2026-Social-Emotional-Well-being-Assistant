import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ui_prototype/features/mood/models/mood_models.dart';

class MoodCalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;

  final MoodEntry? Function(DateTime day) entryOf;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  const MoodCalendarCard({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.entryOf,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;

    final accent = cs.primary;
    final palette = kDefaultMoodPalette;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            cs.surface.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.95),
                      accent.withValues(alpha: 0.65),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Takvim",
                style: base.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              _FancyPill(
                text: _monthLabel(focusedDay),
                accent: accent,
                textColor: cs.onSurface,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          TableCalendar(
            firstDay: DateTime.utc(2010, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: dateOnly(focusedDay),
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(day, dateOnly(selectedDay)),

            onDaySelected: (sel, foc) => onDaySelected(dateOnly(sel), dateOnly(foc)),
            onPageChanged: (foc) => onPageChanged(dateOnly(foc)),

            // ✅ CRASH FIX: hücre yüksekliği büyütüldü
            rowHeight: 66,
            daysOfWeekHeight: 28,

            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              leftChevronIcon: Icon(Icons.chevron_left, color: accent),
              rightChevronIcon: Icon(Icons.chevron_right, color: accent),
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
              headerPadding: const EdgeInsets.only(bottom: 8),
            ),

            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B6B6B),
              ),
              weekendStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B6B6B),
              ),
            ),

            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              // biraz küçülttük ki rahat sığsın
              cellMargin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              todayDecoration: const BoxDecoration(shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(shape: BoxShape.circle),
            ),

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, foc) => _emojiDayCell(
                day: day,
                palette: palette,
                accent: accent,
                entry: entryOf(dateOnly(day)),
                isSelected: false,
                isToday: isSameDay(day, DateTime.now()),
              ),
              todayBuilder: (context, day, foc) => _emojiDayCell(
                day: day,
                palette: palette,
                accent: accent,
                entry: entryOf(dateOnly(day)),
                isSelected: false,
                isToday: true,
              ),
              selectedBuilder: (context, day, foc) => _emojiDayCell(
                day: day,
                palette: palette,
                accent: accent,
                entry: entryOf(dateOnly(day)),
                isSelected: true,
                isToday: isSameDay(day, DateTime.now()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiDayCell({
    required DateTime day,
    required MoodPalette palette,
    required Color accent,
    required MoodEntry? entry,
    required bool isSelected,
    required bool isToday,
  }) {
    final has = entry != null;

    final Color fill = has
        ? palette.colorOf(entry!.mood).withValues(alpha: 0.90)
        : Colors.black.withValues(alpha: 0.07);

    final Color border = isSelected
        ? accent.withValues(alpha: 0.95)
        : isToday
        ? accent.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.14);

    final Color ring = isSelected
        ? accent.withValues(alpha: 0.22)
        : isToday
        ? accent.withValues(alpha: 0.14)
        : Colors.transparent;

    final String emoji = has ? optionOf(entry!.mood).emoji : "";

    final Color dayTextColor = isToday
        ? accent.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.65);

    // ✅ Hücreyi sabitle -> overflow yok
    return SizedBox(
      height: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ring,
            ),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(
                  color: border,
                  width: (isSelected || isToday) ? 1.8 : 1.2,
                ),
                boxShadow: has
                    ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : null,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${day.day}",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              color: dayTextColor,
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
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
      "Aralık",
    ];
    return months[d.month - 1];
  }
}

class _FancyPill extends StatelessWidget {
  final String text;
  final Color accent;
  final Color textColor;

  const _FancyPill({
    required this.text,
    required this.accent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
