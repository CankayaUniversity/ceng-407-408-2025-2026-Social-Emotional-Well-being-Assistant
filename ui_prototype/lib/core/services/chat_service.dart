import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../api/token_store.dart';

// --- Data Models ---

enum ChatItemType { message, system, privateChatRequest }

class ChatItem {
  final ChatItemType type;
  final String? username;
  final String? message;
  final String? room; // Restored room field for UI synchronization
  final DateTime createdAt;
  final int? userId;
  final String? socketId; // For private chat requests

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


  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<ChatItem> get messages => _messageController.stream;
  Stream<PrivateChatInvitation> get invitations => _invitationController.stream;
  Stream<PrivateChatSession> get privateChatSessions => _privateChatStartedController.stream;

  String? _currentRoom;
  String? get currentRoom => _currentRoom;

  int? _currentUserId;
  String? _currentUsername;

  Future<void> connect(int userId, String username) async {
    _currentUserId = userId;
    _currentUsername = username;

    final token = await TokenStore.get();
    final query = <String, dynamic>{
      'userId': userId,
      'username': username,
    };
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }

    _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery(query)
          .disableAutoConnect()
          .build());

    _socket!.onConnect((_) {
      debugPrint('ChatService: Connected');
      _connectionStatusController.add(true);
      _socket?.emit('register-user', {
        'userId': _currentUserId,
        'username': _currentUsername,
      });
    });

    _socket!.onDisconnect((_) {
      debugPrint('ChatService: Disconnected');
      _connectionStatusController.add(false);
    });

    _socket!.on('new-message', (data) {
       debugPrint("new-message received: $data");
      _messageController.add(ChatItem(
        type: ChatItemType.message,
        message: data['message'],
        username: data['username'],
        room: data['room'], // Restored room assignment
        userId: data['userId'],
        socketId: data['socketId'],
        createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      ));
    });

    _socket!.on('system-message', (data) {
      debugPrint("system-message received: $data");
      _messageController.add(ChatItem(
        type: ChatItemType.system,
        message: data['message'],
        createdAt: DateTime.now(),
      ));
    });

    _socket!.on('private-chat-invitation', (data) {
      debugPrint("private-chat-invitation received: $data");
      final parsedId = int.tryParse(data['requesterId']?.toString() ?? '') ?? 0;
      if (parsedId == 0) {
        return;
      }
      _invitationController.add(PrivateChatInvitation(
        requesterId: parsedId,
        requesterUsername: data['requesterUsername'],
      ));
    });

    _socket!.on('private-chat-started', (data) {
       debugPrint("private-chat-started received: $data");
      _privateChatStartedController.add(PrivateChatSession(
        room: data['room'],
        participants: List<String>.from(data['participants']),
      ));
    });

    _socket!.connect();
  }

  void joinRoom(String room, int userId, String username) {
    _currentRoom = room;
    _socket?.emit('join-room', {
      'room': room,
      'userId': userId,
      'username': username,
    });
  }

  void leaveRoom(String room, int userId, String username) {
    if (_currentRoom == room) {
      _currentRoom = null;
    }
    _socket?.emit('leave-room', {
      'room': room,
      'userId': userId,
      'username': username,
    });
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

  void sendPrivateChatRequest({
    String? targetSocketId,
    int? targetUserId,
    int? requesterId,
    String? requesterUsername,
  }) {
    final resolvedUserId = requesterId ?? _currentUserId;
    final resolvedUsername = requesterUsername ?? _currentUsername;
    if (targetSocketId == null && targetUserId == null) {
      return;
    }

    final payload = <String, dynamic>{
      'requesterId': resolvedUserId,
      'requesterUsername': resolvedUsername,
    };
    if (targetSocketId != null) {
      payload['targetSocketId'] = targetSocketId;
    }
    if (targetUserId != null) {
      payload['targetUserId'] = targetUserId;
    }

    _socket?.emit('private-chat-request', payload);
  }

  void acceptPrivateChat(int requesterId, {int? receiverId, String? receiverUsername}) {
    final resolvedReceiverId = receiverId ?? _currentUserId;
    final resolvedReceiverUsername = receiverUsername ?? _currentUsername;
    _socket?.emit('private-chat-accept', {
      'requesterId': requesterId,
      'receiverId': resolvedReceiverId,
      'receiverUsername': resolvedReceiverUsername,
    });
  }

  void setCurrentRoom(String? room) {
    _currentRoom = room;
  }

  void dispose() {
    _socket?.dispose();
    _connectionStatusController.close();
    _messageController.close();
    _invitationController.close();
    _privateChatStartedController.close();
  }
}
