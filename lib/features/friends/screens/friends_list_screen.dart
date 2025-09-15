import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/features/community/screens/chat_screen.dart';
import 'package:transconnect/models/user.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();
  late Future<List<User>> _friendsFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _friendService.fetchFriends();
    _currentUserId = _authService.currentUser?.uid;
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
    return FutureBuilder<List<User>>(
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

        // Create a placeholder for Mad.e
        final madeUser = User(
          uid: 'made_user_id', // A unique, static ID for Mad.e
          username: 'Mad.e',
          email: '', // Placeholder
          city: '', // Placeholder
          token: '', // Placeholder
        );

        // Add Mad.e to the list if they aren't already there and isn't the current user
        if (_currentUserId != madeUser.uid && !friends.any((f) => f.uid == madeUser.uid)) {
          friends.insert(0, madeUser);
        }

        if (friends.isEmpty) {
          return const Center(child: Text('You have no friends yet.'));
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return ListTile(
              leading: const CircleAvatar(
                // TODO: Use friend's profile picture
                child: Icon(Icons.person),
              ),
              title: Text(friend.username), // Assuming User model has a 'username' field
              subtitle: Text('Offline'), // TODO: Implement real-time status
              onTap: () {
                final channelId = _createChannelId(friend.uid);
                GoRouter.of(context).push('/chat/$channelId');
              },
            );
          },
        );
      },
    );
  }
}
