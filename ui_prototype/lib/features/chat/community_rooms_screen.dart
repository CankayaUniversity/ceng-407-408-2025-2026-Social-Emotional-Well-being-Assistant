import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CommunityRoomsScreen extends StatefulWidget {
  const CommunityRoomsScreen({super.key});

  @override
  State<CommunityRoomsScreen> createState() => _CommunityRoomsScreenState();
}

class _CommunityRoomsScreenState extends State<CommunityRoomsScreen> {
  static const String _serverUrl = 'https://sewa-community-chatroom-production.up.railway.app/';

  late final String _username;
  IO.Socket? _socket;

  final TextEditingController _roomCtrl = TextEditingController(text: 'room1');
  final TextEditingController _msgCtrl = TextEditingController();

  String? _currentRoom;
  bool _connected = false;

  final List<_ChatItem> _items = [];

  bool _isDisposed = false; // ✅ kritik

  @override
  void initState() {
    super.initState();
    _username = 'anon_${1000 + Random().nextInt(9000)}';
    _connectSocket();
  }

  void _safeSetState(VoidCallback fn) {
    // ✅ widget öldüyse veya disposed olduysa setState yapma
    if (!mounted || _isDisposed) return;
    setState(fn);
  }

  void _connectSocket() {
    // Eski socket varsa temizle
    _socket?.off('system-message');
    _socket?.off('new-message');
    _socket?.off('connect');
    _socket?.off('disconnect');
    _socket?.off('connect_error');
    _socket?.off('connectError');
    _socket?.off('error');
    _socket?.disconnect();
    _socket?.dispose();

    final socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(3000)
          .build(),
    );

    socket.onConnect((_) {
      debugPrint('SOCKET CONNECTED');
      _safeSetState(() => _connected = true);
      _addSystem('Connected as $_username');

      if (_currentRoom != null) {
        socket.emit('join-room', {'room': _currentRoom, 'username': _username});
        _addSystem('Re-joined room: $_currentRoom');
      }
    });

    socket.onDisconnect((_) {
      debugPrint('SOCKET DISCONNECTED');
      _safeSetState(() => _connected = false);
      _addSystem('Disconnected');
    });

    socket.onConnectError((err) {
      debugPrint('CONNECT ERROR: $err');
      _addSystem('Connect error: $err');
    });

    socket.onError((err) {
      debugPrint('SOCKET ERROR: $err');
      _addSystem('Socket error: $err');
    });

    socket.on('system-message', (data) {
      final msg = (data is Map && data['message'] != null) ? '${data['message']}' : '$data';
      _addSystem(msg);
    });

    socket.on('new-message', (data) {
      final map = (data is Map) ? data : {};

      final room = (map['room'] ?? _currentRoom ?? '<room>').toString();
      final user = (map['username'] ?? map['user'] ?? '<user>').toString();

      final msgValue = map['message'] ?? map['text'] ?? data;
      final msg = msgValue.toString();

      _addMessage(room: room, user: user, text: msg, isMe: user == _username);
    });

    _socket = socket;
    socket.connect();
  }

  void _joinRoom() {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) return;

    if (!_connected) {
      _addSystem('Not connected yet.');
      return;
    }

    _safeSetState(() => _currentRoom = room);
    _socket?.emit('join-room', {'room': room, 'username': _username});
    _addSystem('Joined room: $room');
  }

  void _leaveRoom() {
    if (_currentRoom == null) return;

    _socket?.emit('leave-room', {'room': _currentRoom, 'username': _username});
    _addSystem('Left room: $_currentRoom');
    _safeSetState(() => _currentRoom = null);
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final room = _currentRoom;
    if (room == null) {
      _addSystem('Not in a room. Join a room first.');
      return;
    }

    if (!_connected) {
      _addSystem('Offline. Message not sent.');
      return;
    }

    _socket?.emit('send-message', {
      'room': room,
      'username': _username,
      'message': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _msgCtrl.clear();
  }

  void _addSystem(String text) {
    _safeSetState(() => _items.add(_ChatItem.system(text)));
  }

  void _addMessage({
    required String room,
    required String user,
    required String text,
    required bool isMe,
  }) {
    _safeSetState(() => _items.add(_ChatItem.message(room: room, user: user, text: text, isMe: isMe)));
  }

  @override
  void dispose() {
    _isDisposed = true; // ✅ önce flag

    _roomCtrl.dispose();
    _msgCtrl.dispose();

    // ✅ en kritik: socket eventlerini kaldır, yoksa dispose sonrası setState tetikler
    _socket?.off('system-message');
    _socket?.off('new-message');
    _socket?.off('connect');
    _socket?.off('disconnect');
    _socket?.off('connect_error');
    _socket?.off('error'); // tüm listener’ları kaldır
    _socket?.disconnect();
    _socket?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = _currentRoom != null;

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
                  fontWeight: FontWeight.w600,
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
                    controller: _roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Room name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connected ? _joinRoom : null,
                  child: const Text('Join'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (inRoom && _connected) ? _leaveRoom : null,
                  child: const Text('Leave'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];

                if (item.type == _ChatItemType.system) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.text!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  );
                }

                final isMe = item.isMe!;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.teal.shade200 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          '[${item.room}] ${item.user}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(item.text!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      enabled: _connected,
                      decoration: InputDecoration(
                        hintText: inRoom ? 'Type message...' : 'Join a room to chat...',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _connected ? _sendMessage : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatItemType { system, message }

class _ChatItem {
  final _ChatItemType type;
  final String? room;
  final String? user;
  final String? text;
  final bool? isMe;

  _ChatItem._(this.type, {this.room, this.user, this.text, this.isMe});

  factory _ChatItem.system(String text) => _ChatItem._(_ChatItemType.system, text: text);

  factory _ChatItem.message({
    required String room,
    required String user,
    required String text,
    required bool isMe,
  }) =>
      _ChatItem._(
        _ChatItemType.message,
        room: room,
        user: user,
        text: text,
        isMe: isMe,
      );
}