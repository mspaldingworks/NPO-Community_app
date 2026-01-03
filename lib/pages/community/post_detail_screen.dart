import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/widgets/report_dialog.dart';
import 'package:transconnect/core/utils/flair_utils.dart';
import 'package:transconnect/widgets/link_preview_card.dart';

class PostDetailScreen extends StatefulWidget {
  final int groupId;
  final int postId;

  const PostDetailScreen({super.key, required this.groupId, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

String _fullUrl(String path) {
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return ApiEndpoints.host + path;
  return ApiEndpoints.host + '/media/' + path;
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post> _postFuture;
  final TextEditingController _commentController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  final DateFormat _editedDateFormat = DateFormat('MMM d, yyyy h:mm a');
  final AuthService _authService = AuthService();
  Map<String, String?> _userPicByUsername = {};
  Map<String, String?> _userFlairByUsername = {};
  final ImagePicker _commentImagePicker = ImagePicker();
  File? _commentImage;
  static const int _maxCommentImageBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadUserPicMap();
  }

  void _loadPost() {
    setState(() {
      _postFuture = _communityService.fetchPostById(widget.postId);
    });
  }

  Future<void> _loadUserPicMap() async {
    try {
      final users = await _authService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _userPicByUsername = {for (final u in users) u.username: u.fullProfilePicUrl};
        _userFlairByUsername = {for (final u in users) u.username: u.flair};
      });
    } catch (_) {
      // Ignore; avatars will stay placeholders
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      if (_commentImage != null) {
        await _communityService.addCommentMultipart(
          postId: widget.postId,
          content: _commentController.text,
          imageFilePath: _commentImage!.path,
        );
      } else {
        await _communityService.addComment(
          postId: widget.postId,
          content: _commentController.text,
        );
      }
      _commentController.clear();
      _commentImage = null;
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
    _commentImage = null;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a Comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _commentController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Your comment'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _commentImagePicker.pickImage(source: ImageSource.gallery);
                      if (picked == null) return;
                      final file = File(picked.path);
                      final bytes = await file.length();
                      if (bytes > _maxCommentImageBytes) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image too large. Max 10MB.')),
                          );
                        }
                        return;
                      }
                      setState(() {
                        _commentImage = file;
                      });
                    },
                    icon: const Icon(Icons.photo_camera_back_outlined),
                    label: const Text('Attach photo'),
                  ),
                  if (_commentImage != null) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(_commentImage!, fit: BoxFit.cover, width: 48, height: 48),
                          ),
                          Positioned(
                            right: -6,
                            top: -10,
                            child: IconButton(
                              iconSize: 18,
                              onPressed: () { setState(() { _commentImage = null; }); },
                              icon: const Icon(Icons.close),
                            ),
                          )
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ],
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
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () async {
                        await showReportDialog(
                          context: context,
                          baseRequest: ReportRequest(
                            type: ReportTargetType.post,
                            reason: '',
                            targetId: post.id,
                            targetUsername: post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user'),
                            details: '${post.title ?? ''}\n\n${post.body ?? ''}'.trim(),
                          ),
                        );
                      },
                    ),
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
              return IconButton(
                icon: const Icon(Icons.flag_outlined),
                onPressed: () async {
                  await showReportDialog(
                    context: context,
                    baseRequest: ReportRequest(
                      type: ReportTargetType.post,
                      reason: '',
                      targetId: post.id,
                      targetUsername: post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user'),
                      details: '${post.title ?? ''}\n\n${post.body ?? ''}'.trim(),
                    ),
                  );
                },
              );
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
          final authorFlair = _userFlairByUsername[post.authorUsername ?? ''];
          final authorIsPrivate = FlairUtils.isProfilePrivate(authorFlair);

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
                    GestureDetector(
                      onTap: () {
                        if (post.isAnonymous) return;
                        if (post.author == null) return;
                        context.push('/users/${post.author}');
                      },
                      child: DisplayProfilePic(
                        radius: 20,
                        imageUrl: post.authorProfilePic ?? _userPicByUsername[post.authorUsername ?? ''],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final String? pronounsDisplay = post.isAnonymous || authorIsPrivate
                              ? null
                              : (FlairUtils.extractPronouns(authorFlair) ?? '')
                                  .split(RegExp(r'[\n,]'))
                                  .map((p) => p.trim())
                                  .where((p) => p.isNotEmpty)
                                  .join(' • ');

                          return GestureDetector(
                            onTap: () {
                              if (post.isAnonymous) return;
                              if (post.author == null) return;
                              context.push('/users/${post.author}');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'By ${post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user')} · ${_formatRelative(post.pubDate)}',
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
                          );
                        },
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
                LinkPreviewCard(urlOrText: post.body),
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.images.map((u) {
                      final src = _fullUrl(u);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onLongPress: () async {
                            await showReportDialog(
                              context: context,
                              baseRequest: ReportRequest(
                                type: ReportTargetType.photo,
                                reason: '',
                                targetId: post.id,
                                targetUsername: post.isAnonymous ? 'Anonymous' : (post.authorUsername ?? 'Unknown user'),
                                targetUrl: src,
                                details: 'Post photo',
                              ),
                            );
                          },
                          child: Image.network(
                            src,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                    final commentFlair = _userFlairByUsername[comment.authorUsername];
                    final commentIsPrivate = FlairUtils.isProfilePrivate(commentFlair);
                    final String? pronounsDisplay = commentIsPrivate
                        ? null
                        : (FlairUtils.extractPronouns(commentFlair) ?? '')
                            .split(RegExp(r'[\n,]'))
                            .map((p) => p.trim())
                            .where((p) => p.isNotEmpty)
                            .join(' • ');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (comment.authorId <= 0) return;
                              context.push('/users/${comment.authorId}');
                            },
                            child: DisplayProfilePic(
                              radius: 20,
                              imageUrl: comment.authorProfilePic ?? _userPicByUsername[comment.authorUsername],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (comment.authorId <= 0) return;
                                        context.push('/users/${comment.authorId}');
                                      },
                                      child: Text(
                                        comment.authorUsername,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
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
                                if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      pronounsDisplay,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
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
                                LinkPreviewCard(urlOrText: comment.content),
                                TextButton(
                                  onPressed: () async {
                                    await showReportDialog(
                                      context: context,
                                      baseRequest: ReportRequest(
                                        type: ReportTargetType.comment,
                                        reason: '',
                                        targetId: comment.id,
                                        targetUsername: comment.authorUsername,
                                        details: comment.content,
                                      ),
                                    );
                                  },
                                  child: const Text('Report'),
                                ),
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