import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  // Android Emulator: PC'deki localhost'a ulaşmak için 10.0.2.2 kullanılır
  static const String baseUrl = "http://10.0.2.2:3001/api";

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/auth/login");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data; // { message, token, user }
    } else {
      throw Exception(data["message"] ?? "Login failed");
    }
  }
}
