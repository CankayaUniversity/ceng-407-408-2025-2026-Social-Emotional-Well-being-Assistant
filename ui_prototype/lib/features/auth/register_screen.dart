import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  // ✅ Android Emulator için backend URL
  static const String _baseUrl = "http://10.0.2.2:3001";

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (username.isEmpty || pass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tüm alanları doldur.")),
      );
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifre en az 6 karakter olmalı.")),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifreler eşleşmiyor.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ Backend endpoint
      final url = Uri.parse("$_baseUrl/api/auth/register");

      // ⚠️ Backend email istiyor. Şu an sizde sadece username var.
      // Geçici çözüm: username'i email gibi gönderiyoruz.
      final email = username.contains("@") ? username : "$username@test.com";

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": pass,
          "name": username, // name alanına username
        }),
      );

      // Debug
      debugPrint("REGISTER STATUS: ${res.statusCode}");
      debugPrint("REGISTER BODY: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kayıt başarılı ✅")),
        );

        // İstersen login ekranına geri dön ve username/pass gönder
        Navigator.pop<Map<String, String>>(context, {
          'username': username,
          'password': pass,
        });
      } else {
        // Backend'ten gelen mesajı göstermeye çalış
        String msg = "Kayıt başarısız";
        try {
          final data = jsonDecode(res.body);
          if (data is Map && data["message"] != null) {
            msg = data["message"].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Create Account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Username (veya Email)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure2,
                onSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Sign up"),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back to Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
