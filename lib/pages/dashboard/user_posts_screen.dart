import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/post.dart';

class UserPostsScreen extends StatefulWidget {
  const UserPostsScreen({super.key});

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  final CommunityService _communityService = CommunityService();
  final AuthService _authService = AuthService();

  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadUserPosts();
  }

  Future<List<Post>> _loadUserPosts() async {
    final currentUser = await _authService.getCurrentUser();
    final posts = await _communityService.fetchAllPosts();
    return posts.where((post) => post.author == currentUser.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
      ),
      body: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load posts: ${snapshot.error}'),
              ),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'You have not created any posts yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final formattedDate = _formatDate(post.pubDate);
              final commentCount = post.comments.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(post.title?.isNotEmpty == true ? post.title! : 'Untitled Post'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (formattedDate != null) Text(formattedDate),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.message_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text('$commentCount comment${commentCount == 1 ? '' : 's'}'),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return null;
    }
    DateTime? parsed;
    try {
      parsed = DateTime.parse(rawDate).toLocal();
    } catch (_) {
      return rawDate;
    }
    return DateFormat.yMMMEd().add_jm().format(parsed);
  }
}
