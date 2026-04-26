import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ui_prototype/core/api/token_store.dart';
import 'package:ui_prototype/core/services/notification_service.dart';

class CommunityRoomsScreen extends StatefulWidget {
  const CommunityRoomsScreen({super.key});

  @override
  State<CommunityRoomsScreen> createState() => _CommunityRoomsScreenState();
}

class _CommunityRoomsScreenState extends State<CommunityRoomsScreen> {
  static const String backendBaseUrl = 'https://backend-production-66b91.up.railway.app';
  static const String socketBaseUrl = 'https://sewa-community-chatroom-production.up.railway.app';

  static const String _anonymousModeKey = 'anonymous_mode';
  static const String _nicknameKey = 'user_nickname';
  static const String _joinedRoomsKey = 'joined_community_rooms';

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createRoomController = TextEditingController();

  IO.Socket? _socket;

  final List<_ChatItem> _items = [];
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

      _safeSetState(() {
        _userId = user.id;
        _realUsername = user.username;
        _chatUsername = resolvedChatName;
        _anonymousMode = anonymousMode;
        _nickname = nickname;
        _userReady = true;
        _loadingUser = false;
        _initError = null;

        // Kullanıcıya özel katılmış odaları yükle
        _myJoinedRooms.clear();
        final String userJoinedKey = '${_joinedRoomsKey}_${user.id}';
        final List<String> savedJoinedRooms = prefs.getStringList(userJoinedKey) ?? [];
        for (final room in savedJoinedRooms) {
          _myJoinedRooms.add(room);
          _roomStatuses[_normalizeRoomKey(room)] = RoomMembershipStatus.joined;
        }
      });

