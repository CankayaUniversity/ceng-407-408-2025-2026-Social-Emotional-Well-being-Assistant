import 'package:flutter/foundation.dart';
import 'mood_api.dart';

class MoodStore extends ChangeNotifier {
  bool loading = false;
  List<dynamic> entries = [];

  Future<void> loadMonth(String yyyyMm) async {
    loading = true;
    notifyListeners();
    try {
      entries = await MoodApi.getMoodsByMonth(yyyyMm);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveMood({
    required String entryDate,
    required int mood,
    String? note,
    required String currentMonth,
  }) async {
    await MoodApi.upsertMood(entryDate: entryDate, mood: mood, note: note);
    await loadMonth(currentMonth); // kaydedince yeniden çek
  }

  void reset() {
    loading = false;
    entries = [];
    notifyListeners();
  }
}
