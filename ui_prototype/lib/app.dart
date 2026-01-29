import 'package:flutter/material.dart';

import 'package:ui_prototype/features/auth/login_screen.dart';
import 'package:ui_prototype/features/home/home_screen.dart';
import 'package:ui_prototype/features/chat/chat_hub_screen.dart';
import 'package:ui_prototype/features/mood/mood_screen.dart';
import 'package:ui_prototype/features/profile/profile_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Health App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const LoginScreen(),
    );
  }
}

class HomeShell extends StatefulWidget {
  /// Login sonrası gelen username / email
  final String username;

  const HomeShell({super.key, required this.username});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const ChatHubScreen(),

      // ✅ KRİTİK DÜZELTME:
      // Mood artık userKey ister → her kullanıcı kendi mood'unu görür
      MoodScreen(userKey: widget.username),

      ProfileScreen(loginUsername: widget.username),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Sekme değişince state kaybolmasın
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Mood'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
