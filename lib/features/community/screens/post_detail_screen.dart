import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/theme/app_theme.dart';

class PostDetailScreen extends StatefulWidget {
  final int groupId;
  final int postId;

  const PostDetailScreen({super.key, required this.groupId, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post> _postFuture;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    final communityService = Provider.of<CommunityService>(context, listen: false);
    setState(() {
      _postFuture = communityService.fetchPostById(widget.postId);
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    final communityService = Provider.of<CommunityService>(context, listen: false);
    try {
      await communityService.addComment(
        postId: widget.postId,
        content: _commentController.text,
      );
      _commentController.clear();
      _loadPost(); // Refresh the post data to show the new comment
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final communityService = Provider.of<CommunityService>(context, listen: false);
    try {
      await communityService.deletePost(widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
        context.pop(); // Go back after deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
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
              _deletePost();
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCommentDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a Comment'),
          content: TextField(
            controller: _commentController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Your comment'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _commentController.clear(); // Clear text on cancel
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                _addComment();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Post not found.'));
          }

          final post = snapshot.data!;
          final isAuthor = post.author == currentUserId;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Post'),
              actions: isAuthor
                  ? [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          context.push('/community/group/${widget.groupId}/post/${post.id}/edit', extra: post);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _showDeleteConfirmationDialog,
                      ),
                    ]
                  : null,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _showAddCommentDialog,
              child: const Icon(Icons.add),
              tooltip: 'Add Comment',
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title ?? '[No Title]', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('By ${post.authorUsername ?? 'Anonymous'} on ${post.pubDate ?? 'Unknown Date'}'),
                  const SizedBox(height: 16),
                  Text(post.body ?? '[No Content]'),
                  const Divider(height: 32),
                  Text('Comments', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: post.comments.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final comment = post.comments[index];
                      return ListTile(
                        title: Text(comment.user ?? 'Anonymous'),
                        subtitle: Text(comment.content),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}