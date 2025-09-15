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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('You have no friends yet.'));
        }

        final friends = snapshot.data!;
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
