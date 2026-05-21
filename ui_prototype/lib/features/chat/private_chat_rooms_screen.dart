import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_rooms_screen.dart';
import 'data/chat_store.dart';

class PrivateChatRoomsScreen extends StatefulWidget {
  const PrivateChatRoomsScreen({super.key});

  @override
  State<PrivateChatRoomsScreen> createState() => _PrivateChatRoomsScreenState();
}

class _PrivateChatRoomsScreenState extends State<PrivateChatRoomsScreen> {
  bool _loading = true;
  String? _chatUsername;
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = (prefs.getString('user_nickname') ?? '').trim();
    final resolvedName = nickname.isNotEmpty ? nickname : 'Anonim';
    final raw = ChatStore.instance.loadPrivateChats();

    raw.sort((a, b) => _parseLastActive(b).compareTo(_parseLastActive(a)));

    if (!mounted) return;
    setState(() {
      _chatUsername = resolvedName;
      _chats = raw;
      _loading = false;
    });
  }

  DateTime _parseLastActive(Map<String, dynamic> chat) {
    final raw = chat['lastActive']?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<String> _participantsFrom(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  String _titleForChat(Map<String, dynamic> chat) {
    final participants = _participantsFrom(chat['participants']);
    final current = _chatUsername ?? '';
    final others = participants.where((p) => p != current).toList();
    if (others.isNotEmpty) return others.join(', ');
    if (participants.isNotEmpty) return participants.join(', ');
    return 'Özel Sohbet';
  }

  String _subtitleForChat(Map<String, dynamic> chat) {
    final participants = _participantsFrom(chat['participants']);
    if (participants.isEmpty) return 'Birebir güvenli mesajlaşma';
    return 'Katılımcılar: ${participants.join(', ')}';
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
        title: const Text('Özel Sohbet Odaları', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Text(
                    'Henüz özel sohbet yok.',
                    style: TextStyle(color: navy.withOpacity(0.6), fontWeight: FontWeight.w600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final room = (chat['room'] ?? '').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: navy.withOpacity(0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: navy.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.lock_rounded, color: navy),
                        ),
                        title: Text(
                          _titleForChat(chat),
                          style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 16),
                        ),
                        subtitle: Text(
                          _subtitleForChat(chat),
                          style: TextStyle(fontWeight: FontWeight.w700, color: navy.withOpacity(0.4), fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: navy.withOpacity(0.5)),
                        onTap: room.isEmpty
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityRoomsScreen(
                                      initialRoom: room,
                                      openAsPrivate: true,
                                      popOnBack: true,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  await _loadChats();
                                }
                              },
                      ),
                    );
                  },
                ),
    );
  }
}

