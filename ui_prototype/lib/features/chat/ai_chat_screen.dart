import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/api/gemini_service.dart';
import '../../core/config/app_config.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  late GeminiService _geminiService;
  late ChatSession _chatSession;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() {
    try {
      AppConfig.validateGeminiKey();
      
      if (!AppConfig.hasValidGeminiKey()) {
        setState(() {
          _error = 'Add your Gemini API key.\n\n'
              'Get one from: https://ai.google.dev/\n\n'
              'Then update it in lib/core/config/app_config.dart';
        });
        return;
      }

      _geminiService = GeminiService(apiKey: AppConfig.geminiApiKey);
      _chatSession = _geminiService.startChatSession();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize Gemini: $e';
      });
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_Message(text, true));
      _controller.clear();
      _isLoading = true;
    });

    try {
      // Send message to Gemini
      final response = await _chatSession.sendMessage(
        Content.text(text),
      );

      final aiResponse = response.text ?? 'No response';

      setState(() {
        _messages.add(
          _Message(
            aiResponse,
            false,
            emotion: null, // TODO: Add emotion detection here
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _Message(
            'Sorry, I encountered an error: $e',
            false,
          ),
        );
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Chat")),
      body: _error != null
          ? Center(
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: msg.isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? Colors.teal.shade200
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg.text),
                            ),
                            if (msg.emotion != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Chip(
                                  label: Text("Detected emotion: ${msg.emotion}"),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            hintText: "Type your message...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isLoading ? null : _sendMessage,
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  final String? emotion;

  _Message(this.text, this.isUser, {this.emotion});
}
