import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/theme/app_theme.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _searchResults = [];
  bool _isLoading = true;
  final Set<String> _sentRequests = {}; // Track sent requests

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
      final users = await _authService.getAllUsers();
      final currentUser = _authService.currentUser;

      if (mounted && currentUser != null) {
        final friendIds = currentUser.friends.map((f) => f.id).toSet();

        // Filter out the current user and existing friends
        final filteredUsers = users.where((user) {
          return user.id != currentUser.id && !friendIds.contains(user.id);
        }).toList();

        setState(() {
          _allUsers = filteredUsers;
          _searchResults = filteredUsers;
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

  void _sendFriendRequest(String username) async {
    // Prevent sending multiple requests
    if (_sentRequests.contains(username)) return;

    try {
      await _friendService.sendFriendRequest(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
        // Update the UI to show the request has been sent
        setState(() {
          _sentRequests.add(username);
        });
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
          style: const TextStyle(color: AppColors.textWhite),
          decoration: const InputDecoration(
            hintText: 'Search for users...',
            hintStyle: TextStyle(color: AppColors.textWhite),
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
                final isRequestSent = _sentRequests.contains(user.username);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profilePic != null
                        ? NetworkImage(user.profilePic!)
                        : null,
                    child: user.profilePic == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(user.username),
                      if (user.userType == 'org') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.corporate_fare, size: 16, color: Colors.grey),
                      ],
                    ],
                  ),
                  trailing: isRequestSent
                      ? const Chip(
                          label: Text('Sent'),
                          backgroundColor: Colors.grey,
                        )
                      : IconButton(
                          icon: const Icon(Icons.person_add_alt_1, color: AppColors.secondary),
                          tooltip: 'Add Friend',
                          onPressed: () => _sendFriendRequest(user.username),
                        ),
                );
              },
            ),
    );
  }
}
