import 'dart:convert';
import '../../../core/api/api_client.dart';

class EmergencyContactApi {
  static Future<List<dynamic>> list() async {
    final res = await ApiClient.get("/home/emergency-contacts");
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<void> add({
    required String name,
    String? phone,
    String? relation,
    bool isPrimary = true,
  }) async {
    final res = await ApiClient.post("/home/emergency-contacts", {
      "name": name,
      "phone": phone,
      "relation": relation,
      "isPrimary": isPrimary,
    });

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
}
