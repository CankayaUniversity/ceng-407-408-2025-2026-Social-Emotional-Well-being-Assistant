import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/emergency_contact_store.dart';
import '../chat/data/chat_store.dart';
import 'ui/trusted_contacts_sheet.dart';

// HomeStore
import 'package:ui_prototype/features/home/data/home_store.dart';

// Login’e dönmek için
import 'package:ui_prototype/features/auth/login_screen.dart';

// TokenStore clearAll için
import 'package:ui_prototype/core/api/token_store.dart';

class ProfileScreen extends StatefulWidget {
  final String loginUsername;
  const ProfileScreen({super.key, required this.loginUsername});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _anonymousModeKey = 'anonymous_mode';
  static const String _nicknameKey = 'user_nickname';
  static const String _ageKey = 'profile_age';
  static const String _cityKey = 'profile_city';
  static const String _notesKey = 'profile_notes';
  static const String _moodReminderKey = 'mood_reminder';

  File? _avatarFile;

  bool _anonymousMode = true;
  bool _moodReminder = true;
  bool _crisisNotifications = true;
  bool _loadingPrefs = true;

  late String _realName;

  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _realName = widget.loginUsername;
    _initProfile();
  }

  // Yardımcı fonksiyon: Anahtarı kullanıcıya özel yapar
  String _u(String key) => "${key}_$_realName";

  Future<void> _initProfile() async {
    await _loadProfilePrefs();
    _loadContacts();
  }

  Future<void> _loadProfilePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final anonymousMode = prefs.getBool(_u(_anonymousModeKey)) ?? true;
    final savedNickname = (prefs.getString(_u(_nicknameKey)) ?? '').trim();
    final savedAge = prefs.getString(_u(_ageKey)) ?? '';
    final savedCity = prefs.getString(_u(_cityKey)) ?? '';
    final savedNotes = prefs.getString(_u(_notesKey)) ?? '';
    final moodReminder = prefs.getBool(_u(_moodReminderKey)) ?? true;
    final crisisNotifications = prefs.getBool(_u('isNotificationEnabled')) ?? true;

    _anonymousMode = anonymousMode;
    _moodReminder = moodReminder;
    _crisisNotifications = crisisNotifications;

    _nicknameController.text = savedNickname.isNotEmpty
        ? savedNickname
        : (_anonymousMode ? 'Anonim' : _realName);

    _ageController.text = savedAge;
    _cityController.text = savedCity;
    _notesController.text = savedNotes;

    if (mounted) {
      setState(() {
        _loadingPrefs = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      await EmergencyContactStore.instance.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trusted contacts alınamadı: $e")),
      );
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveAnonymousMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_u(_anonymousModeKey), value);
  }

  Future<void> _saveNickname(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_u(_nicknameKey), value.trim());
  }

  Future<void> _saveAge(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_u(_ageKey), value.trim());
  }

  Future<void> _saveCity(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_u(_cityKey), value.trim());
  }

  Future<void> _saveNotes(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_u(_notesKey), value.trim());
  }

  Future<void> _saveMoodReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_u(_moodReminderKey), value);
  }

  Future<void> _saveCrisisNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_u('isNotificationEnabled'), value);
  }

  Future<void> _toggleAnonymous(bool value) async {
    setState(() {
      _anonymousMode = value;
    });

    await _saveAnonymousMode(value);

    if (value) {
      final current = _nicknameController.text.trim();
      if (current.isEmpty || current == _realName) {
        _nicknameController.text = 'Anonymous';
        await _saveNickname('Anonymous');
      } else {
        await _saveNickname(current);
      }
    } else {
      _nicknameController.text = _realName;
      await _saveNickname(_realName);
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _openTrustedContactsManager() async {
    final changed = await TrustedContactsSheet.open(context);
    if (!mounted) return;
    if (changed) await _loadContacts();
  }

  Future<void> _sendEmailToFirstContact() async {
    final contacts = EmergencyContactStore.instance.contacts;
    if (contacts.isEmpty) {
      await _openTrustedContactsManager();
      return;
    }
    final c = contacts.first;
    final subject = Uri.encodeComponent("Social-Emotional Wellbeing Assistant");
    final body = Uri.encodeComponent("Merhaba ${c.fullName}, acil bir durumda sana ulaşmam gerekiyor. Müsait misin?");
    final uri = Uri.parse("mailto:${c.email}?subject=$subject&body=$body");
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-posta uygulaması bulunamadı.")));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-posta açılamadı.")));
    }
  }

  Future<void> _logout() async {
    await TokenStore.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_email");
    await prefs.remove("user_name");
    await prefs.remove("user_id");

    HomeStore.instance.reset();
    EmergencyContactStore.instance.reset();
    ChatStore.instance.reset();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const gold = Color(0xFFFFE6A7);
    const bgLight = Color(0xFFF8F9FB);

    if (_loadingPrefs) {
      return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(navy))));
    }

    final avatar = _avatarFile == null
        ? const CircleAvatar(radius: 40, backgroundColor: navy, child: Icon(Icons.person, color: Colors.white, size: 44))
        : CircleAvatar(radius: 40, backgroundImage: FileImage(_avatarFile!));

    final trustedContacts = EmergencyContactStore.instance.contacts;
    final loadingContacts = EmergencyContactStore.instance.loading;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Profil", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(tooltip: "Çıkış Yap", onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: navy.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    avatar,
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: navy),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("TAKMA AD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navy, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nicknameController,
                  enabled: _anonymousMode,
                  onChanged: (value) async {
                    if (_anonymousMode) await _saveNickname(value);
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: navy.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    hintText: _anonymousMode ? 'Takma adınızı belirleyin' : _realName,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_anonymousMode ? "Anonim mod AÇIK" : "Gerçek kimlik görünür", style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text("Kullanıcı Bilgileri", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: navy.withOpacity(0.05))),
            child: Column(
              children: [
                _profileInput("Yaş", _ageController, navy, onChanged: _saveAge),
                const SizedBox(height: 16),
                _profileInput("Şehir", _cityController, navy, onChanged: _saveCity),
                const SizedBox(height: 16),
                _profileInput("Notlar / İlgi Alanları", _notesController, navy, maxLines: 3, onChanged: _saveNotes),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text("Gizlilik ve Güvenlik", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          const SizedBox(height: 12),
          _switchCard(title: "Anonim Mod", subtitle: "Sohbetlerde gerçek adını gizler", value: _anonymousMode, onChanged: _toggleAnonymous, icon: Icons.visibility_off_rounded, navy: navy, gold: gold),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openTrustedContactsManager,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: navy.withOpacity(0.05))),
              child: Row(
                children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.shield_rounded, color: navy, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Güvenilir Kişiler", style: TextStyle(fontWeight: FontWeight.w900, color: navy, fontSize: 16)),
                        Text(loadingContacts ? "Yükleniyor..." : (trustedContacts.isEmpty ? "Kaynakları yönet" : "${trustedContacts.length} kişi kayıtlı"), style: TextStyle(fontWeight: FontWeight.w600, color: navy.withOpacity(0.4), fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: _sendEmailToFirstContact, icon: const Icon(Icons.email_rounded, color: navy)),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text("Bildirimler", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          const SizedBox(height: 12),
          _switchCard(title: "Günlük Mod Hatırlatıcı", subtitle: "Her gün modunu kaydetmeni hatırlatır", value: _moodReminder, onChanged: (v) async { setState(() => _moodReminder = v); await _saveMoodReminder(v); }, icon: Icons.notifications_active_rounded, navy: navy, gold: gold),
          const SizedBox(height: 12),
          _switchCard(title: "Kriz Bildirimleri", subtitle: "Düşük mod durumunda bildirim yollar", value: _crisisNotifications, onChanged: (v) async { setState(() => _crisisNotifications = v); await _saveCrisisNotifications(v); }, icon: Icons.warning_amber_rounded, navy: navy, gold: gold),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _profileInput(String label, TextEditingController c, Color navy, {int maxLines = 1, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontWeight: FontWeight.w700, color: navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: navy.withOpacity(0.4), fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0E4E8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0E4E8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: navy.withOpacity(0.2), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _switchCard({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged, required IconData icon, required Color navy, required Color gold}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: navy.withOpacity(0.05))),
      child: SwitchListTile(
        activeColor: navy,
        activeTrackColor: gold,
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: navy, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 15))),
          ],
        ),
        subtitle: Padding(padding: const EdgeInsets.only(left: 50), child: Text(subtitle, style: TextStyle(fontWeight: FontWeight.w600, color: navy.withOpacity(0.4), fontSize: 12))),
      ),
    );
  }
}
