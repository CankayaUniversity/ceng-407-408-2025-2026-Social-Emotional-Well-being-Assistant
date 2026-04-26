import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class EmergencyContact {
  final int? id; // backend id
  final String firstName;
  final String lastName;
  final String relation;
  final String email;
  final bool isPrimary;

  const EmergencyContact({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.relation,
    required this.email,
    this.isPrimary = true,
  });

  String get fullName => ('$firstName $lastName').trim();

  /// Backend -> UI
  static EmergencyContact fromApi(dynamic raw) {
    final m = (raw is Map) ? raw : <String, dynamic>{};
    final name = (m['name'] ?? '').toString().trim();
    final parts = name.split(RegExp(r'\s+'));
    final fn = parts.isNotEmpty ? parts.first : '';
    final ln = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return EmergencyContact(
      id: (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}'),
      firstName: fn,
      lastName: ln,
      relation: (m['relation'] ?? '').toString(),
      email: (m['phone'] ?? '').toString(),
      isPrimary: m['isPrimary'] == true,
    );
  }

  /// UI -> Backend body
  Map<String, dynamic> toApiBody() => {
    "name": fullName,
    "phone": email,
    "relation": relation,
    "isPrimary": isPrimary,
  };
}

class EmergencyContactStore extends ChangeNotifier {
  EmergencyContactStore._();
  static final EmergencyContactStore instance = EmergencyContactStore._();

  bool loading = false;

  // ✅ dışarıdan yanlışlıkla değişmesin
  List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

  /// init istersen sadece load çağırır
  Future<void> init() async {
    await load();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final res = await ApiClient.get("/home/emergency-contacts");
      if (res.statusCode != 200) {
        throw Exception(_prettyErr(res));
      }

      final list = jsonDecode(res.body) as List<dynamic>;
      _contacts = list.map(EmergencyContact.fromApi).toList();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> add(EmergencyContact c) async {
    final res = await ApiClient.post("/home/emergency-contacts", c.toApiBody());
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_prettyErr(res));
    }
    await load();
  }

  /// Update endpoint’iniz varsa çalışır (/home/emergency-contacts/:id)
  Future<void> updateAt(int index, EmergencyContact c) async {
    if (index < 0 || index >= _contacts.length) return;

    // ✅ id üzerinden güncelle
    final id = _contacts[index].id ?? c.id;
    if (id == null) return;

    final res = await ApiClient.put(
      "/home/emergency-contacts/$id",
      c.toApiBody(),
    );

    if (res.statusCode != 200) {
      throw Exception(_prettyErr(res));
    }

    await load();
  }

  /// Delete endpoint’iniz varsa çalışır (/home/emergency-contacts/:id)
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _contacts.length) return;
    final id = _contacts[index].id;
    if (id == null) return;

    final res = await ApiClient.delete("/home/emergency-contacts/$id");
    if (res.statusCode != 200) {
      throw Exception(_prettyErr(res));
    }

    await load();
  }

  /// Logout / user değişimi için
  void reset() {
    loading = false;
    _contacts = [];
    notifyListeners();
  }

  // ---------- helpers ----------
  String _prettyErr(dynamic res) {
    // res: http.Response
    try {
      final body = (res.body ?? '').toString();
      if (body.isEmpty) return "Request failed (${res.statusCode})";
      // backend genelde {message:"..."} döner
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["message"] != null) {
        return decoded["message"].toString();
      }
      return body;
    } catch (_) {
      return "Request failed (${res.statusCode})";
    }
  }
}
