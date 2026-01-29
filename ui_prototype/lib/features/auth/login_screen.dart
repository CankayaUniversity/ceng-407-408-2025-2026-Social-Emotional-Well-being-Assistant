import 'package:flutter/material.dart';
import 'package:ui_prototype/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'services/auth_api.dart';

// ✅ Store importları
import 'package:ui_prototype/features/home/data/home_store.dart';
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
      final user = (result["user"] ?? {}) as Map<String, dynamic>;

      if (token.isEmpty) {
        throw Exception("Token alınamadı.");
      }

      // ✅ userId zorunlu (HomeStore user bazlı)
      final dynamic rawId = user["id"];
      final int userId = (rawId is num)
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? "") ?? -1;

      if (userId <= 0) {
        throw Exception("User id alınamadı. Login response içinde user.id olmalı.");
      }

      final prefs = await SharedPreferences.getInstance();

      // ✅ KRİTİK: ApiClient/TokenStore ile aynı key olmalı
      await prefs.setString("auth_token", token);

      // (opsiyonel bilgi saklama)
      await prefs.setInt("user_id", userId);
      await prefs.setString("user_email", (user["email"] ?? "").toString());
      await prefs.setString("user_name", (user["name"] ?? "").toString());

      // ✅ KRİTİK: HomeStore'u bu kullanıcıya bağla (Hive key user bazlı)
      // NOT: setUser async olduğu için await şart
      await HomeStore.instance.setUser(userId);

      // ✅ Crisis Help backend’den çekiliyor -> token kaydedildikten sonra çağır
      await EmergencyContactStore.instance.load();

      // Mood store varsa:
      // final now = DateTime.now();
      // final month =
      //     "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
      // await MoodStore.instance.loadMonth(month);

      if (!mounted) return;

      final displayName =
      (user["name"] != null && user["name"].toString().trim().isNotEmpty)
          ? user["name"].toString()
          : email;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeShell(username: displayName)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final media = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        const Icon(Icons.lock_outline, size: 64),
                        const SizedBox(height: 12),
                        const Text(
                          "Welcome Back",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          controller: _emailCtrl,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _isLoading
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Text("Login"),
                          ),
                        ),

                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Forgot password (UI draft)")),
                            );
                          },
                          child: const Text("Forgot password?"),
                        ),

                        const Expanded(child: SizedBox()),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Not a member? "),
                            TextButton(
                              onPressed: _goRegister,
                              child: const Text("Sign up"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}