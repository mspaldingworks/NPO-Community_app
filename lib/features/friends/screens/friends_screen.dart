import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/theme/app_theme.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Add listener to rebuild the widget on search query changes
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final currentUser = authService.currentUser;
        final allFriends = currentUser?.friends ?? [];

        final query = _searchController.text.toLowerCase();
        final filteredFriends = allFriends
            .where((friend) => friend.username.toLowerCase().contains(query))
            .toList();

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
              child: filteredFriends.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'You have no friends yet. Use the button below to find some!'
                            : 'No friends found matching your search.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = filteredFriends[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: friend.profilePic != null
                                ? NetworkImage(friend.profilePic!)
                                : null,
                            child: friend.profilePic == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(friend.username),
                          subtitle: Text(friend.statusMessage ?? 'No status'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
