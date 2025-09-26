import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/theme/app_theme.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  List<Friend> _allFriends = [];
  List<Friend> _filteredFriends = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    if (user != null) {
      _allFriends = user.friends;
      _filteredFriends = user.friends;
    }
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFriends);
    _searchController.dispose();
    super.dispose();
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFriends = _allFriends
          .where((friend) => friend.username.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Search Friends',
              labelStyle: const TextStyle(color: AppColors.textWhite),
              hintStyle: const TextStyle(color: AppColors.textWhite),
              prefixIcon: const Icon(Icons.search, color: AppColors.textWhite),
              filled: true,
              fillColor: AppColors.primary.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.secondary, width: 2.0),
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredFriends.isEmpty
              ? const Center(child: Text('You have no friends yet, or the list is empty.'))
              : ListView.builder(
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _filteredFriends[index];
                    return ListTile(
                      title: Text(friend.username),
                      subtitle: Text(friend.statusMessage ?? 'No status'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
