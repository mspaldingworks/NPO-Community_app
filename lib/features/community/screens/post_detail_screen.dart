import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final CommunityService _communityService = CommunityService();
  final DateFormat _editedDateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    setState(() {
      _postFuture = _communityService.fetchPostById(widget.postId);
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      await _communityService.addComment(
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
    try {
      await _communityService.deletePost(widget.postId);
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

  Future<void> _deleteComment(int commentId) async {
    try {
      await _communityService.deleteComment(commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
        _loadPost(); // Refresh post
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog({required bool isPost}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPost ? 'Delete Post?' : 'Delete Comment?'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isPost) {
                _deletePost();
              }
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.tertiary),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatRelative(String? raw, {String fallback = 'Unknown date'}) {
    final parsed = _parseDate(raw);
    if (parsed == null) {
      return fallback;
    }
    return timeago.format(parsed);
  }

  String? _formatEditedLabel(String? raw) {
    final parsed = _parseDate(raw);
    if (parsed == null) {
      return null;
    }
    return _editedDateFormat.format(parsed);
  }

  void _showDeleteCommentConfirmationDialog(int commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteComment(commentId);
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.tertiary),
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(Comment comment) {
    final editController = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateComment(comment.id, editController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateComment(int commentId, String content) async {
    try {
      await _communityService.updateComment(commentId, {'content': content});
      _loadPost();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update comment: $e')),
        );
      }
    }
  }

  void _showAddCommentDialog() {
    _commentController.clear();
    showDialog<void>(
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
              onPressed: () => Navigator.of(context).pop(),
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
        actions: [
          FutureBuilder<Post>(
            future: _postFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || currentUserId == null) return const SizedBox.shrink();
              final post = snapshot.data!;
              if (post.author == currentUserId) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        context.push('/community/group/${widget.groupId}/post/${post.id}/edit', extra: post);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmationDialog(isPost: true),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCommentDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Comment',
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title ?? '[No Title]', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'By ${post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user')} · ${_formatRelative(post.pubDate)}',
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
                  ],
                ),
                if (post.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Edited ${_formatEditedLabel(post.updatedAt) ?? ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
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
                    final isCommentAuthor = comment.authorId == currentUserId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DisplayProfilePic(radius: 20, imageUrl: comment.authorProfilePic),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      comment.authorUsername,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (comment.authorIsStaff)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Chip(
                                          avatar: const Icon(Icons.shield, size: 12, color: Colors.white),
                                          label: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.white)),
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  _formatRelative(comment.pubDate),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                if (comment.isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Edited ${_formatEditedLabel(comment.updatedAt) ?? ''}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(comment.content),
                                if (isCommentAuthor)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _showEditCommentDialog(comment),
                                          child: const Text('Edit'),
                                        ),
                                        TextButton(
                                          onPressed: () => _showDeleteCommentConfirmationDialog(comment.id),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}