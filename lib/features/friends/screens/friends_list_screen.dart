import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/features/chat/services/chat_service.dart';
import 'package:transconnect/models/user.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  late Future<List<User>> _friendsFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _friendService.fetchFriends();
    _currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  }

  // Generates a unique channel ID for a 1-on-1 chat.
  String _createChannelId(String otherUserId) {
    if (_currentUserId == null) {
      throw Exception('Current user not found');
    }
    final ids = [_currentUserId!, otherUserId];
    ids.sort(); // Sort to ensure the ID is always the same for both users.
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).push('/user-search');
        },
        child: const Icon(Icons.search),
        tooltip: 'Search for Users',
      ),
      body: FutureBuilder<List<User>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Create a new list from the snapshot data, or an empty list if null.
          final friends = List<User>.from(snapshot.data ?? []);

          if (friends.isEmpty) {
            return const Center(child: Text('Use the search to find friends!'));
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend.profilePic != null
                      ? NetworkImage(friend.profilePic!)
                      : null,
                  child: friend.profilePic == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Row(
                  children: [
                    Text(friend.username),
                    if (friend.userType == 'org') ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.corporate_fare, size: 16, color: Colors.grey),
                    ],
                  ],
                ), // Assuming User model has a 'username' field
                subtitle: Text(friend.statusMessage ?? ''),
                onTap: () async {
                  try {
                    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
                    if (currentUser == null) {
                      throw Exception('Current user not found');
                    }

                    final conversation = await _chatService.createConversation(
                      userIds: [currentUser.id, friend.id],
                    );

                    if (mounted) {
                      GoRouter.of(context).push('/chat/${conversation.id}');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start chat: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
