import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/features/friends/widgets/friends_tab_view.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/models/conversation.dart';
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
  late Future<List<Conversation>> _conversationsFuture;
  late final ChatService _chatService;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _authService = Provider.of<AuthService>(context, listen: false);
    _conversationsFuture = _chatService.fetchConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _chatService.fetchConversations();
      if (!mounted) return;
      setState(() {
        _conversationsFuture = Future.value(conversations);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Conversation>>(
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
                const Text('No conversations yet.'),
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
                final conversation = conversations[index];
                final currentUserId = _authService.currentUser?.id;
                final otherParticipants = conversation.participants
                    .where((user) => user.id != currentUserId)
                    .toList();
                final displayName = conversation.isGroup
                    ? conversation.name ?? 'Group Chat'
                    : otherParticipants.isNotEmpty
                        ? otherParticipants.first.username
                        : 'Unknown';

                final lastMessage = conversation.lastMessage;
                final lastMessageText = lastMessage?.content ?? 'No messages yet';
                final lastMessageTime = lastMessage?.createdAt != null
                    ? _formatTimeAgo(lastMessage!.createdAt!)
                    : '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: conversation.unreadCount > 0
                          ? AppColors.tertiary
                          : Colors.grey.shade300,
                      foregroundColor: conversation.unreadCount > 0
                          ? AppColors.textWhite
                          : AppColors.textBlack,
                      backgroundImage: conversation.isGroup || otherParticipants.isEmpty
                          ? null
                          : (otherParticipants.first.profilePic != null
                              ? NetworkImage(otherParticipants.first.profilePic!)
                              : null),
                      child: conversation.unreadCount > 0
                          ? Text(conversation.unreadCount.toString())
                          : conversation.isGroup
                              ? const Icon(Icons.group)
                              : otherParticipants.isNotEmpty && otherParticipants.first.profilePic == null
                                  ? Text(displayName[0].toUpperCase())
                                  : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime.isNotEmpty)
                          Text(
                            lastMessageTime,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      lastMessageText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: conversation.unreadCount > 0
                            ? Theme.of(context).primaryColor
                            : null,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: conversation.unreadCount > 0
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      if (conversation.unreadCount > 0 &&
                          conversation.lastMessage != null &&
                          conversation.lastMessage!.id.isNotEmpty) {
                        _chatService.markAsRead(
                          conversationId: conversation.id,
                          messageIds: [conversation.lastMessage!.id],
                        );
                      }
                      GoRouter.of(context).push(
                        '/chat/${conversation.id}',
                        extra: conversation,
                      );
                    },
                    onLongPress: () {
                      _showConversationOptions(conversation);
                    },
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showConversationOptions(Conversation conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Conversation'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteConversation(conversation.id);
                },
              ),
              ListTile(
                leading: Icon(conversation.isMuted ? Icons.notifications : Icons.notifications_off),
                title: Text(conversation.isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleMuteConversation(conversation);
                },
              ),
              if (conversation.isGroup)
                ListTile(
                  leading: const Icon(Icons.group_remove),
                  title: const Text('Leave Group'),
                  onTap: () {
                    Navigator.pop(context);
                    _leaveGroup(conversation.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      await _chatService.deleteConversation(conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete conversation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleMuteConversation(Conversation conversation) async {
    try {
      await _chatService.updateConversation(
        conversationId: conversation.id,
        isMuted: !conversation.isMuted,
      );
      if (mounted) {
        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update notification settings')),
        );
      }
    }
  }

  Future<void> _leaveGroup(String conversationId) async {
    try {
      await _chatService.leaveGroup(conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left the group')),
        );
        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to leave group')),
        );
      }
    }
  }
}
