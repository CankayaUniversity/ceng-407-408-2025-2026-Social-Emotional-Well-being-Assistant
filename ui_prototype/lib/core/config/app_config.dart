import 'package:flutter/foundation.dart';

class AppConfig {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  /// Gemini Model Selection
  static const String geminiModel = 'gemini-2.5-flash';

  static bool hasValidGeminiKey() {
    return geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' && 
           geminiApiKey.isNotEmpty;
  }

  static void validateGeminiKey() {
    if (!hasValidGeminiKey()) {
      if (kDebugMode) {
        print('⚠️  Warning: Gemini API key is not set!');
        print('Get your key from: https://ai.google.dev/');
      }
    }
  }
}
