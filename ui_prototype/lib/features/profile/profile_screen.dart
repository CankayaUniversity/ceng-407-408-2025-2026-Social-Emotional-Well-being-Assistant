import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/emergency_contact_store.dart';
import 'ui/trusted_contacts_sheet.dart';

// ✅ HomeStore (Hive user bazlı)
import 'package:ui_prototype/features/home/data/home_store.dart';

// ✅ Login’e dönmek için
import 'package:ui_prototype/features/auth/login_screen.dart';

// Mood store varsa:
// import 'package:ui_prototype/features/mood/data/mood_store.dart';

class ProfileScreen extends StatefulWidget {
  final String loginUsername;
  const ProfileScreen({super.key, required this.loginUsername});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _avatarFile;

  bool _anonymousMode = true;
  bool _moodReminder = true;
  bool _crisisNotifications = true;

  late String _realName;

  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _realName = widget.loginUsername;
    _applyNicknameByMode();

    _loadContacts();
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

  void _applyNicknameByMode() {
    _nicknameController.text = _anonymousMode ? "Anonymous" : _realName;
    if (mounted) setState(() {});
  }

  void _toggleAnonymous(bool v) {
    setState(() => _anonymousMode = v);
    _applyNicknameByMode();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _openTrustedContactsManager() async {
    final changed = await TrustedContactsSheet.open(context);
    if (!mounted) return;

    if (changed) {
      await _loadContacts();
    }
  }

  Future<void> _sendSmsToFirstContact() async {
    final contacts = EmergencyContactStore.instance.contacts;

    if (contacts.isEmpty) {
      await _openTrustedContactsManager();
      return;
    }

    final c = contacts.first;
    final body = Uri.encodeComponent(
      "Merhaba ${c.fullName}, acil bir durumda sana ulaşmam gerekiyor. Müsait misin?",
    );

    final uri = Uri.parse("sms:${c.phone}?body=$body");

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SMS uygulaması bulunamadı.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS açılamadı.")),
      );
    }
  }

  /// ✅ Logout: token sil + store reset + login’e dön
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    await prefs.remove("user_email");
    await prefs.remove("user_name");
    await prefs.remove("user_id");

    // ✅ Store reset (doğru fonksiyonlar)
    HomeStore.instance.reset();
    EmergencyContactStore.instance.reset();
    // MoodStore varsa:
    // MoodStore.instance.reset();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarFile == null
        ? const CircleAvatar(radius: 28, child: Icon(Icons.person))
        : CircleAvatar(radius: 28, backgroundImage: FileImage(_avatarFile!));

    final trustedContacts = EmergencyContactStore.instance.contacts;
    final loadingContacts = EmergencyContactStore.instance.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            tooltip: "Logout",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      avatar,
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Nickname",
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _nicknameController,
                          enabled: !_anonymousMode,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _anonymousMode
                              ? "Anonymous mode is ON (locked)"
                              : "Anonymous mode is OFF",
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle("User Information"),
          _textFieldCard("Age", _ageController),
          _textFieldCard("City", _cityController),
          _textFieldCard("Notes / Interests (from chat)", _notesController, maxLines: 4),

          const SizedBox(height: 16),
          _sectionTitle("Privacy & Safety"),

          _switchTile(
            title: "Anonymous mode",
            subtitle: "Hide real name in chats",
            value: _anonymousMode,
            onChanged: _toggleAnonymous,
            icon: Icons.visibility_off,
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety),
              title: const Text(
                "Crisis help (mock)",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                loadingContacts
                    ? "Loading trusted contacts..."
                    : (trustedContacts.isEmpty
                    ? "Emergency resources / trusted contacts"
                    : "Trusted contacts: ${trustedContacts.length} kişi"),
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: "SMS (first contact)",
                    onPressed: _sendSmsToFirstContact,
                    icon: const Icon(Icons.sms_outlined),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: _openTrustedContactsManager,
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle("Notifications"),

          _switchTile(
            title: "Daily mood reminder",
            subtitle: "Remind me to log mood daily",
            value: _moodReminder,
            onChanged: (v) => setState(() => _moodReminder = v),
            icon: Icons.notifications_active,
          ),

          _switchTile(
            title: "Crisis notifications",
            subtitle: "Show safety prompts when mood is low (mock)",
            value: _crisisNotifications,
            onChanged: (v) => setState(() => _crisisNotifications = v),
            icon: Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _textFieldCard(String label, TextEditingController c, {int maxLines = 1}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        subtitle: Text(subtitle),
      ),
    );
  }
}