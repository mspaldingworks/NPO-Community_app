import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/constants/api_endpoints.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/features/group_console/group_console_screen.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';
import 'package:npo_community/features/group_console/group_highlights.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/models/group.dart';
import 'package:npo_community/models/post.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/widgets/report_dialog.dart';
import 'package:npo_community/widgets/smart_link_body.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

String _fullUrl(String path) {
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return ApiEndpoints.host + path;
  return '${ApiEndpoints.host}/media/$path';
}

DateTime? _published(Post post) {
  final raw = post.pubDate ?? post.updatedAt;
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

/// A group's posts, newest first, with pull-to-refresh and a compose button.
///
/// With [live] on, the feed polls for posts newer than the newest one it
/// has every [pollInterval] while the app is in the foreground, and does a
/// full refresh when the app comes back. Hosts give it an AppBar; the feed
/// brings its own Scaffold so the compose button sits where it always has.
class GroupFeed extends StatefulWidget {
  const GroupFeed({
    super.key,
    required this.groupId,
    required this.groupName,
    this.service,
    this.console,
    this.userDirectory,
    this.currentUserId,
    this.live = false,
    this.pollInterval = const Duration(seconds: 20),
    this.showGroupImage = true,
    this.canManage = false,
  });

  final int groupId;
  final String groupName;

  /// Injected in tests.
  final CommunityService? service;

  /// The group's console API, for the announcements, events and polls shown
  /// above the posts. Injected in tests.
  final GroupConsoleService? console;

  /// Shows sample markers and the close-poll action.
  final bool canManage;

  /// Source of member avatars and flair; defaults to the member list.
  final Future<List<User>> Function()? userDirectory;

  /// Whose posts get Edit/Delete; defaults to the signed-in member.
  final int? currentUserId;
  final bool live;
  final Duration pollInterval;
  final bool showGroupImage;

  @override
  State<GroupFeed> createState() => _GroupFeedState();
}

class _GroupFeedState extends State<GroupFeed> with WidgetsBindingObserver {
  late final CommunityService _service = widget.service ?? CommunityService();
  late final GroupConsoleService _console =
      widget.console ?? GroupConsoleService(widget.groupId);
  List<Post>? _posts;
  List<GroupAnnouncement> _announcements = const [];
  List<CommunityEvent> _groupEvents = const [];
  List<GroupPoll> _polls = const [];
  Object? _error;
  Map<String, String?> _picByUsername = {};
  Map<String, String?> _flairByUsername = {};
  Future<Group>? _group;
  Timer? _timer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showGroupImage) _group = _service.fetchGroupById(widget.groupId);
    _reload();
    _loadDirectory();
    _startPolling();
  }

  /// Announcements, events and polls each load on their own, so one failing
  /// (or an older server) only hides that section.
  Future<void> _loadHighlights() async {
    await Future.wait([
      _console.fetchAnnouncements().then(
        (rows) => mounted ? setState(() => _announcements = rows) : null,
        onError: (Object _) {},
      ),
      _console.fetchEvents().then(
        (rows) => mounted ? setState(() => _groupEvents = rows) : null,
        onError: (Object _) {},
      ),
      _console.fetchPolls().then(
        (rows) => mounted ? setState(() => _polls = rows) : null,
        onError: (Object _) {},
      ),
    ]);
  }

  void _openConsole() {
    if (GoRouter.maybeOf(context) != null) {
      context.push(
        '/community/group/${widget.groupId}/console',
        extra: widget.groupName,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupConsoleScreen(
            groupId: widget.groupId,
            groupName: widget.groupName,
            service: _console,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.live) return;
    if (state == AppLifecycleState.resumed) {
      _reload();
      _startPolling();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startPolling() {
    if (!widget.live) return;
    _timer?.cancel();
    _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  List<Post> _sorted(List<Post> posts) {
    final sorted = [...posts];
    sorted.sort((a, b) {
      final da = _published(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _published(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return sorted;
  }

  Future<void> _reload() async {
    final highlights = _loadHighlights();
    try {
      final posts = await _service.fetchPostsForGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _posts = _sorted(posts);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _posts ??= const [];
      });
    }
    await highlights;
  }

  /// Asks only for what is newer than the newest post shown and slots it
  /// in at the top. Edits and deletions wait for a full refresh.
  Future<void> _poll() async {
    if (_polling || !mounted) return;
    final current = _posts;
    if (current == null) return;
    _polling = true;
    try {
      DateTime? newest;
      for (final post in current) {
        final when = _published(post);
        if (when != null && (newest == null || when.isAfter(newest))) {
          newest = when;
        }
      }
      final fresh = await _service.fetchPostsForGroup(
        widget.groupId,
        since: newest,
      );
      if (!mounted || fresh.isEmpty) return;
      final known = {for (final p in current) p.id};
      final additions = fresh.where((p) => !known.contains(p.id)).toList();
      if (additions.isEmpty) return;
      setState(() {
        _posts = _sorted([...additions, ...current]);
      });
    } catch (_) {
      // A missed poll is harmless; the next one or a pull-to-refresh catches up.
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadDirectory() async {
    try {
      final users = await (widget.userDirectory ?? AuthService().getAllUsers)();
      if (!mounted) return;
      setState(() {
        _picByUsername = {
          for (final u in users) u.username: u.fullProfilePicUrl,
        };
        _flairByUsername = {for (final u in users) u.username: u.flair};
      });
    } catch (_) {
      // Avatars stay as placeholders.
    }
  }

  int? _currentUserId(BuildContext context) {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Provider.of<AuthService>(context, listen: false).currentUser?.id;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _delete(int postId) async {
    try {
      await _service.deletePost(postId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }

  void _confirmDelete(int postId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _delete(postId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.tertiary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId(context);
    final posts = _posts;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: posts == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                key: const Key('group-feed'),
                itemCount: posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GroupImage(future: _group),
                        GroupHighlights(
                          announcements: _announcements,
                          events: _groupEvents,
                          polls: _polls,
                          api: _console,
                          canManage: widget.canManage,
                          onChanged: _reload,
                          onOpenConsole: _openConsole,
                        ),
                        if (_error != null && posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Error: $_error',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else if (posts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Text(
                                  'No posts yet.',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Be the first to post!',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  final post = posts[index - 1];
                  return _PostCard(
                    post: post,
                    groupId: widget.groupId,
                    isOwner:
                        currentUserId != null && currentUserId == post.author,
                    picUrl:
                        post.authorProfilePic ??
                        _picByUsername[post.authorUsername ?? ''],
                    flair: _flairByUsername[post.authorUsername ?? ''],
                    onDelete: () => _confirmDelete(post.id),
                    onChanged: _reload,
                  );
                },
              ),
      ),
      floatingActionButton: TourAnchor(
        name: 'Add Post',
        child: FloatingActionButton(
          onPressed: () async {
            final result = await context.push(
              '/community/group/${widget.groupId}/create-post',
            );
            if (result == true && mounted) await _reload();
          },
          tooltip: 'Add Post',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _GroupImage extends StatelessWidget {
  const _GroupImage({required this.future});

  final Future<Group>? future;

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<Group>(
      future: future,
      builder: (context, snapshot) {
        final imgUrl = snapshot.hasData ? snapshot.data!.fullImageUrl : null;
        if (imgUrl == null) return const SizedBox.shrink();
        final token = SharedPreferencesService().getData('user_token');
        final headers = token != null
            ? {'Authorization': 'Token $token'}
            : null;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imgUrl,
              httpHeaders: headers,
              imageBuilder: (context, imageProvider) => SizedBox(
                height: 180,
                width: double.infinity,
                child: Image(image: imageProvider, fit: BoxFit.cover),
              ),
              placeholder: (context, url) => Container(
                height: 180,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.groupId,
    required this.isOwner,
    required this.picUrl,
    required this.flair,
    required this.onDelete,
    required this.onChanged,
  });

  final Post post;
  final int groupId;
  final bool isOwner;
  final String? picUrl;
  final String? flair;
  final VoidCallback onDelete;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final postDate = _published(post) ?? DateTime.now();
    String editedLabel = '';
    if (post.isEdited && post.updatedAt != null) {
      final editedDate = DateTime.tryParse(post.updatedAt!)?.toLocal();
      editedLabel = editedDate == null
          ? ' · Edited'
          : ' · Edited ${timeago.format(editedDate)}';
    }
    final displayAuthor = post.isAnonymous
        ? 'Anonymous'
        : (post.authorUsername ?? 'Unknown user');
    final authorIsPrivate = FlairUtils.isProfilePrivate(flair);
    final String? pronounsDisplay = post.isAnonymous || authorIsPrivate
        ? null
        : (FlairUtils.extractPronouns(flair) ?? '')
              .split(RegExp(r'[\n,]'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .join(' • ');

    void openAuthor() {
      if (post.isAnonymous || post.author == null) return;
      context.push('/users/${post.author}');
    }

    return Card(
      key: Key('post-${post.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => GoRouter.of(
          context,
        ).push('/community/group/$groupId/post/${post.id}', extra: post),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: openAuthor,
                    child: DisplayProfilePic(radius: 20, imageUrl: picUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: openAuthor,
                              child: Text(
                                displayAuthor,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (post.authorIsStaff)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Chip(
                                  avatar: Icon(
                                    Icons.shield,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: AppColors.primary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                        if (pronounsDisplay != null &&
                            pronounsDisplay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              pronounsDisplay,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        Text(
                          'By $displayAuthor · ${timeago.format(postDate)}$editedLabel',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
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
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'report') {
                        await showReportDialog(
                          context: context,
                          baseRequest: ReportRequest(
                            type: ReportTargetType.post,
                            reason: '',
                            targetId: post.id,
                            targetUsername: displayAuthor,
                            details: '${post.title ?? ''}\n\n${post.body ?? ''}'
                                .trim(),
                          ),
                        );
                        return;
                      }
                      if (!isOwner) return;
                      if (value == 'delete') {
                        onDelete();
                      } else if (value == 'edit') {
                        final result = await context.push(
                          '/community/group/$groupId/post/${post.id}/edit',
                          extra: post,
                        );
                        if (result == true) await onChanged();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Text('Report'),
                      ),
                      if (isOwner) ...const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SmartLinkBody(text: post.body),
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
                              targetUsername: displayAuthor,
                              targetUrl: src,
                              details: 'Post photo',
                            ),
                          );
                        },
                        child: Image.network(
                          src,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
