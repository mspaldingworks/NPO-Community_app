import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/features/chat/services/chat_service.dart';
import 'package:transconnect/models/conversation.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<Conversation>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _chatService.fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: FutureBuilder<List<Conversation>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No conversations found.'));
          } else {
            final conversations = snapshot.data!;
            return ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                // Displaying participant names, assuming they are user-friendly.
                final title = conversation.participants.join(', ');
                final lastMessage = conversation.lastMessage?.content ?? 'No messages yet.';

                return ListTile(
                  title: Text(title),
                  subtitle: Text(lastMessage),
                  onTap: () {
                    // Navigate to the message screen for this conversation.
                    GoRouter.of(context).push('/chat/${conversation.id}');
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
