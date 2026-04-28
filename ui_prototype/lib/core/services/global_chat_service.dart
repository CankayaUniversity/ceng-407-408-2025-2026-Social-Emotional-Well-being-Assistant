import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ui_prototype/core/api/token_store.dart';
import '../config/app_config.dart';
import 'notification_service.dart';

class GlobalChatService {
  static final GlobalChatService _instance = GlobalChatService._internal();
  factory GlobalChatService() => _instance;
  GlobalChatService._internal();

  static const String socketBaseUrl = AppConfig.chatSocketBaseUrl;
  static const String _joinedRoomsKey = 'joined_community_rooms';

  IO.Socket? _socket;
  final Set<String> _myJoinedRooms = {};
  int? _userId;
  String? _chatUsername;
  String? _currentOpenRoom; // O an kullanıcının baktığı oda

  Function(Map<String, dynamic>)? onMessageReceived;

  Future<void> init() async {
    final user = await TokenStore.getCurrentUser();
    if (user == null) return;

    _userId = user.id;
    final prefs = await SharedPreferences.getInstance();
    
    final nickname = (prefs.getString('user_nickname_${user.id}') ?? '').trim();
    _chatUsername = nickname.isNotEmpty ? nickname : user.username;

    final savedRooms = prefs.getStringList('${_joinedRoomsKey}_${user.id}') ?? [];
    _myJoinedRooms.addAll(savedRooms);

    _connectSocket();
  }

  void _connectSocket() {
    _socket?.dispose();
    _socket = IO.io(socketBaseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect() // Otomatik yeniden bağlanma
        .enableForceNew()
        .setReconnectionAttempts(10) // 10 kez dene
        .setReconnectionDelay(5000) // 5 saniyede bir dene
        .build());

    _socket!.onConnect((_) {
      debugPrint('GLOBAL SOCKET CONNECTED');
      for (final room in _myJoinedRooms) {
        _socket?.emit('join-room', {
          'room': room,
          'username': _chatUsername,
          'userId': _userId,
        });
      }
    });

    _socket!.on('new-message', (data) {
      if (data is Map) {
        final String msgRoom = (data['room'] ?? '').toString();
        final int? senderId = int.tryParse(data['userId']?.toString() ?? '');

        if (onMessageReceived != null) {
          onMessageReceived!(Map<String, dynamic>.from(data));
        }

        // BİLDİRİM ŞARTI: 
        // 1. Mesaj benden gelmemeli
        // 2. Odaya üye olmalıyım
        // 3. O an o odanın içinde OLMAMALIYIM (veya uygulama arka planda olmalı)
        if (senderId != _userId && _myJoinedRooms.contains(msgRoom)) {
          if (_currentOpenRoom == null || _currentOpenRoom != msgRoom) {
            NotificationService().showNotification(
              id: Random().nextInt(100000),
              title: 'Oda: $msgRoom',
              body: '${data['username']}: ${data['message']}',
            );
          }
        }
      }
    });

    _socket!.connect();
  }

  void setCurrentRoom(String? roomName) {
    _currentOpenRoom = roomName;
  }

  void emit(String event, dynamic data) => _socket?.emit(event, data);
  
  void updateJoinedRooms(String room, bool add) {
    if (add) _myJoinedRooms.add(room);
    else _myJoinedRooms.remove(room);
  }
}