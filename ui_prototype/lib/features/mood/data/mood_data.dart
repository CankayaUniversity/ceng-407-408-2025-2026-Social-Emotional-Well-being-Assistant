import '../models/mood_entry.dart';

class MoodRepository {
  /// Demo amaçlı: son 30 gün için örnek kayıt üretir.
  /// Gerçek projede burayı SQLite/Firestore/REST ile değiştirirsin.
  List<MoodEntry> getDemoEntries() {
    final now = DateTime.now();
    final List<MoodEntry> out = [];

    // Her gün 1 kayıt (bazı günler boş) + bazen ekstra akşam kaydı
    for (int i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));

      // bazı günler kayıt yok
      if (i % 9 == 0) continue;

      final mood = _moodByPattern(i);
      out.add(MoodEntry(
        time: day.add(const Duration(hours: 12, minutes: 30)),
        mood: mood,
        note: i % 5 == 0 ? "Bugün biraz yoğun geçti." : null,
        tags: _tagsByPattern(i),
      ));

      // bazen ikinci kayıt
      if (i % 6 == 0) {
        out.add(MoodEntry(
          time: day.add(const Duration(hours: 21, minutes: 10)),
          mood: (mood - 1).clamp(1, 5),
          note: "Akşam",
          tags: const ["Uyku"],
        ));
      }
    }

    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  int _moodByPattern(int i) {
    // hafif dalgalı pattern
    final base = 3;
    final wave = (i % 10 <= 2) ? 1 : (i % 10 >= 7 ? -1 : 0);
    final extra = (i % 4 == 0) ? 1 : 0;
    return (base + wave + extra).clamp(1, 5);
  }

  List<String> _tagsByPattern(int i) {
    final tags = <String>[];
    if (i % 2 == 0) tags.add("İş/Okul");
    if (i % 3 == 0) tags.add("Spor");
    if (i % 4 == 0) tags.add("Sosyal");
    if (i % 5 == 0) tags.add("Uyku");
    return tags;
  }
}
