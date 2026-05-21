import 'package:hive/hive.dart';

class ChatStore {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  static const String _boxName = 'chat_store_v1';
  Box? _box;
  int? _userId;

  Future<void> init() async {
    await _ensureBoxOpen();
  }

  Future<void> setUser(int userId) async {
    await _ensureBoxOpen();
    _userId = userId;
  }

  void reset() {
    _userId = null;
  }

  Future<void> _ensureBoxOpen() async {
    if (_box != null && _box!.isOpen) return;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
  }

  void _ensureUser() {
    if (_userId == null) {
      throw StateError("ChatStore: userId set edilmemiş.");
    }
  }

  Box get _safeBox {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError("ChatStore: Box açık değil.");
    }
    return b;
  }

  // --- AI Chat ---

  String _aiChatKey() {
    _ensureUser();
    return 'ai_chat:${_userId!}';
  }

  List<Map<String, dynamic>> loadAiChat() {
    final key = _aiChatKey();
    final raw = _safeBox.get(key);
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw.map((item) => Map<String, dynamic>.from(item)));
  }

  Future<void> saveAiChat(List<Map<String, dynamic>> messages) async {
    await _ensureBoxOpen();
    final key = _aiChatKey();
    await _safeBox.put(key, messages);
  }

  // --- Private Chats ---

  String _privateChatKey() {
    _ensureUser();
    return 'private_chats:${_userId!}';
  }

  List<Map<String, dynamic>> loadPrivateChats() {
    final key = _privateChatKey();
    final raw = _safeBox.get(key);
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw.map((item) => Map<String, dynamic>.from(item)));
  }

  Future<void> savePrivateChats(List<Map<String, dynamic>> chats) async {
    await _ensureBoxOpen();
    final key = _privateChatKey();
    await _safeBox.put(key, chats);
  }

  Future<void> upsertPrivateChat({
    required String room,
    required List<String> participants,
    DateTime? lastActive,
  }) async {
    final items = loadPrivateChats();
    final normalizedRoom = room.trim();
    if (normalizedRoom.isEmpty) return;

    final payload = <String, dynamic>{
      'room': normalizedRoom,
      'participants': participants,
      'lastActive': (lastActive ?? DateTime.now()).toIso8601String(),
    };

    final index = items.indexWhere((item) => (item['room'] ?? '').toString() == normalizedRoom);
    if (index >= 0) {
      final merged = Map<String, dynamic>.from(items[index]);
      merged.addAll(payload);
      items[index] = merged;
    } else {
      items.add(payload);
    }

    await savePrivateChats(items);
  }

  String _privateMessagesKey(String room) {
    _ensureUser();
    final normalized = room.trim().toLowerCase();
    return 'private_messages:${_userId!}:$normalized';
  }

  List<Map<String, dynamic>> loadPrivateMessages(String room) {
    final key = _privateMessagesKey(room);
    final raw = _safeBox.get(key);
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw.map((item) => Map<String, dynamic>.from(item)));
  }

  Future<void> savePrivateMessages(String room, List<Map<String, dynamic>> messages) async {
    await _ensureBoxOpen();
    final key = _privateMessagesKey(room);
    await _safeBox.put(key, messages);
  }

  Future<void> appendPrivateMessage(String room, Map<String, dynamic> message) async {
    final normalizedRoom = room.trim();
    if (normalizedRoom.isEmpty) return;
    final messages = loadPrivateMessages(normalizedRoom);
    messages.add(Map<String, dynamic>.from(message));
    await savePrivateMessages(normalizedRoom, messages);
  }
}
