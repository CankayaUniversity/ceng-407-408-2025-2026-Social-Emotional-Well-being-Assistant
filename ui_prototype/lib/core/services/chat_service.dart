import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

// --- Data Models ---

enum ChatItemType { message, system, privateChatRequest }

class ChatItem {
  final ChatItemType type;
  final String? username;
  final String? message;
  final String? room;
  final DateTime createdAt;
  final int? userId;
  final String? socketId;

  ChatItem({
    required this.type,
    this.username,
    this.message,
    this.room,
    required this.createdAt,
    this.userId,
    this.socketId,
  });
}

class PrivateChatInvitation {
  final int requesterId;
  final String requesterUsername;

  PrivateChatInvitation({required this.requesterId, required this.requesterUsername});
}

class PrivateChatSession {
  final String room;
  final List<String> participants;

  PrivateChatSession({required this.room, required this.participants});
}

// --- Service ---

class ChatService {
  static const String socketUrl = AppConfig.chatSocketBaseUrl;

  IO.Socket? _socket;
  final StreamController<bool> _connectionStatusController = StreamController.broadcast();
  final StreamController<ChatItem> _messageController = StreamController.broadcast();
  final StreamController<PrivateChatInvitation> _invitationController = StreamController.broadcast();
  final StreamController<PrivateChatSession> _privateChatStartedController = StreamController.broadcast();

  // KRİTİK: Diğer dosyalardan erişim için public harita
  final Map<int, String> userSocketIds = {};

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<ChatItem> get messages => _messageController.stream;
  Stream<PrivateChatInvitation> get invitations => _invitationController.stream;
  Stream<PrivateChatSession> get privateChatSessions => _privateChatStartedController.stream;

  String? _currentRoom;
  String? get currentRoom => _currentRoom;

  int? _currentUserId;
  String? _currentUsername;

  void connect(int userId, String username) {
    _currentUserId = userId;
    _currentUsername = username;

    _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'userId': userId, 'username': username})
            .disableAutoConnect()
            .build());

    _socket!.onConnect((_) {
      debugPrint('ChatService: Connected');
      _connectionStatusController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('ChatService: Disconnected');
      _connectionStatusController.add(false);
      userSocketIds.clear();
    });

    _socket!.on('new-message', (data) {
       // Socket ID takibi
       if (data['userId'] != null && data['socketId'] != null) {
         final int id = int.tryParse(data['userId'].toString()) ?? 0;
         if (id != 0) userSocketIds[id] = data['socketId'].toString();
       }

      _messageController.add(ChatItem(
        type: ChatItemType.message,
        message: data['message'],
        username: data['username'],
        room: data['room'],
        userId: data['userId'] is int ? data['userId'] : int.tryParse(data['userId']?.toString() ?? ''),
        socketId: data['socketId'],
        createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      ));
    });

    _socket!.on('user-joined', (data) {
      if (data['userId'] != null && data['socketId'] != null) {
        final int id = int.tryParse(data['userId'].toString()) ?? 0;
        if (id != 0) userSocketIds[id] = data['socketId'].toString();
      }
    });

    _socket!.on('system-message', (data) {
      _messageController.add(ChatItem(
        type: ChatItemType.system,
        message: data['message'],
        createdAt: DateTime.now(),
      ));
    });

    _socket!.on('private-chat-invitation', (data) {
      final parsedId = int.tryParse(data['requesterId']?.toString() ?? '') ?? 0;
      if (parsedId != 0) {
        _invitationController.add(PrivateChatInvitation(
          requesterId: parsedId,
          requesterUsername: data['requesterUsername'],
        ));
      }
    });

    _socket!.on('private-chat-started', (data) {
      _privateChatStartedController.add(PrivateChatSession(
        room: data['room'],
        participants: List<String>.from(data['participants']),
      ));
    });

    _socket!.connect();
  }

  void joinRoom(String room, int userId, String username) {
    _currentRoom = room;
    _socket?.emit('join-room', {'room': room, 'userId': userId, 'username': username});
  }

  void leaveRoom(String room, int userId, String username) {
    if (_currentRoom == room) _currentRoom = null;
    _socket?.emit('leave-room', {'room': room, 'userId': userId, 'username': username});
  }

  void sendMessage(String message, int userId, String username) {
    if (_currentRoom == null) return;
    _socket?.emit('send-message', {
      'room': _currentRoom,
      'message': message,
      'userId': userId,
      'username': username,
    });
  }

  // Özel sohbet isteği (userId kullanarak)
  void sendPrivateChatRequest(int targetUserId) {
    // Servis içindeki canlı haritadan socketId bul
    final String? socketId = userSocketIds[targetUserId];
    
    if (socketId != null) {
      _socket?.emit('private-chat-request', {
        'targetSocketId': socketId,
        'requesterId': _currentUserId,
        'requesterUsername': _currentUsername,
      });
    } else {
      debugPrint('ChatService: Target user $targetUserId is not online.');
    }
  }

  void acceptPrivateChat(int requesterId, {int? receiverId, String? receiverUsername}) {
    _socket?.emit('private-chat-accept', {
      'requesterId': requesterId,
      'receiverId': receiverId ?? _currentUserId,
      'receiverUsername': receiverUsername ?? _currentUsername,
    });
  }

  void setCurrentRoom(String? room) => _currentRoom = room;

  void dispose() {
    _socket?.dispose();
    _connectionStatusController.close();
    _messageController.close();
    _invitationController.close();
    _privateChatStartedController.close();
  }
}
