import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui_prototype/app.dart';
import 'package:ui_prototype/core/api/token_store.dart';

import 'register_screen.dart';
import 'services/auth_api.dart';

// Store importları
import 'package:ui_prototype/features/home/data/home_store.dart';
import 'package:ui_prototype/features/chat/data/chat_store.dart';
import 'package:ui_prototype/features/profile/data/emergency_contact_store.dart';
// Mood store varsa aç:
// import 'package:ui_prototype/features/mood/data/mood_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email ve Password boş olamaz.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthApi.login(email: email, password: password);

      final token = (result["token"] ?? "").toString();
      final user =
      ((result["user"] ?? <String, dynamic>{}) as Map).cast<String, dynamic>();

      if (token.isEmpty) {
        throw Exception("Token alınamadı.");
      }

      final dynamic rawId = user["id"];
      final int userId = (rawId is num)
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? "") ?? -1;

      if (userId <= 0) {
        throw Exception("User id alınamadı. Login response içinde user.id olmalı.");
      }

      final String userEmail =
      (user["email"] ?? email).toString().trim();

      final String userName =
      (user["name"] ?? user["username"] ?? userEmail).toString().trim();

      final String chatUsername =
      userName.isNotEmpty ? userName : userEmail;

      final prefs = await SharedPreferences.getInstance();

// TokenStore ile uyumlu şekilde token kaydet
      await TokenStore.save(token);

// KRİTİK: Chat ekranının okuyacağı user objesini kaydet
      await TokenStore.saveUser(
        CurrentUser(
          id: userId,
          username: chatUsername,
        ),
      );

// Anonymous mode default: ilk kez login olan kullanıcı için otomatik açık
      final existingAnonymous = prefs.getBool('anonymous_mode');
      if (existingAnonymous == null) {
        await prefs.setBool('anonymous_mode', true);
      }

      final existingNickname = (prefs.getString('user_nickname') ?? '').trim();
      if (existingNickname.isEmpty) {
        await prefs.setString('user_nickname', 'Anonymous');
      }

// İstersen mevcut local saklamaları da koru
      await prefs.setString("auth_token", token);
      await prefs.setInt("user_id", userId);
      await prefs.setString("user_email", userEmail);
      await prefs.setString("user_name", userName);

      // KRİTİK: HomeStore'a userId set et
      await HomeStore.instance.setUser(userId);

      // KRİTİK: ChatStore'a userId set et
      await ChatStore.instance.setUser(userId);

      // Crisis Help backend’den çekiliyor
      await EmergencyContactStore.instance.load();

      // Mood store varsa:
      // final now = DateTime.now();
      // final month =
      //     "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
      // await MoodStore.instance.loadMonth(month);

      if (!mounted) return;

      final displayName = userName.isNotEmpty ? userName : email;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeShell(username: displayName),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _goRegister() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (result == null) return;

    _emailCtrl.text = result['username'] ?? '';
    _passwordCtrl.text = result['password'] ?? '';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Kayıt başarılı! Şimdi giriş yapabilirsin.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const mint = Color(0xFFD6E5E3);
    const lightGrey = Color(0xFFE5E5E5);
    const gold = Color(0xFFFFE6A7);

    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: mint,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Navy Header Background
          Container(
            height: media.size.height * 0.4,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            // Gold Wellness Icon
                            const Center(
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: gold,
                                child: Icon(
                                  Icons.spa_rounded,
                                  size: 50,
                                  color: navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Hoş Geldin",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Text(
                              "Yolculuğuna devam etmek için giriş yap",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: lightGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Login Form Card
                            Card(
                              elevation: 8,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _emailCtrl,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: "E-posta",
                                        labelStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
                                        prefixIcon: const Icon(Icons.email_outlined, color: navy),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: navy, width: 2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextField(
                                      controller: _passwordCtrl,
                                      obscureText: _obscure,
                                      onSubmitted: (_) => _login(),
                                      decoration: InputDecoration(
                                        labelText: "Şifre",
                                        labelStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
                                        prefixIcon: const Icon(Icons.lock_outline, color: navy),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure ? Icons.visibility : Icons.visibility_off,
                                            color: navy,
                                          ),
                                          onPressed: () {
                                            setState(() => _obscure = !_obscure);
                                          },
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: navy, width: 2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: navy,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 4,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  valueColor: AlwaysStoppedAnimation<Color>(gold),
                                                ),
                                              )
                                            : const Text(
                                                "GİRİŞ YAP",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Şifremi unuttum özelliği yakında eklenecek.")),
                                        );
                                      },
                                      child: const Text(
                                        "Şifremi Unuttum",
                                        style: TextStyle(color: navy, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Üye değil misin? ",
                                  style: TextStyle(color: navy, fontWeight: FontWeight.w500),
                                ),
                                TextButton(
                                  onPressed: _goRegister,
                                  child: const Text(
                                    "Kayıt Ol",
                                    style: TextStyle(
                                      color: navy,
                                      fontWeight: FontWeight.w900,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}