      _connectSocket();
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
        final response = await http.get(
          Uri.parse('$backendBaseUrl/api/community/messages?userId=$_userId&room=$room'),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final List<dynamic> messages = decoded['messages'] is List ? decoded['messages'] : [];
          for (final m in messages) {
            final createdAt = DateTime.tryParse(m['createdAt'] ?? '');
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

  void _connectSocket() {
    _socket?.dispose();

    _socket = IO.io(
      socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('SOCKET CONNECTED');
      _safeSetState(() {
        _connected = true;
      });
      // Katıldığımız tüm odalara socket üzerinden bağlan
      for (final room in _myJoinedRooms) {
        _socket?.emit('join-room', {
          'room': room,
          'username': _chatUsername,
          'userId': _userId,
        });
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('SOCKET DISCONNECTED');
      _safeSetState(() {
        _connected = false;
      });
    });

    _socket!.on('new-message', (data) {
      if (data is Map) {
        final String msgRoom = (data['room'] ?? '').toString();
        final String sender = (data['username'] ?? '').toString();
        final String messageText = (data['message'] ?? '').toString();
        final int? senderId = int.tryParse(data['userId']?.toString() ?? '');

        // 1. Durum: Odanın içindeyiz, mesajı listeye ekle
        if (_joined && _currentRoom != null && _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(msgRoom)) {
          _safeSetState(() {
            _items.add(
              _ChatItem(
                type: ChatItemType.message,
                username: sender,
                message: messageText,
                createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ?? DateTime.now(),
              ),
            );
          });
          _updateLastSeen(msgRoom);
        } else {
          // 2. Durum: Mesaj başkasından geldiyse ve üye olduğumuz bir odaysa bildirim gönder
          if (senderId != _userId && _getRoomStatus(msgRoom) == RoomMembershipStatus.joined) {
            NotificationService().showNotification(
              id: Random().nextInt(100000),
              title: msgRoom,
              body: '$sender: $messageText',
            );
          }
        }
      }
    });

    _socket!.connect();
  }

  Future<void> _loadRooms() async {
    _safeSetState(() { _loadingRooms = true; });
    try {
      final response = await http.get(Uri.parse('$backendBaseUrl/api/community/rooms'));
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
      final response = await http.get(Uri.parse('$backendBaseUrl/api/community/messages?userId=$_userId&room=$room'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> messages = decoded['messages'] is List ? decoded['messages'] : [];
        _safeSetState(() {
          _items.clear();
          for (final item in messages) {
            _items.add(_ChatItem(
              type: ChatItemType.message,
              username: (item['username'] ?? '').toString(),
              message: (item['message'] ?? '').toString(),
              createdAt: DateTime.tryParse((item['createdAt'] ?? '').toString()) ?? DateTime.now(),
            ));
          }
        });
      }
    } catch (e) {}
  }

  Future<void> _joinRoom(String room, {bool isNewRoom = false}) async {
    if (_joiningRoom || _leavingRoom) return;
    final trimmedRoom = room.trim();
    if (trimmedRoom.isEmpty) return;

    if (_currentRoom != null && _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(trimmedRoom) && _getRoomStatus(trimmedRoom) == RoomMembershipStatus.joined) {
      await _refreshMessagesForRoom(trimmedRoom);
      _safeSetState(() { _joined = true; });
      return;
    }

    _joiningRoom = true;
    try {
      final joinResponse = await http.post(
        Uri.parse('$backendBaseUrl/api/community/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'room': trimmedRoom}),
      );

      if (joinResponse.statusCode == 200) {
        final msgRes = await http.get(Uri.parse('$backendBaseUrl/api/community/messages?userId=$_userId&room=$trimmedRoom'));
        final decoded = jsonDecode(msgRes.body);
        final List<dynamic> messages = decoded['messages'] is List ? decoded['messages'] : [];

        _safeSetState(() {
          _currentRoom = trimmedRoom;
          _joined = true;
          _items.clear();
          _setRoomStatus(trimmedRoom, RoomMembershipStatus.joined);
          for (final item in messages) {
            _items.add(_ChatItem(
              type: ChatItemType.message,
              username: item['username'],
              message: item['message'],
              createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
            ));
          }
          _filteredRooms = List<String>.from(_allRooms);
        });
        _updateLastSeen(trimmedRoom);
        _socket?.emit('join-room', {'room': trimmedRoom, 'username': _chatUsername, 'userId': _userId});
      }
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

  Future<void> _leaveRoom() async {
    if (_leavingRoom || _currentRoom == null) return;
    final roomToLeave = _currentRoom!;
    _leavingRoom = true;
    try {
      await http.post(
        Uri.parse('$backendBaseUrl/api/community/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'room': roomToLeave}),
      );
      _socket?.emit('leave-room', {'room': roomToLeave, 'userId': _userId});
      _safeSetState(() {
        _joined = false;
        _items.clear();
        _setRoomStatus(roomToLeave, RoomMembershipStatus.left);
        _currentRoom = null;
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
    _socket?.emit('send-message', {'room': _currentRoom, 'message': text, 'userId': _userId, 'username': _chatUsername});
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return WillPopScope(
      onWillPop: () async {
        if (_joined) { _backToRoomBrowser(); return false; }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (_joined) _backToRoomBrowser(); else Navigator.pop(context); }),
          title: Text(_joined ? (_currentRoom ?? 'Chat') : 'Community Rooms'),
          actions: [
            Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text(_connected ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI', style: TextStyle(color: _connected ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)))),
            Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text(_chatUsername ?? '', style: const TextStyle(fontSize: 12)))),
          ],
        ),
        body: _joined ? _buildChatRoom() : _buildRoomBrowser(),
      ),
    );
  }

  Widget _buildStatusBadge(String room) {
    final status = _getRoomStatus(room);

    if (status == RoomMembershipStatus.joined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade300)),
        child: Text('Joined', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    if (status == RoomMembershipStatus.left) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade300)),
        child: Text('Left', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRoomBrowser() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: TextField(controller: _searchController, onChanged: _filterRooms, decoration: InputDecoration(hintText: 'Oda ara...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                TextField(controller: _createRoomController, decoration: const InputDecoration(hintText: 'Yeni oda konusu...')),
                Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _createRoom, child: const Text('Create Room'))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loadingRooms ? const Center(child: CircularProgressIndicator()) : ListView.builder(
            itemCount: _filteredRooms.length,
            itemBuilder: (context, index) {
              final room = _filteredRooms[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(room),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(room),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
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

  Widget _buildChatRoom() {
    return Column(
      children: [
        ListTile(tileColor: Colors.grey.shade100, title: Text('Oda: $_currentRoom', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: ElevatedButton(onPressed: _leaveRoom, child: const Text('Ayrıl'))),
        Expanded(child: ListView.builder(itemCount: _items.length, itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(title: Text(item.username ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(item.message), trailing: Text('${item.createdAt.hour}:${item.createdAt.minute}', style: const TextStyle(fontSize: 10)));
        })),
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Mesaj yaz...'), onSubmitted: (_) => _sendMessage())), IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage)])),
      ],
    );
  }

  @override void dispose() { _isDisposed = true; _socket?.dispose(); super.dispose(); }
}

enum ChatItemType { system, message }
enum RoomMembershipStatus { none, joined, left }
class _ChatItem { final ChatItemType type; final String? username; final String message; final DateTime createdAt; _ChatItem({required this.type, this.username, required this.message, required this.createdAt}); }
