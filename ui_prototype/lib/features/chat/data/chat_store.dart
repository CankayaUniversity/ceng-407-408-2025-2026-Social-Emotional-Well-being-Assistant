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
}
