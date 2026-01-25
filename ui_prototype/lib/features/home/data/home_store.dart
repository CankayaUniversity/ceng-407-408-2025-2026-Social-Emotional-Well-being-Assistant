import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../home_habit_defs.dart';

class HomeStore {
  HomeStore._();
  static final HomeStore instance = HomeStore._();

  static const String _boxName = 'home_store_v1';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dayKey(DateTime d) {
    final dd = _strip(d);
    final y = dd.year.toString().padLeft(4, '0');
    final m = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _typeKey(HabitType t) => t.name;

  String? _timeToString(TimeOfDay? t) {
    if (t == null) return null;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay? _timeFromString(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Gün verisini okur:
  /// HabitType -> (done, time)
  Map<HabitType, ({bool done, TimeOfDay? time})> readDay(DateTime day) {
    final key = _dayKey(day);
    final raw = _box.get(key);

    // default (hiç kayıt yoksa)
    if (raw == null || raw is! Map) {
      return {
        for (final h in kHomeHabits) h.type: (done: false, time: null),
      };
    }

    final out = <HabitType, ({bool done, TimeOfDay? time})>{};

    for (final h in kHomeHabits) {
      final tk = _typeKey(h.type);
      final v = raw[tk];

      if (v is Map) {
        final done = (v['done'] == true);
        final time = _timeFromString(v['time'] as String?);
        out[h.type] = (done: done, time: time);
      } else {
        out[h.type] = (done: false, time: null);
      }
    }

    return out;
  }

  /// Gün verisini yazar
  Future<void> writeDay(
      DateTime day,
      Map<HabitType, ({bool done, TimeOfDay? time})> data,
      ) async {
    final key = _dayKey(day);

    final map = <String, Map<String, dynamic>>{};
    for (final e in data.entries) {
      map[_typeKey(e.key)] = {
        'done': e.value.done,
        'time': _timeToString(e.value.time),
      };
    }

    await _box.put(key, map);
  }
}
