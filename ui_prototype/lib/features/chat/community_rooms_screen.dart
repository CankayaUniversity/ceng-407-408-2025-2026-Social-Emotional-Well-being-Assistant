import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui_prototype/core/api/api_client.dart';
import 'package:ui_prototype/core/api/token_store.dart';
import 'package:ui_prototype/core/config/app_config.dart';
import 'package:ui_prototype/core/services/chat_service.dart';
import 'package:ui_prototype/core/services/notification_service.dart';

class CommunityRoomsScreen extends StatefulWidget {
  const CommunityRoomsScreen({super.key});

  @override
  State<CommunityRoomsScreen> createState() => _CommunityRoomsScreenState();
}

enum RoomMembershipStatus { none, joined, left }

class _CommunityRoomsScreenState extends State<CommunityRoomsScreen> {
  static const String backendBaseUrl = AppConfig.backendBaseUrl;

  static const String _anonymousModeKey = 'anonymous_mode';
  static const String _nicknameKey = 'user_nickname';
  static const String _joinedRoomsKey = 'joined_community_rooms';

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createRoomController = TextEditingController();

  final ChatService _chatService = ChatService();
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _invitationSubscription;
  StreamSubscription? _privateChatStartedSubscription;

  final List<ChatItem> _items = [];
  final List<String> _allRooms = [];
  List<String> _filteredRooms = [];

  final Map<String, RoomMembershipStatus> _roomStatuses = {};
  final Set<String> _myJoinedRooms = {};

  bool _connected = false;
  bool _isDisposed = false;
  bool _joined = false;
  bool _userReady = false;
  bool _loadingUser = true;
  bool _joiningRoom = false;
  bool _loadingRooms = true;
  bool _leavingRoom = false;

  int? _userId;
  String? _realUsername;
  String? _chatUsername;
  bool _anonymousMode = false;
  String? _nickname;
  String? _currentRoom;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _invitationSubscription?.cancel();
    _privateChatStartedSubscription?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _createRoomController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      await NotificationService().init();
      final CurrentUser? user = await TokenStore.getCurrentUser();
      final prefs = await SharedPreferences.getInstance();

      if (user == null) {
        _safeSetState(() {
          _loadingUser = false;
          _loadingRooms = false;
          _initError = 'Giriş yapan kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
        });
        return;
      }

      String remoteNickname = '';
      bool remoteAnonymousMode = true;
      List<String> joinedRooms = [];

      try {
        final profileRes = await ApiClient.get('/user/profile');
        if (profileRes.statusCode == 200) {
          final data = jsonDecode(profileRes.body);
          remoteNickname = (data['nickname'] ?? '').toString();
          remoteAnonymousMode = data['anonymous_mode'] ?? true;
          await prefs.setString("${_nicknameKey}_${user.username}", remoteNickname);
          await prefs.setBool("${_anonymousModeKey}_${user.username}", remoteAnonymousMode);
        } else {
          remoteAnonymousMode = prefs.getBool("${_anonymousModeKey}_${user.username}") ?? true;
          remoteNickname = (prefs.getString("${_nicknameKey}_${user.username}") ?? '').trim();
        }
      } catch (_) {
        remoteAnonymousMode = prefs.getBool("${_anonymousModeKey}_${user.username}") ?? true;
        remoteNickname = (prefs.getString("${_nicknameKey}_${user.username}") ?? '').trim();
      }

      try {
        final roomsRes = await ApiClient.get('/community/my-rooms');
        if (roomsRes.statusCode == 200) {
          final data = jsonDecode(roomsRes.body);
          joinedRooms = List<String>.from(data['rooms'] ?? []);
          await prefs.setStringList('${_joinedRoomsKey}_${user.id}', joinedRooms);
        } else {
          joinedRooms = prefs.getStringList('${_joinedRoomsKey}_${user.id}') ?? [];
        }
      } catch (_) {
        joinedRooms = prefs.getStringList('${_joinedRoomsKey}_${user.id}') ?? [];
      }

      final resolvedChatName = remoteAnonymousMode
          ? (remoteNickname.isNotEmpty ? remoteNickname : 'Anonim')
          : user.username;

