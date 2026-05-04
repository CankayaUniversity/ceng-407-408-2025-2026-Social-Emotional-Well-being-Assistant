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
    const navy = Color(0xFF2B3A67);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: navy.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            offset: const Offset(0, 8),
            color: navy.withOpacity(0.05),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                "Takvim",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
              const Spacer(),
              Text(
                _monthLabel(focusedDay).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: navy.withOpacity(0.4),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TableCalendar(
            firstDay: DateTime.utc(2010, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: dateOnly(focusedDay),
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(day, dateOnly(selectedDay)),
            onDaySelected: (sel, foc) => onDaySelected(dateOnly(sel), dateOnly(foc)),
            onPageChanged: (foc) => onPageChanged(dateOnly(foc)),
            rowHeight: 50,
            daysOfWeekHeight: 30,
            headerVisible: false,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontWeight: FontWeight.bold, color: navy.withOpacity(0.3), fontSize: 12),
              weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: navy.withOpacity(0.3), fontSize: 12),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              selectedDecoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: navy.withOpacity(0.1), shape: BoxShape.circle),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              todayTextStyle: const TextStyle(color: navy, fontWeight: FontWeight.bold),
              defaultTextStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
              weekendTextStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final entry = entryOf(dateOnly(day));
                if (entry == null) return null;
                return Positioned(
                  bottom: 6,
                  child: Text(optionOf(entry.mood).emoji, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
    ];
    return "${months[d.month - 1]} ${d.year}";
  }
}
