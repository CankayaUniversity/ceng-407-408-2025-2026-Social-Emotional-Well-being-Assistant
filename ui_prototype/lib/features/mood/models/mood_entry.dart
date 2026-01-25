class MoodEntry {
  final DateTime time; // kayıt zamanı
  final int mood; // 1..5 (1=kötü, 5=harika)
  final String? note;
  final List<String> tags;

  const MoodEntry({
    required this.time,
    required this.mood,
    this.note,
    this.tags = const [],
  });
}
