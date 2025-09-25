import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/features/chat/services/chat_service.dart';
import 'package:transconnect/models/user.dart';

class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({super.key});

  @override
  State<CreateConversationScreen> createState() => _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      try {
        final results = await _friendService.searchFriends(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
          });
        }
      } catch (e) {
        // Handle error
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _startConversation(User user) async {
    try {
      final conversation = await _chatService.createConversation(userIds: [user.id]);
      if (mounted) {
        // Navigate to the new chat screen, replacing the current screen
        GoRouter.of(context).pushReplacement('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for a user to chat with...',
            border: InputBorder.none,
          ),
          onChanged: _searchUsers,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  title: Text(user.username),
                  onTap: () => _startConversation(user),
                );
              },
            ),
    );
  }
}
