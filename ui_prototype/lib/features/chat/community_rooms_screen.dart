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

  // Profil ekranında kullandığın key'ler farklıysa sadece bunları değiştir.
  static const String _anonymousModeKey = 'anonymous_mode';
  static const String _nicknameKey = 'user_nickname';

  final TextEditingController _roomController =
  TextEditingController(text: 'room1');
  final TextEditingController _messageController = TextEditingController();

  IO.Socket? _socket;
  final List<_ChatItem> _items = [];

  bool _connected = false;
  bool _isDisposed = false;
  bool _joined = false;
  bool _userReady = false;
  bool _loadingUser = true;

  int? _userId;

  // Gerçek hesap bilgisi
  String? _realUsername;

  // Chat'te gösterilecek isim
  String? _chatUsername;

  bool _anonymousMode = false;
  String? _nickname;

  String? _currentRoom;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final CurrentUser? user = await TokenStore.getCurrentUser();
      final prefs = await SharedPreferences.getInstance();

      if (user == null) {
        debugPrint('CHAT INIT ERROR: current user not found');
        _safeSetState(() {
          _loadingUser = false;
          _initError = 'No logged in user found. Please login again.';
        });
        return;
      }

      final anonymousMode = prefs.getBool(_anonymousModeKey) ?? true;
      final nickname = (prefs.getString(_nicknameKey) ?? '').trim();

      final resolvedChatName = anonymousMode
          ? (nickname.isNotEmpty ? nickname : 'Anonymous')
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

      debugPrint(
        'AUTH USER LOADED: userId=$_userId, real=$_realUsername, chat=$_chatUsername, anonymous=$_anonymousMode, nickname=$_nickname',
      );

      _connectSocket();
    } catch (e) {
      debugPrint('CHAT INIT ERROR: $e');
      _safeSetState(() {
        _loadingUser = false;
        _initError = 'Chat user could not be initialized';
      });
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed) return;
    setState(fn);
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

      debugPrint('SYSTEM MESSAGE: $msg');

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

  Future<void> _joinRoom() async {
    if (!_userReady || _userId == null || _chatUsername == null) {
      _showSnack('User is not ready yet');
      return;
    }

    final room = _roomController.text.trim();
    if (room.isEmpty) {
      _showSnack('Please enter a room name');
      return;
    }

    try {
      final joinResponse = await http.post(
        Uri.parse('$backendBaseUrl/api/community/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'room': room,
        }),
      );

      debugPrint('JOIN STATUS: ${joinResponse.statusCode}');
      debugPrint('JOIN BODY: ${joinResponse.body}');

      if (joinResponse.statusCode < 200 || joinResponse.statusCode >= 300) {
        _showSnack('Join failed: ${joinResponse.statusCode}');
        return;
      }

      final messagesResponse = await http.get(
        Uri.parse(
          '$backendBaseUrl/api/community/messages?userId=$_userId&room=$room',
        ),
      );

      debugPrint('MESSAGES STATUS: ${messagesResponse.statusCode}');
      debugPrint('MESSAGES BODY: ${messagesResponse.body}');

      if (messagesResponse.statusCode < 200 ||
          messagesResponse.statusCode >= 300) {
        _showSnack('Could not fetch messages');
        return;
      }

      final decoded = jsonDecode(messagesResponse.body);
      final List<dynamic> messages =
      decoded['messages'] is List ? decoded['messages'] : [];

      _safeSetState(() {
        _currentRoom = room;
        _joined = true;
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

      final joinPayload = {
        'room': room,
        'username': _chatUsername,
        'userId': _userId,
      };

      debugPrint('JOIN ROOM SOCKET PAYLOAD: $joinPayload');
      _socket?.emit('join-room', joinPayload);

      _showSnack('Joined room: $room');
    } catch (e) {
      debugPrint('JOIN ERROR: $e');
      _showSnack('Join failed');
    }
  }

  Future<void> _leaveRoom() async {
    if (_currentRoom == null || _userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/community/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'room': _currentRoom,
        }),
      );

      debugPrint('LEAVE STATUS: ${response.statusCode}');
      debugPrint('LEAVE BODY: ${response.body}');
    } catch (e) {
      debugPrint('LEAVE ERROR: $e');
    }

    _socket?.emit('leave-room');

    _safeSetState(() {
      _joined = false;
      _currentRoom = null;
    });

    _showSnack('Left room');
  }

  void _sendMessage() {
    if (!_userReady || _userId == null || _chatUsername == null) {
      _showSnack('User is not ready yet');
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

    debugPrint('SEND PAYLOAD: $payload');
    _socket?.emit('send-message', payload);
    _messageController.clear();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    if (_joined) {
      _socket?.emit('leave-room');
    }

    _socket?.dispose();
    _roomController.dispose();
    _messageController.dispose();

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
              _initError ?? 'User could not be loaded.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Rooms'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _connected ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: _connected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _joinRoom,
                  child: const Text('Join'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _leaveRoom,
                  child: const Text('Leave'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _anonymousMode
                    ? 'User: ${_chatUsername ?? "Anonymous"} (anonymous)'
                    : 'User: ${_realUsername ?? ""} ($_userId)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_currentRoom != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Joined room: $_currentRoom'),
            ),
          Expanded(
            child: ListView.builder(
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
                  title: Text(item.username ?? 'unknown'),
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
                      hintText: 'Type message...',
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
      ),
    );
  }
}

enum ChatItemType { system, message }

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