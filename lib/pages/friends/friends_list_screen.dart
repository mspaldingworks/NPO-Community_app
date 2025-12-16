import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/widgets/report_dialog.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final AuthService _authService = AuthService();
  late Future<List<Friend>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriendsFromUser();
  }

  Future<List<Friend>> _loadFriendsFromUser() async {
    final user = await _authService.getCurrentUser();
    return user.friends;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            GoRouter.of(context).push('/user-search');
          },
          child: const Icon(Icons.search),
          tooltip: 'Search for Users',
        ),
        body: FutureBuilder<List<Friend>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // Create a new list from the snapshot data, or an empty list if null.
            final friends = List<Friend>.from(snapshot.data ?? []);

            if (friends.isEmpty) {
              return const Center(
                  child: Text('Use the search to find friends!'));
            }

            return ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  leading: DisplayProfilePic(radius: 20, imageUrl: friend.fullProfilePicUrl),
                  title: Text(friend
                      .username), // Assuming User model has a 'username' field
                  subtitle: friend.statusMessage != null &&
                          friend.statusMessage!.isNotEmpty
                      ? Text(friend.statusMessage!)
                      : null,
                  onTap: () {
                    GoRouter.of(context).push('/chat/${friend.id}');
                  },
                  onLongPress: () async {
                    await showReportDialog(
                      context: context,
                      baseRequest: ReportRequest(
                        type: ReportTargetType.user,
                        reason: '',
                        targetUserId: friend.id,
                        targetUsername: friend.username,
                        details: friend.statusMessage,
                      ),
                    );
                  },
                );
              },
            );
          },
        )
      );
  }
}
