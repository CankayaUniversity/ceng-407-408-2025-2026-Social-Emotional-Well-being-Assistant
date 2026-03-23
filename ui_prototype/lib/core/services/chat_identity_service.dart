import 'package:shared_preferences/shared_preferences.dart';

class ChatIdentity {
  final int userId;
  final String username;

  ChatIdentity({
    required this.userId,
    required this.username,
  });
}

class ChatIdentityService {
  static const String _userIdKey = 'community_chat_user_id';
  static const String _usernameKey = 'community_chat_username';

  static Future<ChatIdentity> getOrCreateIdentity() async {
    final prefs = await SharedPreferences.getInstance();

    final savedUserId = prefs.getInt(_userIdKey);
    final savedUsername = prefs.getString(_usernameKey);

    if (savedUserId != null &&
        savedUsername != null &&
        savedUsername.trim().isNotEmpty) {
      return ChatIdentity(
        userId: savedUserId,
        username: savedUsername,
      );
    }

    // TEST/DEMO için sabit kullanıcı:
    // İstersen bunları elle değiştir.
    const int fixedUserId = 423153;
    const String fixedUsername = 'anon_1071';

    await prefs.setInt(_userIdKey, fixedUserId);
    await prefs.setString(_usernameKey, fixedUsername);

    return ChatIdentity(
      userId: fixedUserId,
      username: fixedUsername,
    );
  }

  static Future<void> clearIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}