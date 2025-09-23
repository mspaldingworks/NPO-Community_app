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
  List<User> _allUsers = [];
  List<User> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
    _searchController.addListener(() {
      _filterUsers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    try {
      final users = await _friendService.fetchAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _searchResults = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  void _filterUsers(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _searchResults = _allUsers.where((user) {
        return user.username.toLowerCase().contains(lowerCaseQuery);
      }).toList();
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
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  title: Row(
                    children: [
                      Text(user.username),
                      if (user.userType == 'org') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.corporate_fare, size: 16, color: Colors.grey),
                      ],
                    ],
                  ),
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
