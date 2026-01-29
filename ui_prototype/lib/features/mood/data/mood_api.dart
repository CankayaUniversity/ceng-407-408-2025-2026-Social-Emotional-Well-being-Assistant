import 'dart:convert';
import '../../core/api/api_client.dart';

class MoodApi {
  static Future<List<dynamic>> getMoodsByMonth(String yyyyMm) async {
    final res = await ApiClient.get("/home/moods?month=$yyyyMm");
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<void> upsertMood({
    required String entryDate,
    required int mood,
    String? note,
  }) async {
    final res = await ApiClient.post("/home/moods", {
      "entryDate": entryDate,
      "mood": mood,
      "note": note,
    });
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
