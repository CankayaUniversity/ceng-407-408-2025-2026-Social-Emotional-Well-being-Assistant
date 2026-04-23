import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl;
  final String model;
  final String? systemPrompt;

  OllamaService({
    required this.baseUrl,
    required this.model,
    this.systemPrompt,
  });

  /// Start a chat session for multi-turn conversations
  OllamaChatSession startChatSession() {
    return OllamaChatSession(
      baseUrl: baseUrl,
      model: model,
      systemPrompt: systemPrompt,
    );
  }
}

class OllamaChatSession {
  final String baseUrl;
  final String model;
  final List<Map<String, dynamic>> _messages = [];

  OllamaChatSession({
    required this.baseUrl,
    required this.model,
    String? systemPrompt,
  }) {
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      _messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
  }

  /// Send a message to Ollama and get a response
  Future<OllamaResponse> sendMessage(String message) async {
    _messages.add({
      'role': 'user',
      'content': message,
    });

    try {
      final uri = Uri.parse('$baseUrl/api/chat');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': _messages,
          'stream': false,
          'options': {
            'temperature': 0.5,
            'top_p': 0.9,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data['message']['content'] as String;

        // Append assistant response to history
        _messages.add({
          'role': 'assistant',
          'content': aiText,
        });

        return OllamaResponse(text: aiText);
      } else {
        return OllamaResponse(text: 'Error from Ollama: HTTP ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      return OllamaResponse(text: 'Network Error: Make sure over Tailscale your phone can reach $baseUrl\nDetails: $e');
    }
  }

  /// Ping the model to load it into memory. 
  /// The keep_alive parameter tells Ollama how long to keep it in RAM.
  Future<void> warmUpModel() async {
    try {
      final uri = Uri.parse('$baseUrl/api/generate');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          // Just an empty string so it loads the model but doesn't do any thinking
          'prompt': '', 
          // Set keep_alive to 60m (1 hour). It won't unload unless idle for an hour.
          'keep_alive': '60m', 
        }),
      );
      print('[OllamaService] Model $model warmed up successfully.');
    } catch (e) {
      print('[OllamaService] Background warm-up failed (ignore if network issue): $e');
    }
  }
}

// Wrapper to mimic the Content response structure you had previously
class OllamaResponse {
  final String? text;
  OllamaResponse({this.text});
}