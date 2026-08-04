import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/friends_controller.dart';
import 'pending_request_tile.dart';
import 'pending_sent_tile.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/core/utils/time_ago.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/core/services/chat_favorites_service.dart';

class FriendsTabView extends StatefulWidget {
  const FriendsTabView({super.key});

  @override
  State<FriendsTabView> createState() => _FriendsTabViewState();
}

class _FriendsTabViewState extends State<FriendsTabView> {
  late final FriendsController _friendsController;
  final ChatFavoritesService _chatFavoritesService = ChatFavoritesService();

  Set<int> _favoriteChatIds = <int>{};

  @override
  void initState() {
    super.initState();
    _friendsController = FriendsController();
    _fetchData();
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

  Future<void> _fetchData() async {
    await Future.wait([
      _friendsController.fetchPendingRequests(),
      _friendsController.fetchFriends(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _friendsController,
      child: Consumer<FriendsController>(
        builder: (context, controller, child) {
          return TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: _fetchData,
                child: controller.isLoadingPending
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          if (controller.pendingError != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(controller.pendingError!),
                            ),
                          if (controller.pendingRequests.isNotEmpty) ...[
                            _buildSectionHeader('Incoming Requests'),
                            ...controller.pendingRequests.map(
                              (request) => PendingRequestTile(request: request),
                            ),
                            const Divider(),
                          ],
                          if (controller.pendingSentRequests.isNotEmpty) ...[
                            _buildSectionHeader('Outgoing Requests'),
                            ...controller.pendingSentRequests.map(
                              (request) => PendingSentTile(request: request),
                            ),
                            const Divider(),
                          ],
                          if (controller.pendingRequests.isEmpty &&
                              controller.pendingSentRequests.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No pending requests.'),
                              ),
                            ),
                        ],
                      ),
              ),
              RefreshIndicator(
                onRefresh: _fetchData,
                child: controller.isLoadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          if (controller.friendsError != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(controller.friendsError!),
                            ),
                          if (controller.friends.isNotEmpty) ...[
                            _buildSectionHeader('Friends'),
                            ...controller.friends.map(
                              (friend) => _buildFriendTile(friend),
                            ),
                          ],
                          if (controller.friends.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No friends yet.'),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget? _buildStatusSubtitle(Friend friend) {
    final msg = friend.statusMessage;
    final when = friend.statusUpdatedAt;
    if (msg == null || msg.isEmpty) return null;
    if (when == null) return Text(msg);
    return Text('$msg • ${timeAgo(when)}');
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    final isPrivate = FlairUtils.isProfilePrivate(friend.flair);
    final String? pronounsDisplay = isPrivate
        ? null
        : (FlairUtils.extractPronouns(friend.flair) ?? '')
              .split(RegExp(r'[\n,]'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .join(' • ');

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          context.push('/users/${friend.id}');
        },
        child: DisplayProfilePic(
          radius: 20,
          imageUrl: friend.fullProfilePicUrl,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(friend.username),
          if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                pronounsDisplay,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      subtitle: _buildStatusSubtitle(friend),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _favoriteChatIds.contains(friend.id)
                ? 'Unfavorite chat'
                : 'Favorite chat',
            icon: Icon(
              _favoriteChatIds.contains(friend.id)
                  ? Icons.star
                  : Icons.star_border,
              color: _favoriteChatIds.contains(friend.id)
                  ? Colors.amber
                  : Colors.grey,
            ),
            onPressed: () => _toggleFavorite(friend.id),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Message',
            onPressed: () => GoRouter.of(context).push('/chat/${friend.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showFriendOptions(context, friend);
            },
          ),
        ],
      ),
    );
  }

  void _showFriendOptions(BuildContext parentContext, Friend friend) {
    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(sheetContext);
                GoRouter.of(parentContext).push('/chat/${friend.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text(
                'Remove Friend',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: parentContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Remove Friend'),
                    content: Text(
                      'Are you sure you want to remove ${friend.username} from your friends?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await _friendsController.removeFriend(
                    friend.username,
                  );
                  if (!parentContext.mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${friend.username} removed from friends',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Failed to remove friend')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
