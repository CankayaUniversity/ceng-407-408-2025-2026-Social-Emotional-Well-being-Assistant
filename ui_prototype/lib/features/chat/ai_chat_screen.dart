import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../profile/data/emergency_contact_store.dart';
// import '../../core/api/gemini_service.dart';
import '../../core/api/ollama_service.dart';
import '../../core/config/app_config.dart';
import '../settings/settings_screen.dart';

enum RiskLevel { low, medium, high }

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  // late GeminiService _geminiService;
  // late ChatSession _chatSession;
  late OllamaService _ollamaService;
  late OllamaChatSession _chatSession;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    //_initializeGemini();
    _initializeAI();
  }

  static const String _systemPrompt = '''
You are a supportive wellbeing assistant.
Rules:
1. Be calm, empathetic, and concise.
2. Do not provide medical diagnosis.
3. If the user looks in crisis, suggest contacting local emergency support.
4. If recommendations are provided in context, use only those titles and do not invent items. Use all of the titles provided.
5. Reply in the user's language when possible.
6. Format your message like a text message only raw text, no markdown, no html, no lists. Just plain text.
''';

  // void _initializeGemini() {
  //   try {
  //     AppConfig.validateGeminiKey();
  //
  //     if (!AppConfig.hasValidGeminiKey()) {
  //       setState(() {
  //         _error = 'Add your Gemini API key.\n\n'
  //             'Get one from: https://ai.google.dev/\n\n'
  //             'Then update it in lib/core/config/app_config.dart';
  //       });
  //       return;
  //     }
  //
  //     _geminiService = GeminiService(apiKey: AppConfig.geminiApiKey, systemPrompt: _systemPrompt);
  //     _chatSession = _geminiService.startChatSession();
  //   } catch (e) {
  //     setState(() {
  //       _error = 'Failed to initialize Gemini: $e';
  //     });
  //   }
  // }

  void _initializeAI() {
    try {
      AppConfig.validateSetup();

      if (!AppConfig.hasValidUrl()) {
        setState(() {
          _error = 'Ollama URL is invalid. Check AppConfig.';
        });
        return;
      }

      // Initialize the new local Ollama service
      _ollamaService = OllamaService(
        baseUrl: AppConfig.ollamaBaseUrl,
        model: AppConfig.ollamaModel,
        systemPrompt: _systemPrompt,
      );
      
      // Fire and forget! This will load the model into your PC's memory right now
      _ollamaService.warmUpModel(); 

      _chatSession = _ollamaService.startChatSession();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize AI: $e';
      });
    }
  }

  Future<void> _triggerAutomaticAlert() async {
    print('[DEBUG] AI Chat Screen: Triggering Automatic Alert');
    final prefs = await SharedPreferences.getInstance();
    final isNotificationEnabled = prefs.getBool('isNotificationEnabled') ?? false;

    print('[DEBUG] AI Chat Screen: Notifications Enabled (Global): $isNotificationEnabled');

    // Fetch user name
    final userName = prefs.getString('user_name') ?? 'Your loved one';

    // Get contact from Profile Store
    final contacts = EmergencyContactStore.instance.contacts;
    print('[DEBUG] AI Chat Screen: Contact Store Size (from Profile): ${contacts.length}');

    if (contacts.isEmpty) {
      print('[DEBUG] AI Chat Screen: Alert aborted - No contacts found in User Profile');
      return;
    }

    // Prioritize the Primary contact
    final primary = contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first);
    final contactName = primary.fullName;
    final recipient = primary.email;

    print('[DEBUG] AI Chat Screen: Selected Primary Contact from Profile: $contactName ($recipient)');

    if (!isNotificationEnabled) {
      print('[DEBUG] AI Chat Screen: Alert aborted - Notifications not enabled globally');
      return;
    }

    if (recipient.isEmpty) {
      print('[DEBUG] AI Chat Screen: Alert aborted - Contact email is empty');
      return;
    }

    String message =
        "Our system has detected that $userName may be experiencing a high level of emotional distress. Based on their recent interactions, we are reaching out to you as their designated trusted contact. We recommend checking in on them to offer your support.";

    try {
      await NotificationService().sendEmailAutomatically(
        recipientEmail: recipient,
        toName: contactName,
        userName: userName,
        message: message,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent to your trusted contact.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      print('[ERROR] AI Chat Screen: Failed to send automatic alert: $error');
    }
  }

  void _sendEmail(String email) async {
    String message =
        "This is a notification from the Social-Emotional Wellbeing Assistant. Your trusted contact may be in distress and might need your support.";
    try {
      await NotificationService().sendEmail(
        recipient: email,
        subject: 'Social-Emotional Wellbeing Assistant Notification',
        body: message,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email notification initiated.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: $error')),
      );
    }
  }

  RiskLevel _detectTrigger(
      String currentEmotion, List<Map<String, dynamic>> history) {
    final normalizedCurrent = _normalizeEmotionLabel(currentEmotion);
    const negativeEmotions = {'uzuntu', 'korku', 'ofke'};

    if (!negativeEmotions.contains(normalizedCurrent)) {
      return RiskLevel.low;
    }

    // Analyze history for patterns
    final recentNegativeCount = history
        .where((entry) =>
    negativeEmotions.contains(_normalizeEmotionLabel(entry['emotion'])))
        .length;

    // High risk: current negative emotion + 4 recent negative emotions
    if (recentNegativeCount >= 5) {
      print('[DEBUG] High risk detected: $currentEmotion (History count: $recentNegativeCount)');
      return RiskLevel.high;
    }

    // Medium risk: current negative emotion + 1 recent negative emotion
    if (recentNegativeCount == 1) {
      print('[DEBUG] Medium risk detected: $currentEmotion (History count: $recentNegativeCount)');
      return RiskLevel.medium;
    }

    // Low risk: isolated negative emotion
    print('[DEBUG] Low risk detected: $currentEmotion');
    return RiskLevel.low;
  }

  Future<void> _saveEmotionToJson(String text, String? emotion) async {
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
      
      // Format each emotion separately to avoid logcat buffer issues
      print('\n=== Last Emotions (newest first)) ===');
      final jsonEncoder = const JsonEncoder.withIndent('  ');
      for (int i = emotionsList.length - 1; i >= 0; i--) {
        final prettyEmotion = jsonEncoder.convert(emotionsList[i]);
        print('[${emotionsList.length - i}]\n$prettyEmotion');
      }
      print('=== Toplam: ${emotionsList.length} duygular ===\n');
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
    return '';
  }


  Future<String?> _getEmotion(String text) async {
    const apiUrl = AppConfig.emotionApiUrl;
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
    const apiUrl = AppConfig.recommendationApiUrl;
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

      // Trigger Detection
      final riskLevel = emotion != null
          ? _detectTrigger(emotion, emotionHistory)
          : RiskLevel.low;
      String riskContext = '';
      switch (riskLevel) {
        case RiskLevel.high:
          riskContext =
          '\n\n[CRITICAL] User seems to be in high distress. Prioritize empathy, de-escalation, and suggest professional help. Avoid making jokes or being overly casual. Ask if they want to talk about what is causing these feelings.';
          _triggerAutomaticAlert();
          break;
        case RiskLevel.medium:
          riskContext =
          '\n\n[WARNING] User is showing signs of recurring negative emotions. Be extra supportive and gentle. Acknowledge their feelings.';
          break;
        default:
          break;
      }

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
          ? 'Şu anki ruh halim: ${emotion ?? "belirlenemedi"}. Öneriler için tercih edilen ruh hali: $effectiveMoodForPrompt. Mesajım: $text$moodHistoryContext$recommendationContext$riskContext'
          : 'Mesajım: $text$moodHistoryContext$recommendationContext$riskContext';

      print('[DEBUG] Final prompt: "$prompt"');
      // final response = await _chatSession.sendMessage(
      //   Content.text(prompt),
      // );
      final response = await _chatSession.sendMessage(prompt);

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
            riskLevel: riskLevel,
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
      appBar: AppBar(
        title: const Text("AI Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
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
                      if (msg.emotion != null && !msg.isUser)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Chip(
                            label: Text(
                                'Emotion: ${msg.emotion} (Risk: ${msg.riskLevel?.toString().split('.').last})'),
                            backgroundColor: Colors.blueGrey.shade100,
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
  final RiskLevel? riskLevel;
  final List<dynamic> bookRecommendations;
  final List<dynamic> movieRecommendations;

  _Message(
      this.text,
      this.isUser, {
        this.emotion,
        this.riskLevel,
        this.bookRecommendations = const [],
        this.movieRecommendations = const [],
      });
}
