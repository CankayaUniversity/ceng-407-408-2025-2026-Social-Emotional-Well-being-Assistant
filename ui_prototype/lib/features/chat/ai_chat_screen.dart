import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

  static const String _systemPrompt = '''
You are a supportive wellbeing assistant.
Rules:
1. Be calm, empathetic, and concise.
2. Do not provide medical diagnosis.
3. If the user looks in crisis, suggest contacting local emergency support.
4. If recommendations are provided in context, use only those titles and do not invent items. Use all of the titles provided.
5. Reply in the user's language when possible.
''';

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

      _geminiService = GeminiService(apiKey: AppConfig.geminiApiKey, systemPrompt: _systemPrompt);
      _chatSession = _geminiService.startChatSession();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize Gemini: $e';
      });
    }
  }

  Future<void> _saveEmotionToJson(String text, String? emotion) async {
    if (_isNeutralEmotion(emotion)) {
      print('[DEBUG] Skipping neutral emotion entry for history');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/emotions.json');

      List<Map<String, dynamic>> emotionsList = [];
      String content = "empty";
      if (await file.exists()) {
        content = await file.readAsString();
        if (content.isNotEmpty) {
          emotionsList = List<Map<String, dynamic>>.from(jsonDecode(content));
        }
      }

      emotionsList.add({
        'text': text,
        'emotion': emotion,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Keep only the last 10 emotions
      if (emotionsList.length > 10) {
        emotionsList = emotionsList.sublist(emotionsList.length - 10);
      }

      await file.writeAsString(jsonEncode(emotionsList));
      print('[DEBUG] Emotion saved to ${file.path}');
      print(content);
    } catch (e) {
      print('[ERROR] Failed to save emotion to JSON: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadEmotionHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/emotions.json');

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) => !_isNeutralEmotion(entry['emotion']?.toString()))
          .toList();
    } catch (e) {
      print('[ERROR] Failed to load emotion history: $e');
      return [];
    }
  }

  bool _isNeutralEmotion(String? emotion) {
    final normalized = _normalizeEmotionLabel(emotion);
    const neutralValues = {
      'neutral',
      'none',
      'unknown',
      'unsure',
      'other',
      'notr',
    };
    return normalized.isEmpty || neutralValues.contains(normalized);
  }

  String _normalizeEmotionLabel(String? emotion) {
    if (emotion == null) {
      return '';
    }

    // Normalize common Turkish characters so labels like "Nötr" map to "notr".
    final lowered = emotion.trim().toLowerCase();
    final asciiLike = lowered
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i');

    return asciiLike.replaceAll(RegExp(r'[^a-z]'), '');
  }

  String? _resolveEmotionForRecommendations(
    String? currentEmotion,
    List<Map<String, dynamic>> history,
  ) {
    final normalizedCurrent = currentEmotion?.trim().toLowerCase();

    final sorted = [...history]
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    final Map<String, double> weightedScores = {};
    final Map<String, DateTime> latestSeenAt = {};

    for (int i = 0; i < sorted.length; i++) {
      final rawEmotion = sorted[i]['emotion']?.toString().trim().toLowerCase();
      if (rawEmotion == null || rawEmotion.isEmpty || _isNeutralEmotion(rawEmotion)) {
        continue;
      }

      // More recent entries get a larger weight.
      final recencyWeight = (i + 1).toDouble();
      weightedScores[rawEmotion] = (weightedScores[rawEmotion] ?? 0) + recencyWeight;

      final timestamp = DateTime.tryParse(sorted[i]['timestamp']?.toString() ?? '');
      if (timestamp != null) {
        final previous = latestSeenAt[rawEmotion];
        if (previous == null || timestamp.isAfter(previous)) {
          latestSeenAt[rawEmotion] = timestamp;
        }
      }
    }

    if (normalizedCurrent != null && !_isNeutralEmotion(normalizedCurrent)) {
      final currentBonus = (sorted.length + 1).toDouble();
      weightedScores[normalizedCurrent] = (weightedScores[normalizedCurrent] ?? 0) + currentBonus;
      latestSeenAt[normalizedCurrent] = DateTime.now();
    }

    if (weightedScores.isEmpty) {
      return _isNeutralEmotion(normalizedCurrent) ? null : normalizedCurrent;
    }

    final ranked = weightedScores.entries.toList()
      ..sort((a, b) {
        final scoreComparison = b.value.compareTo(a.value);
        if (scoreComparison != 0) return scoreComparison;

        final aLatest = latestSeenAt[a.key] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bLatest = latestSeenAt[b.key] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bLatest.compareTo(aLatest);
      });

    return ranked.first.key;
  }

  String _buildMoodHistoryContext(List<Map<String, dynamic>> history) {
    final filteredHistory = history
        .where((entry) => !_isNeutralEmotion(entry['emotion']?.toString()))
        .toList();

    if (filteredHistory.isEmpty) {
      return '';
    }

    final sorted = [...filteredHistory]
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    final snippets = <String>[];
    for (final entry in sorted.take(3)) {
      final emotion = entry['emotion']?.toString() ?? 'unknown';
      final text = entry['text']?.toString().trim() ?? '';
      final compactText = text.length > 80 ? '${text.substring(0, 80)}...' : text;
      snippets.add('- emotion: $emotion, message: "$compactText"');
    }

    return '\n\nRecent mood history (newest first):\n${snippets.join('\n')}';
  }

  Future<String?> _getEmotion(String text) async {
    const apiUrl = 'https://emotion-analysis-production.up.railway.app/analyze-emotion';
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
    const apiUrl = 'https://recommendation-production-df1e.up.railway.app/recommend';
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

  bool _isAskingForBooks(String text) {
    final lowerText = text.toLowerCase();
    final bookKeywords = [
      'book', 'kitap', 'read', 'oku', 'novel', 'author', 'yazar'
    ];
    return bookKeywords.any((keyword) => lowerText.contains(keyword));
  }

  bool _isAskingForMovies(String text) {
    final lowerText = text.toLowerCase();
    final movieKeywords = [
      'movie', 'film', 'watch', 'izle', 'tv', 'show', 'serie'
    ];
    return movieKeywords.any((keyword) => lowerText.contains(keyword));
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
      final emotion = await _getEmotion(text);
      print('Detected emotion: ${emotion ?? "None"}');

      // Save the detected emotion to a JSON file
      await _saveEmotionToJson(text, emotion);

      // Load mood history so recommendation requests can use recent emotional context.
      final emotionHistory = await _loadEmotionHistory();
      final recommendationEmotion = _resolveEmotionForRecommendations(
        emotion,
        emotionHistory,
      );
      print('[DEBUG] Emotion selected for recommendations: ${recommendationEmotion ?? "None"}');

      // 2. Check if user is asking for recommendations
      String recommendationContext = '';
      final askingForRecommendations = _isAskingForRecommendations(text);
      print('[DEBUG] User asking for recommendations: $askingForRecommendations');

      final askingForBooks = _isAskingForBooks(text);
      final askingForMovies = _isAskingForMovies(text);
      print('[DEBUG] Asking for books: $askingForBooks, Asking for movies: $askingForMovies');

      Map<String, dynamic>? bookRecs;
      Map<String, dynamic>? movieRecs;

      if (recommendationEmotion != null && askingForRecommendations) {
        print('[DEBUG] Fetching recommendations for emotion: $recommendationEmotion');

        // Get book recommendations only if asking for books (or neither book/movie specified)
        if (askingForBooks || (!askingForBooks && !askingForMovies)) {
          print('[DEBUG] Calling API for books...');
          bookRecs = await _getRecommendations(recommendationEmotion, 'books');
          print('[DEBUG] Book recommendations response: $bookRecs');

          if (bookRecs != null && bookRecs['recommendations'].isNotEmpty) {
            print('[DEBUG] Got ${bookRecs['recommendations'].length} books');
            recommendationContext +=
            '\n\nRecommended books for $recommendationEmotion emotion:\n';
            for (int i = 0; i < bookRecs['recommendations'].length; i++) {
              final book = bookRecs['recommendations'][i];
              print('[DEBUG] Book $i: ${book['title']}');
              recommendationContext +=
              '${i + 1}. ${book['title']} (Score: ${book['score'].toStringAsFixed(2)})\n';
            }
          } else {
            print('[DEBUG] No book recommendations returned');
          }
        }

        // Get movie recommendations only if asking for movies
        if (askingForMovies) {
          print('[DEBUG] Calling API for movies...');
          movieRecs = await _getRecommendations(recommendationEmotion, 'movies');
          print('[DEBUG] Movie recommendations response: $movieRecs');

          if (movieRecs != null && movieRecs['recommendations'].isNotEmpty) {
            print('[DEBUG] Got ${movieRecs['recommendations'].length} movies');
            recommendationContext +=
            '\n\nRecommended movies for $recommendationEmotion emotion:\n';
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
      }

        // 3. Send message to Gemini with emotion and recommendations (if asked)
        final moodHistoryContext = _buildMoodHistoryContext(emotionHistory);
        final effectiveMoodForPrompt = recommendationEmotion ?? emotion;
        final prompt = effectiveMoodForPrompt != null
          ? 'Şu anki ruh halim: ${emotion ?? "belirlenemedi"}. Öneriler için tercih edilen ruh hali: $effectiveMoodForPrompt. Mesajım: $text$moodHistoryContext$recommendationContext'
          : 'Mesajım: $text$moodHistoryContext$recommendationContext';

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
                      // if (msg.emotion != null)
                      //   Padding(
                      //     padding: const EdgeInsets.only(bottom: 6),
                      //     child: Chip(
                      //       label: Text("Detected emotion: ${msg.emotion}"),
                      //     ),
                      //   ),
                      // // Display book recommendations
                      // if (msg.bookRecommendations.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8, bottom: 8),
                      //     child: Container(
                      //       decoration: BoxDecoration(
                      //         border: Border.all(color: Colors.blue.shade300),
                      //         borderRadius: BorderRadius.circular(8),
                      //       ),
                      //       padding: const EdgeInsets.all(12),
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           const Text(
                      //             "Books for you:",
                      //             style: TextStyle(
                      //                 fontWeight: FontWeight.bold,
                      //                 fontSize: 14),
                      //           ),
                      //           const SizedBox(height: 8),
                      //           ...msg.bookRecommendations.asMap().entries.map(
                      //                 (entry) {
                      //               final idx = entry.key;
                      //               final book = entry.value;
                      //               return Padding(
                      //                 padding:
                      //                 const EdgeInsets.symmetric(vertical: 4),
                      //                 child: Text(
                      //                   '${idx + 1}. ${book['title']}',
                      //                   style: const TextStyle(fontSize: 12),
                      //                 ),
                      //               );
                      //             },
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // // Display movie recommendations
                      // if (msg.movieRecommendations.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8, bottom: 8),
                      //     child: Container(
                      //       decoration: BoxDecoration(
                      //         border: Border.all(color: Colors.purple.shade300),
                      //         borderRadius: BorderRadius.circular(8),
                      //       ),
                      //       padding: const EdgeInsets.all(12),
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           const Text(
                      //             "Movies for you:",
                      //             style: TextStyle(
                      //                 fontWeight: FontWeight.bold,
                      //                 fontSize: 14),
                      //           ),
                      //           const SizedBox(height: 8),
                      //           ...msg.movieRecommendations.asMap().entries.map(
                      //                 (entry) {
                      //               final idx = entry.key;
                      //               final movie = entry.value;
                      //               return Padding(
                      //                 padding:
                      //                 const EdgeInsets.symmetric(vertical: 4),
                      //                 child: Text(
                      //                   '${idx + 1}. ${movie['title']}',
                      //                   style: const TextStyle(fontSize: 12),
                      //                 ),
                      //               );
                      //             },
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
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
