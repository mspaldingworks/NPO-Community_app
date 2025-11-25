import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/features/friends/controllers/friends_controller.dart';
import 'package:transconnect/features/friends/widgets/pending_request_tile.dart';
import 'package:transconnect/models/user.dart';

class FriendsTabView extends StatefulWidget {
  const FriendsTabView({Key? key}) : super(key: key);

  @override
  State<FriendsTabView> createState() => _FriendsTabViewState();
}

class _FriendsTabViewState extends State<FriendsTabView> {
  late final FriendsController _friendsController;

  @override
  void initState() {
    super.initState();
    _friendsController = FriendsController();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await _friendsController.fetchPendingRequests();
    await _friendsController.fetchFriends();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _friendsController,
      child: Consumer<FriendsController>(
        builder: (context, controller, child) {
          if (controller.isLoadingPending || controller.isLoadingFriends) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView(
              children: [
                if (controller.pendingRequests.isNotEmpty) ...[
                  _buildSectionHeader('Pending Requests'),
                  ...controller.pendingRequests.map(
                    (request) => PendingRequestTile(request: request),
                  ),
                  const Divider(),
                ],
                if (controller.friends.isNotEmpty) ...[
                  _buildSectionHeader('Friends'),
                  ...controller.friends.map(
                    (friend) => _buildFriendTile(friend),
                  ),
                ],
                if (controller.pendingRequests.isEmpty && controller.friends.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No pending requests.'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: friend.profilePic != null ? NetworkImage(friend.profilePic!) : null,
        child: friend.profilePic == null ? const Icon(Icons.person) : null,
      ),
      title: Text(friend.username),
      subtitle: friend.statusMessage != null ? Text(friend.statusMessage!) : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          _showFriendOptions(context, friend);
        },
      ),
    );
  }

  void _showFriendOptions(BuildContext context, Friend friend) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to chat with friend
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Remove Friend', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Friend'),
                    content: Text('Are you sure you want to remove ${friend.username} from your friends?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await _friendsController.removeFriend(friend.username);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${friend.username} removed from friends')),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
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
