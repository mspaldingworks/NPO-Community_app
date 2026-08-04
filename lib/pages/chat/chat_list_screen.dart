import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/chat_favorites_service.dart';
import 'package:npo_community/core/services/chat_service.dart';
import 'package:npo_community/widgets/friends/friends_tab_view.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/core/utils/flair_utils.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connect'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Friends'),
            ],
          ),
        ),
        body: const FriendsTabView(),
        floatingActionButton: TourAnchor(
          name: 'Add Friend',
          child: FloatingActionButton(
            onPressed: () => GoRouter.of(context).push('/user-search'),
            tooltip: 'Add Friend',
            child: const Icon(Icons.person_add),
          ),
        ),
      ),
    );
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
  final AuthService _authService = AuthService();
  final ChatFavoritesService _chatFavoritesService = ChatFavoritesService();
  Map<int, String?> _userFlairById = {};
  Set<int> _favoriteChatIds = <int>{};

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    // Start fetching the list of other participants immediately
    _conversationsFuture = _chatService.getAllConversations();
    _loadUserFlairMap();
    _loadFavoriteChatIds();
  }

  Future<void> _loadFavoriteChatIds() async {
    final ids = await _chatFavoritesService.getFavoriteChatIds();
    if (!mounted) return;
    setState(() {
      _favoriteChatIds = ids;
    });
  }

  Future<void> _toggleFavorite(int userId) async {
    final isFavorite = _favoriteChatIds.contains(userId);
    await _chatFavoritesService.setChatFavorite(
      chatId: userId,
      isFavorite: !isFavorite,
    );
    await _loadFavoriteChatIds();
  }

  Future<void> _loadUserFlairMap() async {
    try {
      final users = await _authService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _userFlairById = {for (final u in users) u.id: u.flair};
      });
    } catch (_) {
      // Ignore silently; pronouns will not be displayed
    }
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _chatService.getAllConversations();
      if (!mounted) return;
      setState(() {
        _conversationsFuture = Future.value(conversations);
      });
      await _loadUserFlairMap();
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
                final flair = _userFlairById[otherUser.id];
                final isPrivate = FlairUtils.isProfilePrivate(flair);
                final String? pronounsDisplay = isPrivate
                    ? null
                    : (FlairUtils.extractPronouns(flair) ?? '')
                          .split(RegExp(r'[\n,]'))
                          .map((p) => p.trim())
                          .where((p) => p.isNotEmpty)
                          .join(' • ');

                // All previous logic for lastMessage, unreadCount, isGroup,
                // and multi-participants has been REMOVED.

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        GoRouter.of(context).push('/users/${otherUser.id}');
                      },
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: AppColors.textWhite,
                        // Display the first letter of the username
                        child: Text(displayName[0].toUpperCase()),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () {
                        GoRouter.of(context).push('/users/${otherUser.id}');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (pronounsDisplay != null &&
                              pronounsDisplay.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                pronounsDisplay,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: _favoriteChatIds.contains(otherUser.id)
                          ? 'Unfavorite chat'
                          : 'Favorite chat',
                      icon: Icon(
                        _favoriteChatIds.contains(otherUser.id)
                            ? Icons.star
                            : Icons.star_border,
                        color: _favoriteChatIds.contains(otherUser.id)
                            ? Colors.amber
                            : Colors.grey,
                      ),
                      onPressed: () => _toggleFavorite(otherUser.id),
                    ),
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
