import 'package:flutter/foundation.dart';

// class AppConfig {
//   static const String geminiApiKey = String.fromEnvironment(
//     'GEMINI_API_KEY',
//     defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
//   );
//
//   /// Gemini Model Selection
//   static const String geminiModel = 'gemini-3.1-flash-lite-preview';
//
//   static bool hasValidGeminiKey() {
//     return geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
//            geminiApiKey.isNotEmpty;
//   }
//
//   static void validateGeminiKey() {
//     if (!hasValidGeminiKey()) {
//       if (kDebugMode) {
//         print('⚠️  Warning: Gemini API key is not set!');
//         print('Get your key from: https://ai.google.dev/');
//       }
//     }
//   }
// }

class AppConfig {
  /// Replace with your computer's Tailscale IP address (e.g. 100.x.y.z)
  static const String ollamaBaseUrl = String.fromEnvironment(
    'OLLAMA_BASE_URL',
    defaultValue: 'https://coreys-laptop.tailfccbbe.ts.net',
  );

  /// The model you pulled in the terminal
  static const String ollamaModel = 'gemma2';

  static bool hasValidUrl() {
    return ollamaBaseUrl.isNotEmpty && ollamaBaseUrl.startsWith('http');
  }

  static void validateSetup() {
    if (!hasValidUrl()) {
      if (kDebugMode) {
        print('⚠️  Warning: Ollama Base URL is not correctly set!');
      }
    }
  }

  // EmailJS Configuration
  static const String emailjsServiceId = 'social_emotional_assist';
  static const String emailjsTemplateId = 'template_vvi1spo';
  static const String emailjsPublicKey = '_LfgryKG7OhDz_lv_';
}
