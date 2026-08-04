import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/widgets/report_dialog.dart';
import 'package:npo_community/core/utils/flair_utils.dart';

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
      appBar: AppBar(title: const Text('Friends')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).push('/user-search');
        },
        tooltip: 'Search for Users',
        child: const Icon(Icons.search),
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
            return const Center(child: Text('Use the search to find friends!'));
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final isPrivate = FlairUtils.isProfilePrivate(friend.flair);
              final String? pronounsDisplay = isPrivate
                  ? null
                  : (FlairUtils.extractPronouns(friend.flair) ?? '')
                        .split(RegExp(r'[\n,]'))
                        .map((p) => p.trim())
                        .where((p) => p.isNotEmpty)
                        .join(' • ');
              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    GoRouter.of(context).push('/users/${friend.id}');
                  },
                  child: DisplayProfilePic(
                    radius: 20,
                    imageUrl: friend.fullProfilePicUrl,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        GoRouter.of(context).push('/users/${friend.id}');
                      },
                      child: Text(friend.username),
                    ),
                    if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          pronounsDisplay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                subtitle: isPrivate
                    ? const Text('Private profile')
                    : (friend.statusMessage != null &&
                              friend.statusMessage!.isNotEmpty
                          ? Text(friend.statusMessage!)
                          : null),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    GoRouter.of(context).push('/users/${friend.id}');
                  },
                ),
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
      ),
    );
  }
}
