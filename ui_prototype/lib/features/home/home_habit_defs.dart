import 'package:flutter/material.dart';

enum HabitType { water, medicine, exercise, shower, read }

class HabitDef {
  final HabitType type;
  final String title;
  final String emoji;
  final Color color;

  const HabitDef({
    required this.type,
    required this.title,
    required this.emoji,
    required this.color,
  });
}

const List<HabitDef> kHomeHabits = [
  HabitDef(
    type: HabitType.read,
    title: "Bir şeyler oku",
    emoji: "📚",
    color: Color(0xFFFFC107),
  ),
  HabitDef(
    type: HabitType.water,
    title: "Su iç",
    emoji: "💧",
    color: Color(0xFF3B82F6),
  ),
  HabitDef(
    type: HabitType.medicine,
    title: "Takviye al",
    emoji: "💊",
    color: Color(0xFFF97316),
  ),
  HabitDef(
    type: HabitType.exercise,
    title: "Egzersiz yap",
    emoji: "🏋️‍♂️",
    color: Color(0xFF22C55E),
  ),
  HabitDef(
    type: HabitType.shower,
    title: "Duş al",
    emoji: "🚿",
    color: Color(0xFFA855F7),
  ),
];