      _safeSetState(() {
        _userId = user.id;
        _realUsername = user.username;
        _chatUsername = resolvedChatName;
        _anonymousMode = remoteAnonymousMode;
        _nickname = remoteNickname;
        _userReady = true;
        _loadingUser = false;
        _initError = null;

        _myJoinedRooms.clear();
        for (final room in joinedRooms) {
          _myJoinedRooms.add(room);
          _roomStatuses[_normalizeRoomKey(room)] = RoomMembershipStatus.joined;
        }
      });

      _initializeChatService();
      await _loadRooms();
      await _checkMessagesWhileAway();
    } catch (e) {
      _safeSetState(() {
        _loadingUser = false;
        _loadingRooms = false;
        _initError = 'Community Rooms ekranı başlatılamadı.';
      });
    }
  }

  Future<void> _checkMessagesWhileAway() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    int totalNew = 0;

    for (final room in _myJoinedRooms) {
      final key = _normalizeRoomKey(room);
      final lastSeenStr = prefs.getString('last_seen_${_userId}_$key');
      final lastSeen = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0);

      try {
        final response = await ApiClient.get('/community/messages?userId=$_userId&room=$room');
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final List<dynamic> messages = (decoded is List) ? decoded : (decoded['messages'] is List ? decoded['messages'] : []);
          for (final m in messages) {
            final createdAt = DateTime.tryParse(m['createdAt']?.toString() ?? '');
            final senderId = int.tryParse(m['userId']?.toString() ?? '');
            if (senderId != _userId && createdAt != null && createdAt.isAfter(lastSeen)) {
              totalNew++;
            }
          }
        }
      } catch (_) {}
    }

    if (totalNew > 0) {
      NotificationService().showNotification(id: 999, title: 'Community Rooms', body: 'Hoş geldin! Sen yokken $totalNew yeni mesaj geldi.');
    }
  }

  Future<void> _updateLastSeen(String room) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _normalizeRoomKey(room);
    await prefs.setString('last_seen_${_userId}_$key', DateTime.now().toIso8601String());
  }

  Future<void> _persistJoinedRooms() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String userJoinedKey = '${_joinedRoomsKey}_$_userId';
    await prefs.setStringList(userJoinedKey, _myJoinedRooms.toList());
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed) return;
    setState(fn);
  }

  String _normalizeRoomKey(String room) => room.trim().toLowerCase();

  RoomMembershipStatus _getRoomStatus(String room) {
    return _roomStatuses[_normalizeRoomKey(room)] ?? RoomMembershipStatus.none;
  }

  void _setRoomStatus(String room, RoomMembershipStatus status) {
    final key = _normalizeRoomKey(room);
    _roomStatuses[key] = status;
    if (status == RoomMembershipStatus.joined) {
      _myJoinedRooms.add(room);
    } else {
      _myJoinedRooms.removeWhere((r) => _normalizeRoomKey(r) == key);
    }
    _persistJoinedRooms();
  }

  void _ensureRoomExistsInList(String room) {
    final exists = _allRooms.any((r) => _normalizeRoomKey(r) == _normalizeRoomKey(room));
    if (!exists) {
      _allRooms.insert(0, room);
    }
  }

  void _initializeChatService() {
    if (_userId == null || _chatUsername == null) return;
    _chatService.connect(_userId!, _chatUsername!);

    _connectionSubscription = _chatService.connectionStatus.listen((isConnected) {
      _safeSetState(() { _connected = isConnected; });
      if (isConnected) {
        for (final room in _myJoinedRooms) {
          _chatService.joinRoom(room, _userId!, _chatUsername!);
        }
      }
    });

    _messageSubscription = _chatService.messages.listen((chatItem) {
      final msgRoom = chatItem.room;
      final senderId = chatItem.userId;

      if (_joined && msgRoom != null && _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(msgRoom)) {
        _safeSetState(() { 
          _items.add(chatItem);
          if (senderId != null && chatItem.socketId != null) {
            _chatService.userSocketIds[senderId] = chatItem.socketId!;
          }
        });
        _updateLastSeen(msgRoom);
      } else {
        if (senderId != _userId && _getRoomStatus(msgRoom ?? '') == RoomMembershipStatus.joined) {
          NotificationService().showNotification(
            id: Random().nextInt(100000),
            title: msgRoom ?? 'Yeni Mesaj',
            body: '${chatItem.username}: ${chatItem.message}',
          );
        }
      }
    });

    _invitationSubscription = _chatService.invitations.listen((invitation) {
      _showPrivateChatInvitation(invitation);
    });

    _privateChatStartedSubscription = _chatService.privateChatSessions.listen((session) {
      _chatService.setCurrentRoom(session.room);
      _safeSetState(() {
        _currentRoom = session.room;
        _joined = true;
        _items.clear();
        _items.add(ChatItem(
          type: ChatItemType.system,
          message: 'Özel sohbet başladı.',
          createdAt: DateTime.now(),
        ));
      });
    });
  }

  void _showPrivateChatInvitation(PrivateChatInvitation invitation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özel Sohbet Daveti'),
        content: Text('${invitation.requesterUsername} sizinle özel bir sohbet başlatmak istiyor.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Reddet')),
          TextButton(
            onPressed: () {
              _chatService.acceptPrivateChat(invitation.requesterId);
              Navigator.of(context).pop();
            },
            child: const Text('Kabul Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRooms() async {
    _safeSetState(() { _loadingRooms = true; });
    try {
      final response = await ApiClient.get('/community/rooms');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<String> rooms = [];
        if (decoded is Map && decoded['rooms'] is List) {
          rooms = (decoded['rooms'] as List).map((e) => (e is Map ? (e['room'] ?? e['name'] ?? '') : e).toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
        }
        _safeSetState(() {
          _allRooms..clear()..addAll(rooms);
          for (final joinedRoom in _myJoinedRooms) { _ensureRoomExistsInList(joinedRoom); }
          for (final room in _allRooms) {
            final key = _normalizeRoomKey(room);
            if (_myJoinedRooms.any((r) => _normalizeRoomKey(r) == key)) {
              _roomStatuses[key] = RoomMembershipStatus.joined;
            }
          }
          _filteredRooms = List<String>.from(_allRooms);
          _loadingRooms = false;
        });
      }
    } catch (_) {}
    _safeSetState(() { _loadingRooms = false; });
  }

  void _filterRooms(String query) {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) {
      _safeSetState(() { _filteredRooms = List<String>.from(_allRooms); });
      return;
    }
    _safeSetState(() {
      _filteredRooms = _allRooms.where((room) => room.toLowerCase().contains(trimmedQuery)).toList();
    });
  }

  Future<void> _createRoom() async {
    final roomName = _createRoomController.text.trim();
    if (roomName.isEmpty) return;
    _safeSetState(() {
      _ensureRoomExistsInList(roomName);
      _setRoomStatus(roomName, RoomMembershipStatus.joined);
      _filteredRooms = List<String>.from(_allRooms);
    });
    _createRoomController.clear();
    await _joinRoom(roomName, isNewRoom: true);
  }

  Future<void> _refreshMessagesForRoom(String room) async {
    if (_userId == null) return;
    try {
      final response = await ApiClient.get('/community/messages?userId=$_userId&room=$room');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> messages = (decoded is List) ? decoded : (decoded['messages'] is List ? decoded['messages'] : []);
        _safeSetState(() {
          _items.clear();
          for (final item in messages) {
            final int? uId = item['userId'] is int ? item['userId'] : int.tryParse(item['userId']?.toString() ?? '');
            final String? sId = item['socketId']?.toString();
            if (uId != null && sId != null) {
              _chatService.userSocketIds[uId] = sId;
            }
            _items.add(ChatItem(
              type: ChatItemType.message,
              username: (item['username'] ?? 'Bilinmeyen').toString(),
              message: (item['message'] ?? '').toString(),
              room: room, 
              createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
              userId: uId,
              socketId: sId,
            ));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _joinRoom(String room, {bool isNewRoom = false}) async {
    if (_userId == null || _chatUsername == null) return;
    _safeSetState(() { _joiningRoom = true; _currentRoom = room; });
    try {
      await _refreshMessagesForRoom(room);
      _chatService.joinRoom(room, _userId!, _chatUsername!);
      _setRoomStatus(room, RoomMembershipStatus.joined);
      _updateLastSeen(room);
      _safeSetState(() { _joined = true; _joiningRoom = false; });
    } catch (_) {
      _safeSetState(() { _joiningRoom = false; });
    }
  }

  Future<void> _leaveRoom({String? roomName}) async {
    final roomToLeave = roomName ?? _currentRoom;
    if (_userId == null || roomToLeave == null) return;
    _leavingRoom = true;
    try {
      await ApiClient.post('/community/leave', {'userId': _userId, 'room': roomToLeave});
      _chatService.leaveRoom(roomToLeave, _userId!, _chatUsername!);
      _setRoomStatus(roomToLeave, RoomMembershipStatus.left);
      _safeSetState(() {
        if (roomName == null) {
          _joined = false;
          _items.clear();
          _currentRoom = null;
        }
        _filteredRooms = List<String>.from(_allRooms);
        _leavingRoom = false;
      });
    } catch (_) {
      _safeSetState(() { _leavingRoom = false; });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_joined || _currentRoom == null) return;
    _chatService.sendMessage(text, _userId!, _chatUsername!);
    _messageController.clear();
  }

  void _showRoomUsers() {
    final Map<int, String> uniqueUsersMap = {};
    for (var item in _items) {
      if (item.type == ChatItemType.message && item.userId != null && item.userId != _userId) {
        uniqueUsersMap[item.userId!] = item.username ?? 'Bilinmeyen';
      }
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (uniqueUsersMap.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('Odada etkileşimde bulunan kimse yok.')));
        return ListView(
          children: uniqueUsersMap.entries.map((entry) {
            final int userId = entry.key;
            final bool isOnline = _chatService.userSocketIds.containsKey(userId);
            return ListTile(
              leading: Icon(Icons.circle, color: isOnline ? Colors.green : Colors.grey, size: 12),
              title: Text(entry.value),
              subtitle: Text(isOnline ? 'Çevrimiçi' : 'Şu an ulaşılamıyor (Mesaj bekleniyor)'),
              onTap: () {
                Navigator.pop(context);
                _showPrivateChatRequestDialog(entry.value, userId);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showPrivateChatRequestDialog(String username, int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özel Sohbet'),
        content: Text('$username ile özel sohbet başlatmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              _chatService.sendPrivateChatRequest(userId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek gönderildi.')));
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _backToRoomBrowser() {
    if (_currentRoom != null) _updateLastSeen(_currentRoom!);
    _safeSetState(() { _joined = false; _messageController.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const gold = Color(0xFFFFE6A7);
    if (_loadingUser) return const Scaffold(body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(navy))));
    return WillPopScope(
      onWillPop: () async { if (_joined) { _backToRoomBrowser(); return false; } return true; },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (_joined) _backToRoomBrowser(); else Navigator.pop(context); }),
          title: Text(_joined ? (_currentRoom ?? 'Chat') : 'Community Rooms', style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            if (_joined) IconButton(icon: const Icon(Icons.people, color: gold), onPressed: _showRoomUsers),
            Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text(_connected ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI', style: TextStyle(color: _connected ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)))),
            Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(_chatUsername ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gold)))),
          ],
        ),
        body: _joined ? _buildChatRoom(navy, gold) : _buildRoomBrowser(navy, gold),
      ),
    );
  }

  Widget _buildRoomBrowser(Color navy, Color gold) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterRooms,
                  style: TextStyle(color: navy, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Oda ara...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search, color: navy.withOpacity(0.4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  )
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _createRoom,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: gold, size: 20),
                      const SizedBox(width: 4),
                      const Text("Oda Oluştur", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingRooms ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(navy))) : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredRooms.length,
            itemBuilder: (context, index) {
              final room = _filteredRooms[index];
              final status = _getRoomStatus(room);
              final isJoined = status == RoomMembershipStatus.joined;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: navy.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: navy.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.groups_rounded, color: navy),
                  ),
                  title: Text(room, style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 16)),
                  trailing: GestureDetector(
                    onTap: () {
                      if (isJoined) {
                        _leaveRoom(roomName: room);
                      } else {
                        _joinRoom(room);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: isJoined ? Colors.red.withOpacity(0.3) : navy.withOpacity(0.1)),
                        color: isJoined ? Colors.red.withOpacity(0.05) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isJoined ? "Ayrıl" : "Katıl",
                        style: TextStyle(
                          color: isJoined ? Colors.red.shade700 : navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  onTap: () => _joinRoom(room),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatRoom(Color navy, Color gold) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              if (item.type == ChatItemType.system) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: navy.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(item.message ?? '', style: TextStyle(fontStyle: FontStyle.italic, color: navy.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }
              final isMe = item.userId == _userId;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMe ? navy : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) Text(item.username ?? 'Bilinmeyen', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueGrey)),
                      Text(item.message ?? '', style: TextStyle(color: isMe ? Colors.white : navy, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      hintStyle: TextStyle(color: navy.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: navy,
                  child: IconButton(icon: Icon(Icons.send_rounded, color: gold, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
