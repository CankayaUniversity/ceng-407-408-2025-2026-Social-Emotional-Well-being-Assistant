import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ui_prototype/core/api/token_store.dart';

class CommunityRoomsScreen extends StatefulWidget {
  const CommunityRoomsScreen({super.key});

  @override
  State<CommunityRoomsScreen> createState() => _CommunityRoomsScreenState();
}

class _CommunityRoomsScreenState extends State<CommunityRoomsScreen> {
  static const String backendBaseUrl = 'http://10.0.2.2:3001';
  static const String socketBaseUrl = 'http://10.0.2.2:4000';

  static const String _anonymousModeKey = 'anonymous_mode';
  static const String _nicknameKey = 'user_nickname';

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createRoomController = TextEditingController();

  IO.Socket? _socket;

  final List<_ChatItem> _items = [];
  final List<String> _allRooms = [];
  List<String> _filteredRooms = [];

  // Oda bazlı kullanıcı durumu
  final Map<String, RoomMembershipStatus> _roomStatuses = {};

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
      final CurrentUser? user = await TokenStore.getCurrentUser();
      final prefs = await SharedPreferences.getInstance();

      if (user == null) {
        _safeSetState(() {
          _loadingUser = false;
          _loadingRooms = false;
          _initError =
          'Giriş yapan kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
        });
        return;
      }

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
      });

      _connectSocket();
      await _loadRooms();
    } catch (e) {
      debugPrint('INIT ERROR: $e');
      _safeSetState(() {
        _loadingUser = false;
        _loadingRooms = false;
        _initError = 'Community Rooms ekranı başlatılamadı.';
      });
    }
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
    _roomStatuses[_normalizeRoomKey(room)] = status;
  }

  void _ensureRoomExistsInList(String room) {
    final exists =
    _allRooms.any((r) => _normalizeRoomKey(r) == _normalizeRoomKey(room));

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
    });

    _socket!.onDisconnect((_) {
      debugPrint('SOCKET DISCONNECTED');
      _safeSetState(() {
        _connected = false;
      });
    });

    _socket!.onConnectError((data) {
      debugPrint('SOCKET CONNECT ERROR: $data');
    });

    _socket!.onError((data) {
      debugPrint('SOCKET ERROR: $data');
    });

    _socket!.on('system-message', (data) {
      final msg =
      data is Map ? (data['message'] ?? '').toString() : data.toString();

      if (msg.isEmpty) return;

      _safeSetState(() {
        _items.add(
          _ChatItem(
            type: ChatItemType.system,
            message: msg,
            createdAt: DateTime.now(),
          ),
        );
      });
    });

    _socket!.on('new-message', (data) {
      debugPrint('NEW MESSAGE EVENT: $data');

      if (data is Map) {
        _safeSetState(() {
          _items.add(
            _ChatItem(
              type: ChatItemType.message,
              username: (data['username'] ?? '').toString(),
              message: (data['message'] ?? '').toString(),
              createdAt:
              DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
                  DateTime.now(),
            ),
          );
        });
      }
    });

    _socket!.connect();
  }

  Future<void> _loadRooms() async {
    _safeSetState(() {
      _loadingRooms = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$backendBaseUrl/api/community/rooms'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);

        List<String> rooms = [];

        if (decoded is Map && decoded['rooms'] is List) {
          rooms = (decoded['rooms'] as List)
              .map((e) {
            if (e is Map) {
              return (e['room'] ?? e['name'] ?? '').toString().trim();
            }
            return e.toString().trim();
          })
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();
        }


        _safeSetState(() {
          _allRooms
            ..clear()
            ..addAll(rooms);

          // Eski status'ler kalsın, yeni odalar listeye eklensin
          for (final room in _allRooms) {
            _roomStatuses.putIfAbsent(
              _normalizeRoomKey(room),
                  () => RoomMembershipStatus.none,
            );
          }

          _filteredRooms = List<String>.from(_allRooms);
          _loadingRooms = false;
        });

        return;
      }
    } catch (e) {
      debugPrint('ROOMS LOAD ERROR: $e');
    }

    _safeSetState(() {
      _allRooms.clear();   // fallback yok artık

      for (final room in _allRooms) {
        _roomStatuses.putIfAbsent(
          _normalizeRoomKey(room),
              () => RoomMembershipStatus.none,
        );
      }

      _filteredRooms = List<String>.from(_allRooms);
      _loadingRooms = false;
    });
  }

  void _filterRooms(String query) {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      _safeSetState(() {
        _filteredRooms = List<String>.from(_allRooms);
      });
      return;
    }

    final ranked = _allRooms
        .map((room) => MapEntry(room, _similarityScore(trimmedQuery, room)))
        .where((entry) => entry.value > 0)
        .toList();

    ranked.sort((a, b) => b.value.compareTo(a.value));

    _safeSetState(() {
      _filteredRooms = ranked.map((e) => e.key).toList();
    });
  }

  int _similarityScore(String query, String roomName) {
    final q = query.toLowerCase().trim();
    final r = roomName.toLowerCase().trim();

    if (q.isEmpty || r.isEmpty) return 0;
    if (q == r) return 100;
    if (r.startsWith(q)) return 80;
    if (r.contains(q)) return 70;

    final qWords = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final rWords = r.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    int score = 0;

    for (final qw in qWords) {
      for (final rw in rWords) {
        if (rw == qw) {
          score += 25;
        } else if (rw.contains(qw) || qw.contains(rw)) {
          score += 15;
        }
      }
    }

    return score;
  }

  Future<void> _createRoom() async {
    final roomName = _createRoomController.text.trim();

    if (roomName.isEmpty) {
      _showSnack('Lütfen yeni oda için bir konu girin.');
      return;
    }

    if (_allRooms.any(
          (room) => _normalizeRoomKey(room) == _normalizeRoomKey(roomName),
    )) {
      _createRoomController.clear();
      _searchController.text = roomName;
      _filterRooms(roomName);
      _showSnack('Bu isimde bir oda zaten var. Mevcut odayı seçebilirsiniz.');
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
      final response = await http.get(
        Uri.parse(
          '$backendBaseUrl/api/community/messages?userId=$_userId&room=$room',
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> messages =
      decoded['messages'] is List ? decoded['messages'] : [];

      _safeSetState(() {
        _items.clear();

        for (final item in messages) {
          if (item is Map) {
            _items.add(
              _ChatItem(
                type: ChatItemType.message,
                username: (item['username'] ?? '').toString(),
                message: (item['message'] ?? '').toString(),
                createdAt:
                DateTime.tryParse((item['createdAt'] ?? '').toString()) ??
                    DateTime.now(),
              ),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('REFRESH MESSAGES ERROR: $e');
    }
  }

  Future<void> _joinRoom(String room, {bool isNewRoom = false}) async {
    if (_joiningRoom || _leavingRoom) return;

    if (!_userReady || _userId == null || _chatUsername == null) {
      _showSnack('Kullanıcı bilgileri henüz hazır değil.');
      return;
    }

    final trimmedRoom = room.trim();
    if (trimmedRoom.isEmpty) {
      _showSnack('Geçerli bir oda adı bulunamadı.');
      return;
    }

    // Eğer room list ekranından tekrar kendi joined odasına basıyorsa
    if (_currentRoom != null &&
        _normalizeRoomKey(_currentRoom!) == _normalizeRoomKey(trimmedRoom) &&
        _getRoomStatus(trimmedRoom) == RoomMembershipStatus.joined) {
      await _refreshMessagesForRoom(trimmedRoom);
      _safeSetState(() {
        _joined = true;
      });
      return;
    }

    _joiningRoom = true;

    try {
      final joinResponse = await http.post(
        Uri.parse('$backendBaseUrl/api/community/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'room': trimmedRoom,
        }),
      );

      debugPrint('JOIN STATUS: ${joinResponse.statusCode}');
      debugPrint('JOIN BODY: ${joinResponse.body}');

      if (joinResponse.statusCode < 200 || joinResponse.statusCode >= 300) {
        _showSnack('Odaya katılınamadı: ${joinResponse.statusCode}');
        _joiningRoom = false;
        return;
      }

      final messagesResponse = await http.get(
        Uri.parse(
          '$backendBaseUrl/api/community/messages?userId=$_userId&room=$trimmedRoom',
        ),
      );

      debugPrint('MESSAGES STATUS: ${messagesResponse.statusCode}');
      debugPrint('MESSAGES BODY: ${messagesResponse.body}');

      if (messagesResponse.statusCode < 200 ||
          messagesResponse.statusCode >= 300) {
        _showSnack('Mesajlar alınamadı.');
        _joiningRoom = false;
        return;
      }

      final decoded = jsonDecode(messagesResponse.body);
      final List<dynamic> messages =
      decoded['messages'] is List ? decoded['messages'] : [];

      _safeSetState(() {
        _currentRoom = trimmedRoom;
        _joined = true;
        _items.clear();

        _ensureRoomExistsInList(trimmedRoom);
        _setRoomStatus(trimmedRoom, RoomMembershipStatus.joined);

        for (final item in messages) {
          if (item is Map) {
            _items.add(
              _ChatItem(
                type: ChatItemType.message,
                username: (item['username'] ?? '').toString(),
                message: (item['message'] ?? '').toString(),
                createdAt:
                DateTime.tryParse((item['createdAt'] ?? '').toString()) ??
                    DateTime.now(),
              ),
            );
          }
        }

        _filteredRooms = List<String>.from(_allRooms);
      });

      final joinPayload = {
        'room': trimmedRoom,
        'username': _chatUsername,
        'userId': _userId,
      };

      _socket?.emit('join-room', joinPayload);

      if (isNewRoom) {
        _showSnack('Yeni oda oluşturuldu ve katılındı: $trimmedRoom');
      } else {
        _showSnack('Odaya katılındı: $trimmedRoom');
      }
    } catch (e) {
      debugPrint('JOIN ERROR: $e');
      _showSnack('Odaya katılma işlemi başarısız oldu.');
    } finally {
      _joiningRoom = false;
    }
  }

  void _backToRoomBrowser() {
    _safeSetState(() {
      _joined = false;
      _messageController.clear();
      // _currentRoom aynı kalsın, çünkü kullanıcı hala o odanın üyesi
      // Böylece listeye dönüp tekrar aynı odaya girebilir
      if (_currentRoom != null) {
        _setRoomStatus(_currentRoom!, RoomMembershipStatus.joined);
      }
    });
  }

  Future<void> _leaveRoom() async {
    if (_leavingRoom) return;

    final roomToLeave = _currentRoom;

    if (roomToLeave == null || _userId == null) {
      _safeSetState(() {
        _joined = false;
        _currentRoom = null;
        _items.clear();
        _messageController.clear();
      });
      return;
    }

    _leavingRoom = true;

    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/community/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'room': roomToLeave,
        }),
      );

      debugPrint('LEAVE STATUS: ${response.statusCode}');
      debugPrint('LEAVE BODY: ${response.body}');
    } catch (e) {
      debugPrint('LEAVE ERROR: $e');
    }

    _socket?.emit('leave-room', {
      'room': roomToLeave,
      'userId': _userId,
    });

    _safeSetState(() {
      _joined = false;
      _items.clear();
      _messageController.clear();

      // Oda listede kalsın ama durumu left olsun
      _ensureRoomExistsInList(roomToLeave);
      _setRoomStatus(roomToLeave, RoomMembershipStatus.left);

      // Artık bu oda aktif oda değil
      _currentRoom = null;

      _filteredRooms = List<String>.from(_allRooms);
    });

    await _loadRooms();
    _showSnack('Odadan ayrıldınız.');

    _leavingRoom = false;
  }

  void _sendMessage() {
    if (!_userReady || _userId == null || _chatUsername == null) {
      _showSnack('Kullanıcı bilgileri henüz hazır değil.');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || !_joined || _currentRoom == null) return;

    final payload = {
      'room': _currentRoom,
      'message': text,
      'userId': _userId,
      'username': _chatUsername,
    };

    _socket?.emit('send-message', payload);
    _messageController.clear();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildStatusBadge(String room) {
    final status = _getRoomStatus(room);

    if (status == RoomMembershipStatus.joined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Text(
          'Joined',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (status == RoomMembershipStatus.left) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          'Left',
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRoomBrowser() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              _safeSetState(() {});
              _filterRooms(value);
            },
            decoration: InputDecoration(
              hintText: 'Katılmak istediğin oda konusunu yaz...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                  _safeSetState(() {});
                  _filterRooms('');
                },
                icon: const Icon(Icons.clear),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yeni oda oluştur',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _createRoomController,
                  decoration: InputDecoration(
                    hintText: 'Örn: Internship Stress, Breakup Support',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Room'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _searchController.text.trim().isEmpty
                  ? 'Open Rooms'
                  : 'Matching Rooms',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loadingRooms
              ? const Center(child: CircularProgressIndicator())
              : _filteredRooms.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Uygun oda bulunamadı.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İstersen yukarıdan kendi odanı oluşturabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            itemCount: _filteredRooms.length,
            itemBuilder: (context, index) {
              final room = _filteredRooms[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(room),
                  subtitle: const Text('Tap to join this room'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(room),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 18),
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
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oda: ${_currentRoom ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _anonymousMode
                    ? 'Kullanıcı: ${_chatUsername ?? "Anonim"} (anonim)'
                    : 'Kullanıcı: ${_realUsername ?? ""} ($_userId)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _leaveRoom,
                  child: const Text('Ayrıl'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(
            child: Text('Henüz mesaj yok. Sohbeti başlatabilirsin.'),
          )
              : ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];

              if (item.type == ChatItemType.system) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(item.message),
                    ),
                  ),
                );
              }

              return ListTile(
                title: Text(item.username ?? 'Bilinmeyen kullanıcı'),
                subtitle: Text(item.message),
                trailing: Text(
                  '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yaz...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    if (_joined && _currentRoom != null && _userId != null) {
      _socket?.emit('leave-room', {
        'room': _currentRoom,
        'userId': _userId,
      });
    }

    _socket?.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _createRoomController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_userReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Community Rooms')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _initError ?? 'Kullanıcı bilgileri yüklenemedi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_joined) {
          _backToRoomBrowser();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_joined) {
                _backToRoomBrowser();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _joined ? (_currentRoom ?? 'Community Room') : 'Community Rooms',
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _connected ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI',
                  style: TextStyle(
                    color: _connected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _chatUsername ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _joined ? _buildChatRoom() : _buildRoomBrowser(),
      ),
    );
  }
}

enum ChatItemType { system, message }

enum RoomMembershipStatus {
  none,
  joined,
  left,
}

class _ChatItem {
  final ChatItemType type;
  final String? username;
  final String message;
  final DateTime createdAt;

  _ChatItem({
    required this.type,
    this.username,
    required this.message,
    required this.createdAt,
  });
}