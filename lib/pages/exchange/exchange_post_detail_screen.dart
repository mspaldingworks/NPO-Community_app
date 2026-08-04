import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/constants/api_endpoints.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/exchange_service.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/models/post.dart';
import 'package:npo_community/widgets/report_dialog.dart';
import 'package:npo_community/widgets/smart_link_body.dart';

class ExchangePostDetailScreen extends StatefulWidget {
  final int postId;
  final Post? initialPost;

  const ExchangePostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<ExchangePostDetailScreen> createState() =>
      _ExchangePostDetailScreenState();
}

class _ExchangePostDetailScreenState extends State<ExchangePostDetailScreen> {
  final AuthService _authService = AuthService();

  late Future<Post> _postFuture;
  Map<String, int> _userIdByUsername = {};

  late final CommunityService _communityService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _communityService = context.read<CommunityService>();
    _postFuture = _loadPost();
    _loadUserLookup();
  }

  Future<Post> _loadPost() async {
    if (widget.initialPost != null) {
      return widget.initialPost!;
    }
    return _communityService.fetchPostById(widget.postId);
  }

  Future<void> _loadUserLookup() async {
    final users = await _authService.getAllUsers();
    if (!mounted) return;

    setState(() {
      _userIdByUsername = {for (final u in users) u.username: u.id};
    });
  }

  String _fullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiEndpoints.host}$url';
    return '${ApiEndpoints.host}/$url';
  }

  int? _resolveAuthorId(Post post) {
    if (post.isAnonymous) return null;
    if (post.author != null) return post.author;
    final username = post.authorUsername;
    if (username == null || username.isEmpty) return null;
    return _userIdByUsername[username];
  }

  Future<void> _report(Post post) async {
    final authorLabel = post.isAnonymous
        ? 'Anonymous'
        : (post.authorUsername ??
              (post.author != null ? 'User ${post.author}' : 'Unknown user'));

    await showReportDialog(
      context: context,
      baseRequest: ReportRequest(
        type: ReportTargetType.post,
        reason: '',
        targetId: post.id,
        targetUserId: post.author,
        targetUsername: authorLabel,
        details: '${post.title ?? ''}\n\n${post.body ?? ''}'.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load listing: ${snapshot.error}'),
            );
          }

          final post = snapshot.data;
          if (post == null) {
            return const Center(child: Text('Listing not found.'));
          }

          final meta = ExchangeMetadata.tryParse(post.feeling);
          final title = (post.title ?? '').trim();
          final body = (post.body ?? '').trim();

          final authorLabel = post.isAnonymous
              ? 'Anonymous'
              : (post.authorUsername ??
                    (post.author != null
                        ? 'User ${post.author}'
                        : 'Unknown user'));

          final subtitleParts = <String>[];
          if (meta != null) {
            subtitleParts.add(
              meta.kind == ExchangeKind.offer ? 'Offer' : 'Request',
            );
            subtitleParts.add(switch (meta.compensation) {
              ExchangeCompensation.free => 'Free',
              ExchangeCompensation.trade => 'Trade',
              ExchangeCompensation.paid => 'Paid',
            });
            if (meta.price != null && meta.price!.trim().isNotEmpty) {
              subtitleParts.add(meta.price!.trim());
            }
          }

          final canContact = _resolveAuthorId(post) != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.emojis.isNotEmpty
                        ? post.emojis.first
                        : (post.emoji ?? '💼'),
                    style: const TextStyle(fontSize: 44),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? '(Untitled)' : title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitleParts.join(' · '),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'By $authorLabel',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'report') {
                        await _report(post);
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Text('Report'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (meta != null && meta.tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: meta.tags.map((t) => Chip(label: Text(t))).toList(),
                ),
              if (meta != null && meta.tags.isNotEmpty)
                const SizedBox(height: 16),
              SmartLinkBody(text: body),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.images.map((u) {
                    final src = _fullUrl(u);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        src,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: !canContact
                    ? null
                    : () {
                        final userId = _resolveAuthorId(post);
                        if (userId == null) return;
                        context.push('/chat/$userId');
                      },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contact'),
              ),
            ],
          );
        },
      ),
    );
  }
}
