import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart'; 
import 'package:transconnect/models/user.dart';

class SelectFriendsForChatScreen extends StatefulWidget {
  const SelectFriendsForChatScreen({super.key});

  @override
  State<SelectFriendsForChatScreen> createState() => _SelectFriendsForChatScreenState();
}

class _SelectFriendsForChatScreenState extends State<SelectFriendsForChatScreen> {
  final AuthService _authService = AuthService();
  late Future<List<User>> _friendsFuture;
  User? _selectedFriend;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
  }

  Future<List<User>> _loadFriends() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null && currentUser.friends.isNotEmpty) {
      final userFriends = currentUser.friends.map((friend) {
        return User(
          id: friend.id,
          username: friend.username,
          email: '', // email is not available on the Friend model, provide a placeholder
          city: friend.city,
          statusMessage: friend.statusMessage,
          flair: friend.flair,
          profilePic: friend.profilePic,
        );
      }).toList();
      return Future.value(userFriends);
    }
    return Future.value([]); // Return empty list if no user or no friends
  }

  void _onFriendSelected(User? friend) {
    setState(() {
      _selectedFriend = friend;
    });
  }

  void _startChat() {
    if (_selectedFriend == null) {
      return;
    }
    context.go('/chat/${_selectedFriend!.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedFriend != null ? _startChat : null,
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no friends to start a chat with.'));
          } else {
            final friends = snapshot.data!;
            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return RadioListTile<User>(
                  title: Text(friend.username),
                  value: friend,
                  groupValue: _selectedFriend,
                  onChanged: _onFriendSelected,
                );
              },
            );
          }
        },
      ),
    );
  }
}
