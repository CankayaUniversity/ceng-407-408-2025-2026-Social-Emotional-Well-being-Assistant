import 'package:flutter/material.dart';
import 'ai_chat_screen.dart';

class ChatHubScreen extends StatelessWidget {
  const ChatHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('AI Chat'),
              subtitle: const Text('Talk with AI assistant'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiChatScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Community Rooms'),
              subtitle: const Text('Join anonymous group chats'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Community Rooms (UI draft)')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Private Chat Requests'),
              subtitle: const Text('1-on-1 anonymous chat'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Private Requests (UI draft)')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
