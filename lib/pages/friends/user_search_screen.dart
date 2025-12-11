import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  List<Friend> _searchResults = [];
  Timer? _debounce;
  bool _isLoading = false;
  Map<int, _FriendRequestStatus> _requestStates = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await _friendService.searchFriends(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _requestStates = {
            for (final friend in results)
              friend.id: _requestStates[friend.id] ?? _FriendRequestStatus.idle,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to perform search: $e')),
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

  void _sendFriendRequest(String username) async {
    final friend = _searchResults.firstWhere((f) => f.username == username, orElse: () => Friend(id: -1, username: username, email: ''));
    if (friend.id == -1) {
      return;
    }

    setState(() {
      _requestStates[friend.id] = _FriendRequestStatus.sending;
    });

    try {
      await _friendService.sendFriendRequest(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
        setState(() {
          _requestStates[friend.id] = _FriendRequestStatus.sent;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
        setState(() {
          _requestStates[friend.id] = _FriendRequestStatus.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search for users...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _requestStates = {};
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Search for users by username to send friend requests.'),
                  ),
                )
              : ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final friend = _searchResults[index];
                    final status = _requestStates[friend.id] ?? _FriendRequestStatus.idle;

                    return ListTile(
                      leading: DisplayProfilePic(radius: 20, imageUrl: friend.fullProfilePicUrl),
                      title: Text(friend.username),
                      subtitle: friend.statusMessage != null && friend.statusMessage!.isNotEmpty
                          ? Text(friend.statusMessage!)
                          : (friend.city != null && friend.city!.isNotEmpty
                              ? Text(friend.city!)
                              : null),
                      trailing: _buildActionButton(friend, status),
                    );
                  },
                ),
    );
  }

  Widget _buildActionButton(Friend friend, _FriendRequestStatus status) {
    switch (status) {
      case _FriendRequestStatus.sending:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _FriendRequestStatus.sent:
        return const Chip(
          label: Text('Request Sent'),
          avatar: Icon(Icons.check, size: 16),
        );
      case _FriendRequestStatus.failed:
        return TextButton.icon(
          onPressed: () => _sendFriendRequest(friend.username),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        );
      case _FriendRequestStatus.idle:
      default:
        return ElevatedButton.icon(
          onPressed: () => _sendFriendRequest(friend.username),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add Friend'),
        );
    }
  }
}

enum _FriendRequestStatus { idle, sending, sent, failed }
