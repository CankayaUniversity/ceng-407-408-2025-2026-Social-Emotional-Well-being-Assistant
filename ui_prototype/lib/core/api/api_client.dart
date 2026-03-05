import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

class ApiClient {
  static const String baseUrl = "http://10.0.2.2:3001/api";

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final headers = <String, String>{};
    if (json) headers["Content-Type"] = "application/json";

    final token = await TokenStore.get();
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  static Future<http.Response> get(String path) async {
    final uri = Uri.parse("$baseUrl$path");
    return http.get(uri, headers: await _headers(json: false));
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse("$baseUrl$path");
    return http.post(uri, headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse("$baseUrl$path");
    return http.put(uri, headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path) async {
    final uri = Uri.parse("$baseUrl$path");
    return http.delete(uri, headers: await _headers(json: false));
  }
}
