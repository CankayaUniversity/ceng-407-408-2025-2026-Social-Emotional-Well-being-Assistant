import 'package:flutter/material.dart';
import '../home_habit_defs.dart';
import '../medicine/medicine_screen.dart';
import '../water/water_screen.dart';

class HabitRoutes {
  static Future<bool?> open(
      BuildContext context,
      HabitType type, {
        required DateTime day,
      }) {
    if (type == HabitType.medicine) {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => MedicineScreen(day: day)),
      );
    }

    if (type == HabitType.water) {
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => WaterScreen(day: day)),
      );
    }

    return Future.value(null);
  }
}
