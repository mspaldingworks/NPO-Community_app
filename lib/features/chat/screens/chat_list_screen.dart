import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/features/friends/screens/friends_screen.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Add a listener to rebuild the FAB when the tab changes
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Chats'),
            Tab(text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ConversationList(),
          FriendsList(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 0: // Chats Tab
        return FloatingActionButton(
          onPressed: () => GoRouter.of(context).push('/chat/create'),
          child: Icon(Icons.add),
          tooltip: 'Start a new chat',
        );
      case 1: // Friends Tab
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: 'find_friends',
              onPressed: () => GoRouter.of(context).push('/user-search'),
              child: const Icon(Icons.person_add),
              tooltip: 'Find new friends',
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'chat_with_friends',
              onPressed: () => GoRouter.of(context).push('/select-friends-for-chat'),
              child: const Icon(Icons.group_add),
              tooltip: 'Chat with friends',
            ),
          ],
        );
      default:
        return null;
    }
  }
}

// Extracted widget for displaying the list of conversations
class ConversationList extends StatefulWidget {
  ConversationList({super.key});

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late Future<List<ConversationPreview>> _conversationsFuture;
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _conversationsFuture = _chatService.getAllConversations();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationPreview>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No conversations found.'));
        } else {
          final conversations = snapshot.data!;
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: conversation.unreadCount > 0
                        ? AppColors.tertiary
                        : Colors.grey.shade300,
                    foregroundColor: conversation.unreadCount > 0
                        ? AppColors.textWhite
                        : AppColors.textBlack,
                    child: conversation.unreadCount > 0
                        ? Text(conversation.unreadCount.toString())
                        : const Icon(Icons.notifications_none),
                  ),
                  title: Text(conversation.username),
                  subtitle: Text(
                    'Not Implemented yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.secondary),
                  onTap: () {
                    GoRouter.of(context).push('/chat/${conversation.id}');
                  },
                ),
              );
            },
          );
        }
      },
    );
  }
}
