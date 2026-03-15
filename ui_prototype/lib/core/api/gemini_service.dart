import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService({required String apiKey}) {
    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: apiKey,
    );
  }

  /// Send a message to Gemini and get a response
  Future<String> sendMessage(String message) async {
    try {
      final content = [Content.text(message)];
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        return response.text!;
      } else {
        return 'No response from Gemini';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Start a chat session for multi-turn conversations
  ChatSession startChatSession({List<Content>? history}) {
    return _model.startChat(history: history ?? []);
  }
}
