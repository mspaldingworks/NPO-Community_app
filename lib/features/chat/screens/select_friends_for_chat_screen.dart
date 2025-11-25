import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/user.dart';

class SelectFriendsForChatScreen extends StatefulWidget {
  const SelectFriendsForChatScreen({super.key});

  @override
  State<SelectFriendsForChatScreen> createState() =>
      _SelectFriendsForChatScreenState();
}

class _SelectFriendsForChatScreenState extends State<SelectFriendsForChatScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  late Future<User> _userProfileFuture;
  final Set<Friend> _selectedFriends = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _authService.getProfile();
  }

  void _onFriendSelected(Friend friend, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedFriends.add(friend);
      } else {
        _selectedFriends.remove(friend);
      }
    });
  }

  Future<void> _startChat() async {
    if (_selectedFriends.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // COMMENTED OUT
      // final participantIds =
      //     _selectedFriends.map((friend) => friend.id.toString()).toList();
      // final chatName = _selectedFriends.map((friend) => friend.username).join(', ');

      // final conversation = await _chatService.sendMessage(
      //   recipientId: participantIds,
      //   content: chatName.isEmpty ? null : chatName
      // );

      // if (mounted) {
      //   context.go('/chat/${conversation.id}', extra: conversation);
      // }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _selectedFriends.isNotEmpty ? _startChat : null,
                ),
        ],
      ),
      body: FutureBuilder<User>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.friends.isEmpty) {
            return const Center(
              child: Text('You have no friends to start a chat with.'),
            );
          } else {
            final friends = snapshot.data!.friends;
            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final isSelected =
                    _selectedFriends.any((selected) => selected.id == friend.id);

                return CheckboxListTile(
                  title: Text(friend.username),
                  subtitle: friend.statusMessage != null
                      ? Text(friend.statusMessage!)
                      : null,
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
