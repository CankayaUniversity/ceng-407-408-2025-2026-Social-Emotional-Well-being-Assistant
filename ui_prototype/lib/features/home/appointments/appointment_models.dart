import 'package:flutter/material.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKeyOf(DateTime d) {
  final dd = dateOnly(d);
  final y = dd.year.toString().padLeft(4, '0');
  final m = dd.month.toString().padLeft(2, '0');
  final day = dd.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

TimeOfDay? timeFromHHmm(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String timeToHHmm(TimeOfDay t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

DateTime dayFromKey(String? s, {DateTime? fallback}) {
  if (s == null || s.isEmpty) return fallback ?? DateTime.now();
  final parts = s.split('-');
  if (parts.length != 3) return fallback ?? DateTime.now();
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return fallback ?? DateTime.now();
  return DateTime(y, m, d);
}

class AppointmentEntry {
  final String id;
  final DateTime day;
  final String timeHHmm;
  final String doctorName;
  final String department;
  final String? hospital;
  final String? location;
  final String? type;
  final String? note;

  AppointmentEntry({
    required this.id,
    required this.day,
    required this.timeHHmm,
    required this.doctorName,
    required this.department,
    this.hospital,
    this.location,
    this.type,
    this.note,
  });

  TimeOfDay? get timeOfDay => timeFromHHmm(timeHHmm);

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': dayKeyOf(day),
        'timeHHmm': timeHHmm,
        'doctorName': doctorName,
        'department': department,
        'hospital': hospital,
        'location': location,
        'type': type,
        'note': note,
      };

  factory AppointmentEntry.fromMap(Map<dynamic, dynamic> map, {DateTime? fallbackDay}) {
    final day = dayFromKey(map['day'] as String?, fallback: fallbackDay);
    return AppointmentEntry(
      id: (map['id'] ?? '').toString(),
      day: dateOnly(day),
      timeHHmm: (map['timeHHmm'] ?? '').toString(),
      doctorName: (map['doctorName'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      hospital: map['hospital']?.toString(),
      location: map['location']?.toString(),
      type: map['type']?.toString(),
      note: map['note']?.toString(),
    );
  }
}

