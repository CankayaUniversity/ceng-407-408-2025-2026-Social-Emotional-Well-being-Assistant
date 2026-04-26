import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../home_habit_defs.dart';
import '../medicine/medicine_models.dart';

class HomeStore {
  HomeStore._();
  static final HomeStore instance = HomeStore._();

  static const String _boxName = 'home_store_v1';
  Box? _box;

  int? _userId; // ✅ aktif kullanıcı

  /// Uygulama açılışında bir kez çağır (main veya splash)
  Future<void> init() async {
    await _ensureBoxOpen();
  }

  /// ✅ Login sonrası çağır: HomeStore.instance.setUser(userId)
  /// Not: Home local (Hive) olduğu için bu yeterli.
  Future<void> setUser(int userId) async {
    await _ensureBoxOpen();
    _userId = userId;
  }

  /// ✅ Logout sonrası çağır: HomeStore.instance.reset()
  /// Not: veriyi silmez, sadece aktif user bilgisini sıfırlar.
  void reset() {
    _userId = null;
  }

  /// (Geriye dönük uyum için) clearUser()
  void clearUser() => reset();

  Future<void> _ensureBoxOpen() async {
    if (_box != null && _box!.isOpen) return;

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  void _ensureUser() {
    if (_userId == null) {
      throw StateError(
        "HomeStore: userId set edilmemiş. Login sonrası HomeStore.instance.setUser(userId) çağırın.",
      );
    }
  }

  Box get _safeBox {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError("HomeStore: Box açık değil. Önce init() çağırın.");
    }
    return b;
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

  /// ✅ user’a özel key: u:<id>|<yyyy-mm-dd>
  String _userDayKey(DateTime day) {
    _ensureUser();
    return 'u:${_userId!}|${_dayKey(day)}';
  }

  String _medicineDayKey(DateTime day) {
    _ensureUser();
    return 'med:${_userId!}|${_dayKey(day)}';
  }

  List<MedicinePlan> readMedicinePlans(DateTime day) {
    final key = _medicineDayKey(day);
    final raw = _safeBox.get(key);

    if (raw == null || raw is! List) return [];

    try {
      return raw.map((m) => MedicinePlan.fromMap(m as Map)).toList();
    } catch (e) {
      print("[ERROR] Failed to read medicine plans: $e");
      return [];
    }
  }

  Future<void> writeMedicinePlans(DateTime day, List<MedicinePlan> plans) async {
    await _ensureBoxOpen();
    final key = _medicineDayKey(day);
    final raw = plans.map((p) => p.toMap()).toList();
    await _safeBox.put(key, raw);
  }

  /// Gün verisini okur: HabitType -> (done, time)
  Map<HabitType, ({bool done, TimeOfDay? time})> readDay(DateTime day) {
    final key = _userDayKey(day);
    final raw = _safeBox.get(key);

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
    await _ensureBoxOpen();
    final key = _userDayKey(day);

    final map = <String, Map<String, dynamic>>{};
    for (final e in data.entries) {
      map[_typeKey(e.key)] = {
        'done': e.value.done,
        'time': _timeToString(e.value.time),
      };
    }

    await _safeBox.put(key, map);
  }

  /// (Opsiyonel) Bu kullanıcıya ait tüm kayıtları temizle
  Future<void> clearAllForUser() async {
    await _ensureBoxOpen();
    _ensureUser();
    final prefix = 'u:${_userId!}|';
    final keysToDelete = _safeBox.keys
        .where((k) => k is String && k.startsWith(prefix))
        .toList();
    await _safeBox.deleteAll(keysToDelete);
  }
}
