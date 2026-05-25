import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ui_prototype/core/api/api_client.dart';
import 'package:ui_prototype/core/api/token_store.dart';
import 'package:ui_prototype/core/services/event_service.dart';
import 'package:ui_prototype/core/services/notification_service.dart';
import 'package:ui_prototype/core/services/gamification_service.dart';
import 'ai_chat_screen.dart';
import 'community_rooms_screen.dart';
import 'all_events_screen.dart';
import 'private_chat_rooms_screen.dart';
import 'data/chat_store.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final EventService _eventService = EventService();
  List<EventModel> _events = [];
  bool _loadingEvents = true;

  int _communityUnreadCount = 0;
  int _privateUnreadCount = 0;
  static bool _sessionNotificationShown = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _checkMessagesWhileAway();
  }

  Future<void> _checkMessagesWhileAway() async {
    final user = await TokenStore.getCurrentUser();
    if (user == null) return;

    final userId = user.id;
    final prefs = await SharedPreferences.getInstance();

    // 1. Get joined community rooms (strictly non-private)
    final String userJoinedKey = 'joined_community_rooms_$userId';
    final List<String> communityRooms = (prefs.getStringList(userJoinedKey) ?? [])
        .where((r) => !r.trim().toLowerCase().startsWith('private-'))
        .toSet()
        .toList();

    // 2. Get private rooms from ChatStore (strictly private)
    final privateChats = ChatStore.instance.loadPrivateChats();
    final List<String> privateRooms = privateChats
        .map((c) => c['room']?.toString() ?? '')
        .where((r) => r.isNotEmpty && r.trim().toLowerCase().startsWith('private-'))
        .toSet()
        .toList();

    int totalNew = 0;
    int communityNew = 0;
    int privateNew = 0;

    // Helper to normalize room key (same as in community_rooms_screen)
    String normalize(String r) => r.trim().toLowerCase();

    // Check Community Rooms
    for (final room in communityRooms) {
      final unread = await _getUnreadCountForRoom(userId, room, prefs, normalize);
      communityNew += unread;
    }

    // Check Private Rooms
    for (final room in privateRooms) {
      final unread = await _getUnreadCountForRoom(userId, room, prefs, normalize);
      privateNew += unread;
    }

    totalNew = communityNew + privateNew;

    if (mounted) {
      setState(() {
        _communityUnreadCount = communityNew;
        _privateUnreadCount = privateNew;
      });
    }

    if (totalNew > 0 && !_sessionNotificationShown) {
      _sessionNotificationShown = true;
      NotificationService().showNotification(
        id: 999,
        title: 'Keşfet',
        body: 'Hoş geldin! Sen yokken $totalNew yeni mesaj geldi.',
      );
    }
  }

  Future<int> _getUnreadCountForRoom(int userId, String room, SharedPreferences prefs, String Function(String) normalize) async {
    final key = normalize(room);
    final lastSeenStr = prefs.getString('last_seen_${userId}_$key');
    final lastSeen = lastSeenStr != null
        ? DateTime.tryParse(lastSeenStr) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);

    try {
      final response = await ApiClient.get('/community/messages?userId=$userId&room=$room');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> messages = (decoded is List) ? decoded : (decoded['messages'] is List ? decoded['messages'] : []);
        int count = 0;
        for (final m in messages) {
          final createdAt = DateTime.tryParse(m['createdAt']?.toString() ?? '');
          final senderId = int.tryParse(m['userId']?.toString() ?? '');
          if (senderId != userId && createdAt != null && createdAt.isAfter(lastSeen)) {
            count++;
          }
        }
        return count;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _eventService.fetchUpcomingEvents();
      if (mounted) {
        setState(() {
          _events = events;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingEvents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const gold = Color(0xFFFFE6A7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Keşfet', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _chatCard(
            context,
            icon: Icons.settings_input_component_rounded,
            title: 'Ebhire',
            subtitle: 'Kişisel asistanın',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
            navy: navy,
            gold: gold,
          ),
          const SizedBox(height: 16),
          _chatCard(
            context,
            icon: Icons.groups_rounded,
            title: 'Topluluk Odaları',
            subtitle: 'Destek gruplarına katıl',
            unreadCount: _communityUnreadCount,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityRoomsScreen()));
              _checkMessagesWhileAway(); // Refresh counts when returning
            },
            navy: navy,
            gold: gold,
          ),
          const SizedBox(height: 16),
          _chatCard(
            context,
            icon: Icons.lock_rounded,
            title: 'Özel Sohbet Odaları',
            subtitle: 'Birebir güvenli mesajlaşma',
            unreadCount: _privateUnreadCount,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivateChatRoomsScreen()),
              );
              _checkMessagesWhileAway(); // Refresh counts when returning
            },
            navy: navy,
            gold: gold,
          ),
          const SizedBox(height: 32),
          _buildUpcomingEventsSection(navy, gold),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsSection(Color navy, Color gold) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Yakındaki Etkinlikler',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            if (!_loadingEvents)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllEventsScreen(events: _events),
                    ),
                  );
                },
                child: Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: navy.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingEvents)
          const Center(child: CircularProgressIndicator())
        else if (_events.isEmpty)
          const Text('Yakınlarda etkinlik bulunamadı.')
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return _buildEventCard(event, navy, gold);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event, Color navy, Color gold) {
    return GestureDetector(
      onTap: () async {
        // Gamification Trigger
        await GamificationService().recordEventClick();

        if (event.link != null && event.link!.isNotEmpty) {
          final uri = Uri.parse(event.link!);
          try {
            // mode: LaunchMode.externalApplication ensures it opens in the default browser
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              debugPrint('Could not launch ${event.link}');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the link.')),
                );
              }
            }
          } catch (e) {
            debugPrint('Error launching URL: $e');
          }
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.network(
                event.imageUrl,
                height: 120,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: navy.withOpacity(0.1),
                  child: Icon(Icons.image_not_supported, color: navy),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: navy,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: navy.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: navy.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: navy.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: navy.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color navy,
    required Color gold,
    int unreadCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: navy.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: gold, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: navy,
                          fontSize: 17,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: navy.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: navy.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}