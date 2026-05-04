import 'package:flutter/material.dart';
import 'ai_chat_screen.dart';
import 'community_rooms_screen.dart';

class ChatHubScreen extends StatelessWidget {
  const ChatHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const mint = Color(0xFFD6E5E3);
    const gold = Color(0xFFFFE6A7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _chatCard(
            context,
            icon: Icons.settings_input_component_rounded,
            title: 'AI Chat',
            subtitle: 'Personal wellbeing assistant',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
            navy: navy,
            gold: gold,
          ),
          const SizedBox(height: 16),
          _chatCard(
            context,
            icon: Icons.groups_rounded,
            title: 'Community Rooms',
            subtitle: 'Join peer support groups',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityRoomsScreen())),
            navy: navy,
            gold: gold,
          ),
          const SizedBox(height: 16),
          _chatCard(
            context,
            icon: Icons.lock_rounded,
            title: 'Private Chats',
            subtitle: 'One-on-one secure messaging',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Private Requests (UI draft)'))),
            navy: navy,
            gold: gold,
          ),
        ],
      ),
    );
  }

  Widget _chatCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color navy,
    required Color gold,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: navy.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: gold, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: navy,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: navy.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: navy.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}