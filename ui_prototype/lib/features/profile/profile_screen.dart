import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/emergency_contact_store.dart';
import 'ui/trusted_contacts_sheet.dart';

// HomeStore
import 'package:ui_prototype/features/home/data/home_store.dart';

// Login’e dönmek için
import 'package:ui_prototype/features/auth/login_screen.dart';

// TokenStore clearAll için
import 'package:ui_prototype/core/api/token_store.dart';

// Mood store varsa:
// import 'package:ui_prototype/features/mood/data/mood_store.dart';

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
  static const String _crisisNotificationsKey = 'crisis_notifications';

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

  Future<void> _initProfile() async {
    await _loadProfilePrefs();
    _loadContacts();
  }

  Future<void> _loadProfilePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final anonymousMode = prefs.getBool(_anonymousModeKey) ?? true;
    final savedNickname = (prefs.getString(_nicknameKey) ?? '').trim();
    final savedAge = prefs.getString(_ageKey) ?? '';
    final savedCity = prefs.getString(_cityKey) ?? '';
    final savedNotes = prefs.getString(_notesKey) ?? '';
    final moodReminder = prefs.getBool(_moodReminderKey) ?? true;
    final crisisNotifications =
        prefs.getBool('isNotificationEnabled') ?? true;

    _anonymousMode = anonymousMode;
    _moodReminder = moodReminder;
    _crisisNotifications = crisisNotifications;

    _nicknameController.text = savedNickname.isNotEmpty
        ? savedNickname
        : (_anonymousMode ? 'Anonymous' : _realName);

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
    await prefs.setBool(_anonymousModeKey, value);
  }

  Future<void> _saveNickname(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, value.trim());
  }

  Future<void> _saveAge(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ageKey, value.trim());
  }

  Future<void> _saveCity(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, value.trim());
  }

  Future<void> _saveNotes(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, value.trim());
  }

  Future<void> _saveMoodReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_moodReminderKey, value);
  }

  Future<void> _saveCrisisNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationEnabled', value);
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
      // Anonymous kapalıysa gerçek isim göster
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

    if (changed) {
      await _loadContacts();
    }
  }

  Future<void> _sendEmailToFirstContact() async {
    final contacts = EmergencyContactStore.instance.contacts;

    if (contacts.isEmpty) {
      await _openTrustedContactsManager();
      return;
    }

    final c = contacts.first;
    final subject = Uri.encodeComponent("Social-Emotional Wellbeing Assistant");
    final body = Uri.encodeComponent(
      "Merhaba ${c.fullName}, acil bir durumda sana ulaşmam gerekiyor. Müsait misin?",
    );

    final uri = Uri.parse("mailto:${c.email}?subject=$subject&body=$body");

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("E-posta uygulaması bulunamadı.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-posta açılamadı.")),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    await TokenStore.clearAll();

    await prefs.remove("user_email");
    await prefs.remove("user_name");
    await prefs.remove("user_id");

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
    if (_loadingPrefs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                            backgroundColor:
                            Theme.of(context).colorScheme.primary,
                            child: const Icon(
                              Icons.edit,
                              size: 14,
                              color: Colors.white,
                            ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _nicknameController,
                          enabled: _anonymousMode,
                          onChanged: (value) async {
                            if (_anonymousMode) {
                              await _saveNickname(value);
                            }
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            hintText: _anonymousMode
                                ? 'Anonymous veya takma ad yaz'
                                : _realName,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _anonymousMode
                              ? "Anonymous mode is ON"
                              : "Anonymous mode is OFF (real identity visible)",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
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
          _textFieldCard(
            "Age",
            _ageController,
            onChanged: _saveAge,
          ),
          _textFieldCard(
            "City",
            _cityController,
            onChanged: _saveCity,
          ),
          _textFieldCard(
            "Notes / Interests (from chat)",
            _notesController,
            maxLines: 4,
            onChanged: _saveNotes,
          ),
          const SizedBox(height: 16),
          _sectionTitle("Privacy & Safety"),
          _switchTile(
            title: "Anonymous mode",
            subtitle: "Hide real name in chats",
            value: _anonymousMode,
            onChanged: (v) async {
              await _toggleAnonymous(v);
            },
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
                    tooltip: "E-posta (first contact)",
                    onPressed: _sendEmailToFirstContact,
                    icon: const Icon(Icons.email_outlined),
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
            onChanged: (v) async {
              setState(() => _moodReminder = v);
              await _saveMoodReminder(v);
            },
            icon: Icons.notifications_active,
          ),
          _switchTile(
            title: "Crisis notifications",
            subtitle: "Show safety prompts when mood is low (mock)",
            value: _crisisNotifications,
            onChanged: (v) async {
              setState(() => _crisisNotifications = v);
              await _saveCrisisNotifications(v);
            },
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

  Widget _textFieldCard(
      String label,
      TextEditingController c, {
        int maxLines = 1,
        ValueChanged<String>? onChanged,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          onChanged: onChanged,
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