import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:transconnect/widgets/display_profile_pic.dart';

class PostListScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const PostListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  late Future<List<Post>> _postsFuture;
  late final CommunityService _communityService;
  final AuthService _authService = AuthService();
  Map<String, String?> _userPicByUsername = {};

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _loadPosts();
  }

  void _loadPosts() {
    setState(() {
      _postsFuture = _communityService.fetchPostsForGroup(widget.groupId);
    });
    _loadUserPicMap();
  }

  Future<void> _loadUserPicMap() async {
    try {
      final users = await _authService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _userPicByUsername = {
          for (final u in users) u.username: u.fullProfilePicUrl,
        };
      });
    } catch (_) {
      // Ignore silently; avatars will remain placeholders
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _loadPosts();
    });
  }

  void _deletePost(int postId) async {
    try {
      await _communityService.deletePost(postId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully')),
      );
      _refreshPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  void _showDeleteConfirmationDialog(int postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePost(postId);
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.tertiary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: FutureBuilder<List<Post>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('No posts found in this group.'),
                    SizedBox(height: 16),
                    Text('Be the first to post!'),
                  ],
                ),
              );
            } else {
              final posts = snapshot.data!;

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postDate = post.pubDate != null ? DateTime.parse(post.pubDate!) : DateTime.now();
                  String editedLabel = '';
                  if (post.isEdited && post.updatedAt != null) {
                    try {
                      final editedDate = DateTime.parse(post.updatedAt!).toLocal();
                      editedLabel = ' · Edited ${timeago.format(editedDate)}';
                    } catch (_) {
                      editedLabel = ' · Edited';
                    }
                  }
                  final displayAuthor = post.isAnonymous
                      ? 'Anonymous'
                      : (post.authorUsername ?? 'Unknown user');

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        GoRouter.of(context).push(
                          '/community/group/${widget.groupId}/post/${post.id}',
                          extra: post,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DisplayProfilePic(
                                  radius: 20,
                                  imageUrl: post.authorProfilePic ?? _userPicByUsername[post.authorUsername ?? ''],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(displayAuthor, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (post.authorIsStaff)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: Chip(
                                                avatar: const Icon(Icons.shield, size: 12, color: Colors.white),
                                                label: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.white)),
                                                backgroundColor: AppColors.primary,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'By ${post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user')} · ${timeago.format(postDate)}$editedLabel',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (post.emojis.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      post.emojis.first,
                                      style: const TextStyle(fontSize: 48),
                                    ),
                                  ),
                                if (currentUser != null && currentUser.id == post.author)
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        _showDeleteConfirmationDialog(post.id);
                                      } else if (value == 'edit') {
                                        final result = await context.push('/community/group/${widget.groupId}/post/${post.id}/edit', extra: post);
                                        if (result == true && mounted) {
                                          _refreshPosts();
                                        }
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(post.title ?? '', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(post.body ?? ''),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/community/group/${widget.groupId}/create-post');
          if (result == true && mounted) {
            _loadPosts();
          }
        },
        tooltip: 'Add Post',
        child: const Icon(Icons.add),
      ),
    );
  }
}
