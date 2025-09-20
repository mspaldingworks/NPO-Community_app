import 'package:flutter/material.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/features/community/services/community_service.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late List<Comment> _comments;
  late final CommunityService _communityService;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.post.comments); // Create a mutable copy
    final authService = Provider.of<AuthService>(context, listen: false);
    _communityService = CommunityService(authService: authService);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
            decoration: const InputDecoration(hintText: 'Write your comment...'),
            maxLines: null, // Allows for multiline input
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _commentController.clear();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                if (_commentController.text.isNotEmpty) {
                  try {
                    final newComment = await _communityService.addComment(
                      postId: widget.post.id,
                      content: _commentController.text,
                    );
                    setState(() {
                      _comments.add(newComment);
                    });
                    _commentController.clear();
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add comment: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title ?? 'Post Details'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCommentDialog,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.post.title ?? '[No Title]',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8.0),
            Text(
              'By ${widget.post.authorUsername ?? 'Anonymous'} on ${widget.post.pubDate ?? 'Unknown Date'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16.0),
            Text(widget.post.body ?? '[No Content]'),
            const SizedBox(height: 24.0),
            const Divider(),
            Text(
              'Comments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _comments.isEmpty
                ? const Center(child: Text('Add the first comment.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          title: Text(comment.user?.toString() ?? 'Anonymous'),
                          subtitle: Text(comment.content),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
