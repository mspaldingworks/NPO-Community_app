import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/models/user.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  final FriendService _friendService = FriendService();
  late Future<List<User>> _friendsFuture;
  List<User> _allFriends = [];
  List<User> _filteredFriends = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _friendsFuture = _friendService.fetchFriends(); MADDIE TODO Friends are returned as a list within the user use that instead
    _friendsFuture.then((friends) {
      if (mounted) {
        setState(() {
          _allFriends = friends;
          _filteredFriends = friends;
        });
      }
    });
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
            decoration: const InputDecoration(
              labelText: 'Search Friends',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<User>>(
            future: _friendsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('You have no friends yet.'));
              } else {
                return ListView.builder(
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _filteredFriends[index];
                    return ListTile(
                      title: Text(friend.username),
                      subtitle: Text(friend.statusMessage ?? 'No status'),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
