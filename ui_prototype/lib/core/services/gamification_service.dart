import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum BadgeType {
  consistency7Days, // 7 Günlük İstikrar
  moodExplorer,     // Duygu Kaşifi
  deepChat,          // Derin Sohbet
  socialButterfly,   // Sosyal Kelebek
}

class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _badgesKey = 'user_badges';
  static const String _moodHistoryKey = 'mood_history_dates';
  static const String _uniqueMoodsKey = 'unique_moods_recorded';
  static const String _aiChatCountKey = 'ai_chat_message_count';
  static const String _hasJoinedRoomKey = 'has_joined_community_room';
  static const String _hasClickedEventKey = 'has_clicked_event';

  Future<List<String>> getEarnedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_badgesKey) ?? [];
  }

  Future<void> _awardBadge(BadgeType type) async {
    final prefs = await SharedPreferences.getInstance();
    final badges = prefs.getStringList(_badgesKey) ?? [];
    final badgeName = type.name;

    if (!badges.contains(badgeName)) {
      badges.add(badgeName);
      await prefs.setStringList(_badgesKey, badges);
      debugPrint('Badge Awarded: $badgeName');
      notifyListeners();
    }
  }

  // 1. 7 Günlük İstikrar
  Future<void> recordMoodEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    final history = prefs.getStringList(_moodHistoryKey) ?? [];
    if (!history.contains(today)) {
      history.add(today);
      // Keep last 10 entries for simplicity
      if (history.length > 10) history.removeAt(0);
      await prefs.setStringList(_moodHistoryKey, history);
    }

    if (_check7DayConsistency(history)) {
      await _awardBadge(BadgeType.consistency7Days);
    }
  }

  bool _check7DayConsistency(List<String> history) {
    if (history.length < 7) return false;

    // Sort and check for 7 consecutive days
    final dates = history.map((e) => DateTime.parse(e)).toList()..sort();
    int consecutive = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i+1].difference(dates[i]).inDays == 1) {
        consecutive++;
        if (consecutive >= 7) return true;
      } else if (dates[i+1].difference(dates[i]).inDays > 1) {
        consecutive = 1;
      }
    }
    return false;
  }

  // 2. Duygu Kaşifi
  Future<void> recordMoodType(int moodScore) async {
    final prefs = await SharedPreferences.getInstance();
    final uniqueMoods = prefs.getStringList(_uniqueMoodsKey) ?? [];
    final scoreStr = moodScore.toString();

    if (!uniqueMoods.contains(scoreStr)) {
      uniqueMoods.add(scoreStr);
      await prefs.setStringList(_uniqueMoodsKey, uniqueMoods);
    }

    if (uniqueMoods.length >= 5) {
      await _awardBadge(BadgeType.moodExplorer);
    }
  }

  // 3. Derin Sohbet
  Future<void> recordAiChatMessage() async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_aiChatCountKey) ?? 0;
    count++;
    await prefs.setInt(_aiChatCountKey, count);

    if (count >= 10) {
      await _awardBadge(BadgeType.deepChat);
    }
  }

  Future<void> resetAiChatCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aiChatCountKey);
  }

  // 4. Sosyal Kelebek
  Future<void> recordRoomJoin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasJoinedRoomKey, true);
    _checkSocialButterfly(prefs);
  }

  Future<void> recordEventClick() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasClickedEventKey, true);
    _checkSocialButterfly(prefs);
  }

  Future<void> _checkSocialButterfly(SharedPreferences prefs) async {
    final joined = prefs.getBool(_hasJoinedRoomKey) ?? false;
    final clicked = prefs.getBool(_hasClickedEventKey) ?? false;
    if (joined && clicked) {
      await _awardBadge(BadgeType.socialButterfly);
    }
  }
}
