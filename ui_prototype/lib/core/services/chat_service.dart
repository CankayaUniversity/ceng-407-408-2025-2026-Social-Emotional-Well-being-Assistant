import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// --- Data Models ---

enum ChatItemType { message, system, privateChatRequest }

class ChatItem {
  final ChatItemType type;
  final String? username;
  final String? message;
  final DateTime createdAt;
  final int? userId;
  final String? socketId; // For private chat requests

  ChatItem({
    required this.type,
    this.username,
    this.message,
    required this.createdAt,
    this.userId,
    this.socketId,
  });
}

class PrivateChatInvitation {
  final String requesterId;
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
  static const String socketUrl = 'https://private-chat-production-2151.up.railway.app';

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

  void connect(int userId, String username) {
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
    });

    _socket!.on('new-message', (data) {
       debugPrint("new-message received: $data");
      _messageController.add(ChatItem(
        type: ChatItemType.message,
        message: data['message'],
        username: data['username'],
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
      _invitationController.add(PrivateChatInvitation(
        requesterId: data['requesterId'],
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

  void sendPrivateChatRequest(String targetSocketId) {
    _socket?.emit('private-chat-request', {'targetSocketId': targetSocketId});
  }

  void acceptPrivateChat(String requesterId) {
    _socket?.emit('private-chat-accept', {'requesterId': requesterId});
  }

  void dispose() {
    _socket?.dispose();
    _connectionStatusController.close();
    _messageController.close();
    _invitationController.close();
    _privateChatStartedController.close();
  }
}

