import 'package:flutter/material.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/models/user.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  late Future<User> _userProfileFuture;
  List<Friend> _allFriends = [];
  List<Friend> _filteredFriends = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userProfileFuture = AuthService().getProfile();
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
    return FutureBuilder<User>(
      future: _userProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          _allFriends = snapshot.data!.friends;
          _filteredFriends = _allFriends;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Friends',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: _filteredFriends.isEmpty
                    ? const Center(
                        child: Text(
                          'You have no friends yet, or the list is empty.',
                        ),
                      )
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
        } else {
          return const Center(child: Text('No friends found.'));
        }
      },
    );
  }
}
