import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CurrentUser {
  final int id;
  final String username;

  CurrentUser({
    required this.id,
    required this.username,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      username: (json['username'] ?? json['name'] ?? json['email'] ?? 'unknown')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}

class TokenStore {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  // ===== TOKEN =====

  static Future<void> save(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, token);
  }

  static Future<String?> get() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
  }

  // İstersen yeni isimlerle de kullan
  static Future<void> saveToken(String token) async {
    await save(token);
  }

  static Future<String?> getToken() async {
    return get();
  }

  static Future<void> clearToken() async {
    await clear();
  }

  // ===== USER =====

  static Future<void> saveUser(CurrentUser user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<CurrentUser?> getUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_userKey);

    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CurrentUser.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<CurrentUser?> getCurrentUser() async {
    return getUser();
  }

  static Future<void> clearUser() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_userKey);
  }

  // ===== ALL =====

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
    await sp.remove(_userKey);
  }
}