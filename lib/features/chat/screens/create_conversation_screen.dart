import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
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
  List<Friend> _searchResults = [];
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

  void _startConversation(Friend user, String content) async {
    try {
      // Assuming sendMessage can take a recipientId and content
      // You might need to adjust this based on your ChatService implementation
      await _chatService.sendMessage(recipientId: user.id, content: content);
      if (mounted) {
        // Navigate to the chat screen or show a confirmation
        // For now, just pop back
        GoRouter.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversation started with ${user.username}')),
        );
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
            // Example of starting a chat by tapping the user
            onTap: () => _startConversation(user, 'Hey!'),
          );
        },
      ),
    );
  }
}