import 'package:flutter/material.dart';

class MoodPalette {
  // 1..5 renkleri (kırmızı → yeşil)
  static const Map<int, Color> moodColors = {
    1: Color(0xFFE74C3C),
    2: Color(0xFFF39C12),
    3: Color(0xFFF1C40F),
    4: Color(0xFF9CCC65),
    5: Color(0xFF43A047),
  };

  static const Map<int, String> moodLabel = {
    1: "Berbat",
    2: "Kötü",
    3: "Normal",
    4: "İyi",
    5: "Harika",
  };

  static const Map<int, String> moodEmoji = {
    1: "😡",
    2: "🙁",
    3: "😐",
    4: "🙂",
    5: "😊",
  };

  static Color colorOf(int mood) => moodColors[mood] ?? Colors.grey;
  static String emojiOf(int mood) => moodEmoji[mood] ?? "🙂";
  static String labelOf(int mood) => moodLabel[mood] ?? "İyi";
}
