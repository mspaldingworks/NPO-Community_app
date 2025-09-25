import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/features/chat/services/chat_service.dart';
import 'package:transconnect/models/user.dart';

class SelectFriendsForChatScreen extends StatefulWidget {
  const SelectFriendsForChatScreen({super.key});

  @override
  State<SelectFriendsForChatScreen> createState() => _SelectFriendsForChatScreenState();
}

class _SelectFriendsForChatScreenState extends State<SelectFriendsForChatScreen> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  late Future<List<User>> _friendsFuture;
  final Set<User> _selectedFriends = {};

  @override
  void initState() {
    super.initState();
    // _friendsFuture = _friendService.fetchFriends(); MADDIE TODO Friends are returned as a list within the user use that instead
  }

  void _onFriendSelected(User friend, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedFriends.add(friend);
      } else {
        _selectedFriends.remove(friend);
      }
    });
  }

  void _startChat() async {
    if (_selectedFriends.isEmpty) {
      return;
    }
    try {
      final participantIds = _selectedFriends.map((user) => user.id).toList();
      // We'll need to update createConversation to handle a list of participants
      final conversation = await _chatService.createConversation(userIds: participantIds);
      if (mounted) {
        context.go('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedFriends.isNotEmpty ? _startChat : null,
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
                final isSelected = _selectedFriends.contains(friend);
                return CheckboxListTile(
                  title: Text(friend.username),
                  value: isSelected,
                  onChanged: (bool? selected) {
                    if (selected != null) {
                      _onFriendSelected(friend, selected);
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
