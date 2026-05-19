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

  // Oda bazlı kullanıcı durumu
  final Map<String, RoomMembershipStatus> _roomStatuses = {};
  // Kullanıcının katıldığı odaların listesi (Hafıza için)
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

  // Şu an chat ekranında açık olan oda
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
      // Bildirim servisini başlat
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

      // Kullanıcıya özel nickname ve anonim modu yükle
      final anonymousMode = prefs.getBool(_anonymousModeKey) ?? true;
      final nickname = (prefs.getString(_nicknameKey) ?? '').trim();

      final resolvedChatName = anonymousMode
          ? (nickname.isNotEmpty ? nickname : 'Anonim')
          : user.username;

      final String userJoinedKey = '${_joinedRoomsKey}_${user.id}';
      final List<String> savedJoinedRooms = prefs.getStringList(userJoinedKey) ?? [];
      final List<String>? remoteJoinedRooms = await _fetchRemoteJoinedRooms();
      final List<String> joinedRooms = remoteJoinedRooms ?? savedJoinedRooms;

      _safeSetState(() {
        _userId = user.id;
        _realUsername = user.username;
        _chatUsername = resolvedChatName;
        _anonymousMode = anonymousMode;
        _nickname = nickname;
        _userReady = true;
        _loadingUser = false;
        _initError = null;

        _myJoinedRooms.clear();
        for (final room in joinedRooms) {
          _myJoinedRooms.add(room);
          _roomStatuses[_normalizeRoomKey(room)] = RoomMembershipStatus.joined;
        }
      });

      if (remoteJoinedRooms != null) {
        await prefs.setStringList(userJoinedKey, joinedRooms);
      }

      await _initializeChatService();
      await _loadRooms();
      // Çevrimdışı mesajları kontrol et
      await _checkMessagesWhileAway();
    } catch (e) {
      debugPrint('INIT ERROR: $e');
      _safeSetState(() {
        _loadingUser = false;
        _loadingRooms = false;
        _initError = 'Community Rooms ekranı başlatılamadı.';
      });
    }
  }

  // Çevrimdışı mesaj bildirimi (Catch-up)
  Future<void> _checkMessagesWhileAway() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    int totalNew = 0;

    for (final room in _myJoinedRooms) {
      final key = _normalizeRoomKey(room);
      final lastSeenStr = prefs.getString('last_seen_${_userId}_$key');
      final lastSeen = lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);

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
      NotificationService().showNotification(
        id: 999,
        title: 'Community Rooms',
        body: 'Hoş geldin! Sen yokken $totalNew yeni mesaj geldi.',
      );
    }
  }

  // Okundu bilgisi güncelleme
  Future<void> _updateLastSeen(String room) async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _normalizeRoomKey(room);
    await prefs.setString('last_seen_${_userId}_$key', DateTime.now().toIso8601String());
  }

  Future<List<String>?> _fetchRemoteJoinedRooms() async {
    try {
      final response = await ApiClient.get('/community/joined');
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['rooms'] is List) {
        return (decoded['rooms'] as List)
            .map((e) => e is Map ? (e['room'] ?? e['name'] ?? '').toString() : e.toString())
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('FETCH REMOTE JOINED ROOMS FAILED: $e');
    }
    return null;
  }

  // Hafızaya kaydetme yardımcısı
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

  Future<void> _initializeChatService() async {
    if (_userId == null || _chatUsername == null) return;

    await _chatService.connect(_userId!, _chatUsername!);

    _connectionSubscription = _chatService.connectionStatus.listen((isConnected) {
      _safeSetState(() {
        _connected = isConnected;
      });
      if (isConnected) {
        // Katıldığımız tüm odalara socket üzerinden bağlan
        for (final room in _myJoinedRooms) {
          _chatService.joinRoom(room, _userId!, _chatUsername!);
        }
      }
    });

    _messageSubscription = _chatService.messages.listen((chatItem) {
      final msgRoom = chatItem.room; // Use the room from the message itself
      final sender = chatItem.username ?? 'Bilinmeyen';
      final messageText = chatItem.message ?? '';
      final senderId = chatItem.userId;

      if (_joined && msgRoom != null && _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(msgRoom)) {
        _safeSetState(() {
          _items.add(chatItem);
        });
        _updateLastSeen(msgRoom);
      } else {
        if (senderId != _userId && _getRoomStatus(msgRoom ?? '') == RoomMembershipStatus.joined) {
          NotificationService().showNotification(
            id: Random().nextInt(100000),
            title: msgRoom ?? 'Yeni Mesaj',
            body: '$sender: $messageText',
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
          message: 'Özel sohbet başladı. Katılımcılar: ${session.participants.join(', ')}',
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
        content: Text('${invitation.requesterUsername} sizinle özel bir sohbet başlatmak istiyor. Kabul ediyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Reddet'),
          ),
          TextButton(
            onPressed: () {
              _chatService.acceptPrivateChat(invitation.requesterId,
                  receiverId: _userId, receiverUsername: _chatUsername);
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
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
            } else if (_roomStatuses[key] != RoomMembershipStatus.left) {
              _roomStatuses.putIfAbsent(key, () => RoomMembershipStatus.none);
            }
          }
          _filteredRooms = List<String>.from(_allRooms);
          _loadingRooms = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('ROOMS LOAD ERROR: $e');
    }
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

    if (_allRooms.any((room) => _normalizeRoomKey(room) == _normalizeRoomKey(roomName))) {
      _createRoomController.clear();
      _searchController.text = roomName;
      _filterRooms(roomName);
      return;
    }

    _safeSetState(() {
      _ensureRoomExistsInList(roomName);
      _setRoomStatus(roomName, RoomMembershipStatus.joined);
      _filteredRooms = List<String>.from(_allRooms);
    });

    _createRoomController.clear();
    _searchController.clear();
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
            _items.add(ChatItem(
              type: ChatItemType.message,
              username: (item['username'] ?? 'Bilinmeyen').toString(),
              message: (item['message'] ?? '').toString(),
              room: room, // Populate room
              createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
              userId: int.tryParse(item['userId']?.toString() ?? ''),
              socketId: item['socketId']?.toString(),
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('REFRESH MESSAGES ERROR: $e');
    }
  }

  Future<void> _joinRoom(String room, {bool isNewRoom = false}) async {
    if (_joiningRoom || _leavingRoom) return;
    final trimmedRoom = room.trim();
    if (trimmedRoom.isEmpty || _userId == null) return;

    // ALWAYS inform the service that we are switching/joining this room
    _chatService.joinRoom(trimmedRoom, _userId!, _chatUsername!);

    if (_currentRoom != null && _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(trimmedRoom) && _getRoomStatus(trimmedRoom) == RoomMembershipStatus.joined) {
      await _refreshMessagesForRoom(trimmedRoom);
      _safeSetState(() { _joined = true; });
      return;
    }

    _joiningRoom = true;
    try {
      // 1. Tell the backend we are joining (Critical for message persistence)
      await ApiClient.post('/community/join', {'userId': _userId, 'room': trimmedRoom});

      // 2. Fetch historical messages
      final msgRes = await ApiClient.get('/community/messages?userId=$_userId&room=$trimmedRoom');
      final decoded = jsonDecode(msgRes.body);
      final List<dynamic> messages = (decoded is List) ? decoded : (decoded['messages'] is List ? decoded['messages'] : []);

      _safeSetState(() {
        _currentRoom = trimmedRoom;
        _joined = true;
        _items.clear();
        _setRoomStatus(trimmedRoom, RoomMembershipStatus.joined);
        for (final item in messages) {
          _items.add(ChatItem(
            type: ChatItemType.message,
            username: (item['username'] ?? 'Bilinmeyen').toString(),
            message: (item['message'] ?? '').toString(),
            room: trimmedRoom, // Populate room
            createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
            userId: int.tryParse(item['userId']?.toString() ?? ''),
            socketId: item['socketId']?.toString(),
          ));
        }
        _filteredRooms = List<String>.from(_allRooms);
      });
      _updateLastSeen(trimmedRoom);
    } catch (e) {
      debugPrint('JOIN ERROR: $e');
    } finally {
      _joiningRoom = false;
    }
  }

  void _backToRoomBrowser() {
    if (_currentRoom != null) {
      _updateLastSeen(_currentRoom!);
    }
    _safeSetState(() {
      _joined = false;
      _messageController.clear();
    });
  }

  Future<void> _leaveRoom({String? roomName}) async {
    final roomToLeave = roomName ?? _currentRoom;
    if (_leavingRoom || roomToLeave == null) return;
    _leavingRoom = true;
    try {
      // 1. Tell backend we are leaving
      await ApiClient.post('/community/leave', {'userId': _userId, 'room': roomToLeave});

      // 2. Tell socket service
      _chatService.leaveRoom(roomToLeave, _userId!, _chatUsername!);

      _safeSetState(() {
        if (roomName == null) {
          _joined = false;
          _items.clear();
        }
        if (!roomToLeave.startsWith('private-')) {
          _setRoomStatus(roomToLeave, RoomMembershipStatus.left);
        }
        if (roomName == null) {
          _currentRoom = null;
        }
        _filteredRooms = List<String>.from(_allRooms);
      });
    } catch (e) {
      debugPrint('LEAVE ERROR: $e');
    } finally {
      _leavingRoom = false;
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_joined || _currentRoom == null) return;
    _chatService.sendMessage(text, _userId!, _chatUsername!);
    _messageController.clear();
  }

  void _showRoomUsers() {
    // This is a placeholder for fetching users in a room.
    // In a real app, you'd need an API endpoint to get users for a room.
    // For now, we'll use the users from the messages in the chat.
    final roomUsers = _items
        .where((item) => item.type == ChatItemType.message && item.userId != _userId)
        .map((item) =>
            {'username': item.username, 'userId': item.userId, 'socketId': item.socketId})
        .toList();

    final uniqueUsers = <String, Map<String, dynamic>>{};
    for (var user in roomUsers) {
      if (user['username'] != null) {
        uniqueUsers[user['username'] as String] = user;
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: uniqueUsers.values.map((user) {
            return ListTile(
              title: Text(user['username']),
              onTap: () {
                Navigator.pop(context);
                _showPrivateChatRequestDialog(user['username'], user['socketId']);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showPrivateChatRequestDialog(String username, String? socketId) {
    if (socketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start private chat. User is not available.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Chat'),
        content: Text('$username ile özel sohbet başlatmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              _chatService.sendPrivateChatRequest(socketId,
                  requesterId: _userId, requesterUsername: _chatUsername);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Özel sohbet isteği gönderildi.')),
              );
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const mint = Color(0xFFD6E5E3);
    const gold = Color(0xFFFFE6A7);

    if (_loadingUser) return const Scaffold(backgroundColor: mint, body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(navy))));

    return WillPopScope(
      onWillPop: () async {
        if (_joined) { _backToRoomBrowser(); return false; }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (_joined) _backToRoomBrowser(); else Navigator.pop(context); }),
          title: Text(_joined ? (_currentRoom ?? 'Chat') : 'Community Rooms', style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            if (_joined && !_currentRoom!.startsWith('private-'))
              IconButton(
                icon: const Icon(Icons.people, color: gold),
                onPressed: _showRoomUsers,
              ),
            Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text(_connected ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI', style: TextStyle(color: _connected ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)))),
            Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(_chatUsername ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gold)))),
          ],
        ),
        body: _joined ? _buildChatRoom(navy, mint, gold) : _buildRoomBrowser(navy, mint, gold),
      ),
    );
  }

  Widget _buildStatusBadge(String room, Color navy, Color gold) {
    final status = _getRoomStatus(room);

    if (status == RoomMembershipStatus.joined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: navy.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: navy.withOpacity(0.3))),
        child: Text('Joined', style: TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w900)),
      );
    }

    if (status == RoomMembershipStatus.left) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.3))),
        child: Text('Left', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w900)),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRoomBrowser(Color navy, Color mint, Color gold) {
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

        const SizedBox(height: 10),
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: navy.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.groups_rounded, color: navy),
                  ),
                  title: Text(room, style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 16)),
                  subtitle: Row(
                    children: [
                      Text("Aktif Grup", style: TextStyle(fontWeight: FontWeight.w700, color: navy.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
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

  Widget _categoryChip(String label, bool isSelected, Color navy, Color gold) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? navy : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? navy : navy.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : navy.withOpacity(0.6),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildChatRoom(Color navy, Color mint, Color gold) {
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


enum RoomMembershipStatus {
  none,
  joined,
  left,
}
