import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/features/community/services/community_service.dart';
import 'package:transconnect/features/friends/screens/friend_requests_screen.dart';
import 'package:transconnect/features/friends/screens/friends_list_screen.dart';
import 'package:transconnect/models/post.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Post>> _postsFuture;
  final CommunityService _communityService = CommunityService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _postsFuture = _communityService.fetchPosts();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuilds the widget to show/hide the FAB
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Posts Tab
          FutureBuilder<List<Post>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No posts found.'));
              } else {
                final posts = snapshot.data!;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(post.title),
                        subtitle: Text(post.body),
                        onTap: () {
                          // TODO: Implement navigation to post details screen if needed
                        },
                      ),
                    );
                  },
                );
              }
            },
          ),
          // Friends Tab
          const FriendsListScreen(),
          // Friend Requests Tab
          const FriendRequestsScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                GoRouter.of(context).push('/user-search');
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
