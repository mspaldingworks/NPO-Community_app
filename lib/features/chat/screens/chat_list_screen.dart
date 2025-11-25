import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/features/friends/widgets/friends_tab_view.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/models/user.dart';

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
            Tab(text: 'Messages'),
            Tab(text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ConversationList(),
          const FriendsTabView(),
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
          child: const Icon(Icons.add),
          tooltip: 'Start a new chat',
        );
      case 1: // Friends Tab
        return FloatingActionButton(
          onPressed: () => GoRouter.of(context).push('/user-search'),
          backgroundColor: AppColors.secondary, // Yellow color
          child: const Icon(Icons.person_add),
          tooltip: 'Add Friend',
        );
      default:
        return null;
    }
  }
}

// Extracted widget for displaying the list of conversations
class ConversationList extends StatefulWidget {
  const ConversationList({super.key});

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late Future<List<ConversationPreview>> _conversationsFuture;
  late final ChatService _chatService;
  // AuthService is no longer strictly necessary since we only need the other user's info
  // final AuthService _authService = Provider.of<AuthService>(context, listen: false); 

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    // Start fetching the list of other participants immediately
    _conversationsFuture = _chatService.getAllConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _chatService.getAllConversations();
      if (!mounted) return;
      setState(() {
        _conversationsFuture = Future.value(conversations);
      });
    } catch (e) {
      if (!mounted) return;
      // Show error in a SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationPreview>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No active chats. Start one now!'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).push('/chat/create');
                  },
                  child: const Text('Start a New Chat'),
                ),
              ],
            ),
          );
        } else {
          final conversations = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final otherUser = conversations[index];
                final displayName = otherUser.username;

                // All previous logic for lastMessage, unreadCount, isGroup,
                // and multi-participants has been REMOVED.

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: AppColors.textWhite,
                      // Display the first letter of the username
                      child: Text(displayName[0].toUpperCase()),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // subtitle is removed as there is no last message data
                    // trailing is removed as there is no unread count data
                    onTap: () {
                      // Navigate using the other user's ID
                      GoRouter.of(context).push('/chat/${otherUser.id}'); 
                      
                      // NOTE: We no longer pass `extra: conversation` as it 
                      // is now minimal and likely unnecessary for the chat detail screen.
                    },
                    // Long press is removed since there are no options now
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }
}
