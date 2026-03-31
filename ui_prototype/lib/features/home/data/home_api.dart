import 'dart:convert';
import '../../../core/api/api_client.dart';

class HomeApi {
  static Future<List<String>> getSelectedTabs() async {
    final res = await ApiClient.get("/home/preferences");
    if (res.statusCode != 200) throw Exception(res.body);

    final data = jsonDecode(res.body);
    final list = (data["selectedTabs"] ?? []) as List;
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> saveSelectedTabs(List<String> tabs) async {
    final res = await ApiClient.put("/home/preferences", {"selectedTabs": tabs});
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
