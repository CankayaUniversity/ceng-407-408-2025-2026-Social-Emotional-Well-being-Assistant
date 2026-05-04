import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'medicine/medicine_screen.dart';
import 'water/water_screen.dart';

import 'home_habit_defs.dart';
import 'home_habit_card.dart';

import 'ui/soft_card.dart';
import 'ui/pill.dart';
import 'ui/stats_sheet.dart';

import 'data/home_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class HabitDayState {
  final HabitType type;
  bool done;
  TimeOfDay? time;

  HabitDayState({required this.type, this.done = false, this.time});
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  /// Gün -> HabitType -> state
  final Map<DateTime, Map<HabitType, HabitDayState>> _dayMap = {};

  /// ✅ Bu gün Hive’dan gerçekten yüklendi mi?
  final Set<DateTime> _loadedDays = {};

  DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();

    // ✅ açılışta bugünü Hive’dan çek
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final today = _key(DateTime.now());
      _selectedDay = today;
      _focusedDay = today;

      await _loadDay(today);

      if (!mounted) return;
      setState(() {});
    });
  }

  /// ✅ Gün verisini Hive’dan yükle (default map koyulmuş olsa bile YÜKLEYECEK)
  Future<void> _loadDay(DateTime day) async {
    final k = _key(day);

    // ✅ Daha önce Hive’dan yüklendiyse tekrar okuma (performans)
    if (_loadedDays.contains(k)) return;

    final data = HomeStore.instance.readDay(k);

    final map = <HabitType, HabitDayState>{
      for (final h in kHomeHabits)
        h.type: HabitDayState(
          type: h.type,
          done: data[h.type]?.done ?? false,
          time: data[h.type]?.time,
        ),
    };

    _dayMap[k] = map;
    _loadedDays.add(k);
  }

  Future<void> _saveDay(DateTime day) async {
    final k = _key(day);
    final map = _dayMap[k];
    if (map == null) return;

    final data = <HabitType, ({bool done, TimeOfDay? time})>{
      for (final e in map.entries)
        e.key: (done: e.value.done, time: e.value.time),
    };

    await HomeStore.instance.writeDay(k, data);
  }

  Map<HabitType, HabitDayState> _stateOf(DateTime day) {
    final k = _key(day);

    // varsa direkt dön
    if (_dayMap.containsKey(k)) return _dayMap[k]!;

    // ✅ (Henüz yüklenmediyse) default üret
    final map = {for (final h in kHomeHabits) h.type: HabitDayState(type: h.type)};
    _dayMap[k] = map;

    // ✅ ÖNEMLİ: _loadedDays’e ekleme! çünkü bu default, Hive’dan yüklenmedi.
    // Arka planda Hive’dan gerçek datayı yükle
    _loadDay(k).then((_) {
      if (!mounted) return;
      setState(() {});
    });

    return map;
  }

  int _doneCount(DateTime day) => _stateOf(day).values.where((e) => e.done).length;

  bool _dailyCompleted(DateTime day) =>
      _doneCount(day) == kHomeHabits.length && kHomeHabits.isNotEmpty;

  DateTime _weekStart(DateTime d) => _key(d).subtract(Duration(days: (d.weekday + 6) % 7));

  List<DateTime> _weekDays(DateTime d) =>
      List.generate(7, (i) => _weekStart(d).add(Duration(days: i)));

  double _weeklyRatio(DateTime d) {
    final total = kHomeHabits.length * 7;
    if (total == 0) return 0;
    int done = 0;
    for (final day in _weekDays(d)) {
      done += _doneCount(day);
    }
    return done / total;
  }

  double _weeklyHabitRatio(DateTime d, HabitType t) {
    int c = 0;
    for (final day in _weekDays(d)) {
      if (_stateOf(day)[t]?.done == true) c++;
    }
    return c / 7;
  }

  Future<void> _openAndApply({
    required DateTime day,
    required HabitType type,
    required Widget screen,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (result == null) return;

    setState(() => _stateOf(day)[type]!.done = result);
    await _saveDay(day);
  }

  Future<void> _onHabitTap(HabitType type) async {
    final day = _key(_selectedDay ?? _focusedDay);

    // ✅ Önce o günü garanti yükle
    await _loadDay(day);

    // ✅ Takviye
    if (type == HabitType.medicine) {
      await _openAndApply(
        day: day,
        type: type,
        screen: MedicineScreen(day: day),
      );
      return;
    }

    // ✅ Su
    if (type == HabitType.water) {
      await _openAndApply(
        day: day,
        type: type,
        screen: WaterScreen(day: day),
      );
      return;
    }

    // ✅ diğerleri: toggle
    setState(() => _stateOf(day)[type]!.done = !_stateOf(day)[type]!.done);
    await _saveDay(day);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const mint = Color(0xFFD6E5E3);
    const lightGrey = Color(0xFFE5E5E5);
    const gold = Color(0xFFFFE6A7);

    final day = _key(_selectedDay ?? _focusedDay);
    final done = _doneCount(day);
    final total = kHomeHabits.length;
    final double percent = total == 0 ? 0 : (done / total);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Home", style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: gold),
            onPressed: () {
              StatsSheet.open(
                context: context,
                day: day,
                startOfWeek: _weekStart,
                daysOfWeek: _weekDays,
                isDailyTargetCompleted: _dailyCompleted,
                weeklySuccessRatio: _weeklyRatio,
                habits: kHomeHabits
                    .map((h) => HabitStat(
                  title: h.title,
                  emoji: h.emoji,
                  ratio: _weeklyHabitRatio(day, h.type),
                ))
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Label and Horizontal Picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  DateFormat("MMMM yyyy", "tr_TR").format(_focusedDay),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: navy),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: navy),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                    });
                  },
                ),
              ],
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            headerVisible: false,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: navy, fontWeight: FontWeight.bold),
              weekendStyle: TextStyle(color: navy, fontWeight: FontWeight.bold),
            ),
            calendarStyle: CalendarStyle(
              isTodayHighlighted: false,
              selectedDecoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
              defaultDecoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              weekendDecoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              defaultTextStyle: const TextStyle(color: navy, fontWeight: FontWeight.bold),
              weekendTextStyle: const TextStyle(color: navy, fontWeight: FontWeight.bold),
              markersMaxCount: 5,
              markerDecoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
            ),
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            onDaySelected: (s, f) async {
              final selected = _key(s);
              setState(() {
                _selectedDay = selected;
                _focusedDay = f;
              });
              await _loadDay(selected);
              if (!mounted) return;
              setState(() {});
            },
            onPageChanged: (f) {
              setState(() {
                _focusedDay = f;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final count = _doneCount(date);
                if (count == 0) return const SizedBox.shrink();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    count,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: navy,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Progress Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: navy.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(Icons.eco_rounded, size: 100, color: Colors.white.withOpacity(0.1)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "GÜNLÜK İLERLEME",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "%${(percent * 100).toInt()}",
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Bugün $done/$total alışkanlık tamamlandı.",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: kHomeHabits.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (_, i) {
                    final h = kHomeHabits[i];
                    final st = _stateOf(day)[h.type]!;
                    return HomeHabitCard(
                      title: h.title,
                      emoji: h.emoji,
                      color: h.color,
                      done: st.done,
                      timeText: st.time?.format(context),
                      onTap: () => _onHabitTap(h.type),
                      onLongPress: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: st.time ?? TimeOfDay.now(),
                        );
                        if (t != null) {
                          setState(() => st.time = t);
                          await _saveDay(day);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
