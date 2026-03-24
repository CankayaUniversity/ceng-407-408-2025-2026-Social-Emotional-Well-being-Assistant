import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
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

  Future<String?> _getEmotion(String text) async {
    // For Android emulator, use 'http://10.0.2.2:8000/analyze_emotion'
    const apiUrl = 'http://127.0.0.1:8000/analyze_emotion';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['emotion'];
      }
    } catch (e) {
      // Handle API errors (e.g., log them)
      print('Error getting emotion: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getRecommendations(
      String emotion, String mediaType) async {
    const apiUrl = 'http://10.0.2.2:5000/recommend';
    try {
      print('[DEBUG] Calling recommendation API: $apiUrl');
      print('[DEBUG] Emotion: $emotion, Media Type: $mediaType');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emotion': emotion.toLowerCase(),
          'media_type': mediaType,
          'count': 3,
        }),
      );

      print('[DEBUG] API Response Status: ${response.statusCode}');
      print('[DEBUG] API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('[ERROR] API returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[ERROR] Error getting recommendations: $e');
    }
    return null;
  }

  bool _isAskingForRecommendations(String text) {
    final lowerText = text.toLowerCase();
    print('[DEBUG] Checking recommendations for text: "$text"');
    print('[DEBUG] Lowercase text: "$lowerText"');
    
    // English keywords
    final englishKeywords = [
      'recommend',
      'suggest',
      'suggestion',
      'book recommendation',
      'movie recommendation',
      'what should i',
      'what can i',
      'any good',
      'suggest a',
      'recommend a',
      'show me',
      'find me',
      'give me',
    ];
    
    // Turkish keywords
    final turkishKeywords = [
      'öner',         
      'tavsiye',       
      'kitap',        
      'film',     
      'ne izle',       
      'ne okuya',    
      'ne okusa',     
      'hangi kitap',   
      'hangi film', 
      'bana bir',      
      'bulabilir',      
      'bulabilir misin', 
      'yapabilir misin', 
      'yardım et',     
    ];

    // Check English keywords
    for (var keyword in englishKeywords) {
      if (lowerText.contains(keyword)) {
        print('[DEBUG] Matched English keyword: "$keyword"');
        return true;
      }
    }
    
    // Check Turkish keywords
    for (var keyword in turkishKeywords) {
      if (lowerText.contains(keyword)) {
        print('[DEBUG] Matched Turkish keyword: "$keyword"');
        return true;
      }
    }
    
    print('[DEBUG] No recommendation keywords found');
    return false;
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
      // 1. Get emotion from NLP API
      print('Sending to NLP API: "$text"');
      final emotion = "anger"; // Hardcoded for testing for now
      print('Detected emotion: ${emotion ?? "None"}');

      // 2. Check if user is asking for recommendations
      String recommendationContext = '';
      final askingForRecommendations = _isAskingForRecommendations(text);
      print('[DEBUG] User asking for recommendations: $askingForRecommendations');
      
      Map<String, dynamic>? bookRecs;
      Map<String, dynamic>? movieRecs;

      if (emotion != null && askingForRecommendations) {
        print('[DEBUG] Fetching recommendations for emotion: $emotion');
        
        // Get book recommendations
        print('[DEBUG] Calling API for books...');
        bookRecs = await _getRecommendations(emotion, 'books');
        print('[DEBUG] Book recommendations response: $bookRecs');
        
        if (bookRecs != null && bookRecs['recommendations'].isNotEmpty) {
          print('[DEBUG] Got ${bookRecs['recommendations'].length} books');
          recommendationContext +=
              '\n\nRecommended books for ${emotion} emotion:\n';
          for (int i = 0; i < bookRecs['recommendations'].length; i++) {
            final book = bookRecs['recommendations'][i];
            print('[DEBUG] Book $i: ${book['title']}');
            recommendationContext +=
                '${i + 1}. ${book['title']} (Score: ${book['score'].toStringAsFixed(2)})\n';
          }
        } else {
          print('[DEBUG] No book recommendations returned');
        }

        // Get movie recommendations
        print('[DEBUG] Calling API for movies...');
        movieRecs = await _getRecommendations(emotion, 'movies');
        print('[DEBUG] Movie recommendations response: $movieRecs');
        
        if (movieRecs != null && movieRecs['recommendations'].isNotEmpty) {
          print('[DEBUG] Got ${movieRecs['recommendations'].length} movies');
          recommendationContext +=
              '\n\nRecommended movies for ${emotion} emotion:\n';
          for (int i = 0; i < movieRecs['recommendations'].length; i++) {
            final movie = movieRecs['recommendations'][i];
            print('[DEBUG] Movie $i: ${movie['title']}');
            recommendationContext +=
                '${i + 1}. ${movie['title']} (Score: ${movie['score'].toStringAsFixed(2)})\n';
          }
        } else {
          print('[DEBUG] No movie recommendations returned');
        }
      }

      // 3. Send message to Gemini with emotion and recommendations (if asked)
      final prompt = emotion != null
          ? 'Şu anki ruh halim: $emotion. Mesajım: $text$recommendationContext'
          : 'Mesajım: $text';

      print('[DEBUG] Final prompt: "$prompt"');
      final response = await _chatSession.sendMessage(
        Content.text(prompt),
      );

      final aiResponse = response.text ?? 'No response';
      print('[DEBUG] Gemini response: "$aiResponse"');
      print('[DEBUG] Book recs for message: ${bookRecs?['recommendations'] ?? []}');
      print('[DEBUG] Movie recs for message: ${movieRecs?['recommendations'] ?? []}');

      setState(() {
        _messages.add(
          _Message(
            aiResponse,
            false,
            emotion: emotion,
            bookRecommendations: bookRecs?['recommendations'] ?? [],
            movieRecommendations: movieRecs?['recommendations'] ?? [],
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      print('[ERROR] Exception: $e');
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
                      // Display book recommendations
                      if (msg.bookRecommendations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Books for you:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                ...msg.bookRecommendations.asMap().entries.map(
                                  (entry) {
                                    final idx = entry.key;
                                    final book = entry.value;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        '${idx + 1}. ${book['title']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Display movie recommendations
                      if (msg.movieRecommendations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Movies for you:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                ...msg.movieRecommendations.asMap().entries.map(
                                  (entry) {
                                    final idx = entry.key;
                                    final movie = entry.value;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        '${idx + 1}. ${movie['title']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
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
  final List<dynamic> bookRecommendations;
  final List<dynamic> movieRecommendations;

  _Message(
    this.text,
    this.isUser, {
    this.emotion,
    this.bookRecommendations = const [],
    this.movieRecommendations = const [],
  });
}