import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class EmergencyContact {
  final String firstName;
  final String lastName;
  final String relation; // Arkadaş, Anne, Baba, vb.
  final String phone;    // 05xx... veya +90...

  const EmergencyContact({
    required this.firstName,
    required this.lastName,
    required this.relation,
    required this.phone,
  });

  String get fullName => ('$firstName $lastName').trim();

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'relation': relation,
    'phone': phone,
  };

  static EmergencyContact? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final fn = (raw['firstName'] ?? '').toString();
    final ln = (raw['lastName'] ?? '').toString();
    final rel = (raw['relation'] ?? '').toString();
    final ph = (raw['phone'] ?? '').toString();
    if (fn.isEmpty && ln.isEmpty && rel.isEmpty && ph.isEmpty) return null;
    return EmergencyContact(firstName: fn, lastName: ln, relation: rel, phone: ph);
  }
}

class EmergencyContactStore {
  EmergencyContactStore._();
  static final EmergencyContactStore instance = EmergencyContactStore._();

  static const _boxName = 'profile_store_v1';

  // ✅ Yeni: çoklu liste
  static const _keyTrustedContacts = 'trusted_contacts_v1';

  // ✅ Eski: tek kişi (migrate edeceğiz)
  static const _legacyKeySingle = 'emergency_contact';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    await _migrateLegacyIfNeeded();
  }

  Future<void> _migrateLegacyIfNeeded() async {
    // Yeni liste yoksa ama eski tek kişi varsa -> listeye taşı
    final hasNew = _box.containsKey(_keyTrustedContacts);
    final legacy = _box.get(_legacyKeySingle);

    if (!hasNew && legacy != null) {
      final single = EmergencyContact.fromMap(legacy);
      if (single != null) {
        await _box.put(_keyTrustedContacts, [single.toMap()]);
      } else {
        await _box.put(_keyTrustedContacts, <Map<String, dynamic>>[]);
      }
      await _box.delete(_legacyKeySingle); // artık kullanılmıyor
    } else if (!hasNew) {
      // hiçbir şey yoksa boş liste başlat
      await _box.put(_keyTrustedContacts, <Map<String, dynamic>>[]);
    }
  }

  List<EmergencyContact> readAll() {
    final raw = _box.get(_keyTrustedContacts);
    if (raw is! List) return [];
    return raw
        .map((e) => EmergencyContact.fromMap(e))
        .whereType<EmergencyContact>()
        .toList();
  }

  Future<void> saveAll(List<EmergencyContact> list) async {
    await _box.put(_keyTrustedContacts, list.map((e) => e.toMap()).toList());
  }

  Future<void> add(EmergencyContact c) async {
    final list = readAll();
    list.add(c);
    await saveAll(list);
  }

  Future<void> updateAt(int index, EmergencyContact c) async {
    final list = readAll();
    if (index < 0 || index >= list.length) return;
    list[index] = c;
    await saveAll(list);
  }

  Future<void> removeAt(int index) async {
    final list = readAll();
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await saveAll(list);
  }

  Future<void> clearAll() async {
    await _box.put(_keyTrustedContacts, <Map<String, dynamic>>[]);
  }
}
