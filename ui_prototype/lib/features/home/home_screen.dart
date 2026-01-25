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

  final Map<DateTime, Map<HabitType, HabitDayState>> _dayMap = {};

  DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    // ✅ açılışta bugünü Hive’dan çek
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDay(_focusedDay);
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _loadDay(DateTime day) async {
    final k = _key(day);
    if (_dayMap.containsKey(k)) return;

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
    if (_dayMap.containsKey(k)) return _dayMap[k]!;

    // (load gelmeden çağrılırsa) default üret
    final map = {for (final h in kHomeHabits) h.type: HabitDayState(type: h.type)};
    _dayMap[k] = map;

    // arka planda Hive’dan yükle
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
    final day = _selectedDay ?? _focusedDay;

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
    final day = _selectedDay ?? _focusedDay;
    final done = _doneCount(day);
    final total = kHomeHabits.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded),
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
          )
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),

            // ✅ gün seçince Hive’dan yükle
            onDaySelected: (s, f) async {
              setState(() {
                _selectedDay = s;
                _focusedDay = f;
              });
              await _loadDay(s);
              if (!mounted) return;
              setState(() {});
            },

            eventLoader: (d) =>
            _doneCount(d) == 0 ? [] : List.generate(_doneCount(d), (_) => "x"),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat("d MMMM, EEEE", "tr_TR").format(day),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Pill(
                      text: total == 0 ? "Boş gün" : "$done/$total",
                      icon: total == 0 ? Icons.event_busy_rounded : Icons.check_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: kHomeHabits.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
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
                const SizedBox(height: 14),
                SoftCard(
                  title: "Daily Summary",
                  subtitle: total == 0
                      ? "Bugün için alışkanlık yok."
                      : "Bugün $done tanesi tamamlandı, ${total - done} kaldı.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
