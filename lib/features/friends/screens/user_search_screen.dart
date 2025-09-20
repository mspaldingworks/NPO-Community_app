import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/models/user.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final FriendService _friendService = FriendService();
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
        setState(() {
          _searchResults = [];
        });
        return;
      }
      setState(() {
        _isLoading = true;
      });
      try {
        final results = await _friendService.searchUsers(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
          });
        }
      } catch (e) {
        // Handle error, e.g., show a snackbar
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _sendFriendRequest(int userId) async {
    try {
      await _friendService.sendFriendRequest(userId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
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
            hintText: 'Search for users...',
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
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite_border),
                    tooltip: 'Add Friend',
                    onPressed: () => _sendFriendRequest(user.id),
                  ),
                );
              },
            ),
    );
  }
}
