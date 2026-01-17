import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/exchange_service.dart';
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/models/comment.dart';
import 'package:transconnect/models/group.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/widgets/report_dialog.dart';
import 'package:transconnect/widgets/smart_link_body.dart';

enum ActivityFeedItemType { post, comment }

class ActivityFeedItem {
  final ActivityFeedItemType type;
  final String key;
  final DateTime timestamp;
  final Post? post;
  final Comment? comment;
  final Post? parentPost;
  final ExchangeMetadata? exchange;
  final int? groupId;

  const ActivityFeedItem({
    required this.type,
    required this.key,
    required this.timestamp,
    this.post,
    this.comment,
    this.parentPost,
    this.exchange,
    this.groupId,
  });
}

class SavedListingSearch {
  final String id;
  final String name;
  final int? groupId;
  final ExchangeKind? kind;
  final ExchangeCompensation? comp;

  const SavedListingSearch({
    required this.id,
    required this.name,
    required this.groupId,
    required this.kind,
    required this.comp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupId': groupId,
      'kind': kind == null
          ? null
          : (kind == ExchangeKind.offer ? 'offer' : 'request'),
      'comp': switch (comp) {
        null => null,
        ExchangeCompensation.free => 'free',
        ExchangeCompensation.trade => 'trade',
        ExchangeCompensation.paid => 'paid',
      },
    };
  }

  static SavedListingSearch? tryFromJson(Map<String, dynamic> json) {
    try {
      final id = (json['id'] ?? '').toString();
      final name = (json['name'] ?? '').toString();
      if (id.isEmpty || name.trim().isEmpty) return null;

      final groupIdRaw = json['groupId'];
      final int? groupId = groupIdRaw == null
          ? null
          : (groupIdRaw is int
                ? groupIdRaw
                : int.tryParse(groupIdRaw.toString()));

      final kindRaw = (json['kind'] ?? '').toString().toLowerCase().trim();
      final ExchangeKind? kind = kindRaw == 'offer'
          ? ExchangeKind.offer
          : (kindRaw == 'request' ? ExchangeKind.request : null);

      final compRaw = (json['comp'] ?? '').toString().toLowerCase().trim();
      final ExchangeCompensation? comp = compRaw == 'free'
          ? ExchangeCompensation.free
          : (compRaw == 'trade'
                ? ExchangeCompensation.trade
                : (compRaw == 'paid' ? ExchangeCompensation.paid : null));

      return SavedListingSearch(
        id: id,
        name: name,
        groupId: groupId,
        kind: kind,
        comp: comp,
      );
    } catch (_) {
      return null;
    }
  }
}

class ActivityFeedScreen extends StatefulWidget {
  final bool showAppBar;
  final Widget? header;

  const ActivityFeedScreen({super.key, this.showAppBar = true, this.header});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  late final CommunityService _communityService;
  late final AuthService _authService;

  bool _initialized = false;

  static const String _savedSearchesPrefKey = 'saved_listing_searches_v1';

  bool _loading = false;
  Object? _error;

  List<Group> _groups = const [];
  List<Post> _posts = const [];
  List<Comment> _comments = const [];

  int? _selectedGroupId;
  ExchangeKind? _selectedKind;
  ExchangeCompensation? _selectedComp;

  List<SavedListingSearch> _savedSearches = const [];
  bool _savedSearchesLoaded = false;

  final ImagePicker _commentImagePicker = ImagePicker();
  static const int _maxCommentImageBytes = 10 * 1024 * 1024;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _communityService = context.read<CommunityService>();
    _authService = context.read<AuthService>();

    _load();
    _loadSavedSearches();
  }

  Future<void> _loadSavedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedSearchesPrefKey);
      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _savedSearches = const [];
          _savedSearchesLoaded = true;
        });
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        if (!mounted) return;
        setState(() {
          _savedSearches = const [];
          _savedSearchesLoaded = true;
        });
        return;
      }

      final parsed = <SavedListingSearch>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final s = SavedListingSearch.tryFromJson(map);
          if (s != null) parsed.add(s);
        }
      }

      if (!mounted) return;
      setState(() {
        _savedSearches = parsed;
        _savedSearchesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedSearches = const [];
        _savedSearchesLoaded = true;
      });
    }
  }

  Future<void> _persistSavedSearches(List<SavedListingSearch> searches) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      searches.map((s) => s.toJson()).toList(growable: false),
    );
    await prefs.setString(_savedSearchesPrefKey, raw);
  }

  void _applySavedSearch(SavedListingSearch search) {
    final desiredGroupId = search.groupId;
    final effectiveGroupId =
        desiredGroupId != null && _groups.any((g) => g.id == desiredGroupId)
        ? desiredGroupId
        : null;

    setState(() {
      _selectedGroupId = effectiveGroupId;
      _selectedKind = search.kind;
      _selectedComp = search.comp;
    });
  }

  Future<void> _deleteSavedSearch(SavedListingSearch search) async {
    final updated = _savedSearches
        .where((s) => s.id != search.id)
        .toList(growable: false);
    setState(() {
      _savedSearches = updated;
    });
    await _persistSavedSearches(updated);
  }

  Future<void> _promptSaveSearch() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save search'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty || !mounted) return;

    final search = SavedListingSearch(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      groupId: _selectedGroupId,
      kind: _selectedKind,
      comp: _selectedComp,
    );

    final updated = [search, ..._savedSearches];
    setState(() {
      _savedSearches = updated;
      _savedSearchesLoaded = true;
    });

    try {
      await _persistSavedSearches(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "$trimmed"')));
      }
    } catch (_) {}
  }

  Widget _buildSavedSearches(BuildContext context) {
    if (!_savedSearchesLoaded || _savedSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved searches',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _savedSearches
                  .map(
                    (s) => InputChip(
                      label: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _applySavedSearch(s),
                      onDeleted: () => _deleteSavedSearch(s),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final groups = await _communityService.fetchGroups();
      final posts = await _communityService.fetchAllPosts();
      final comments = await _communityService.fetchAllComments();
      if (!mounted) return;

      setState(() {
        _groups = groups;
        _posts = posts;
        _comments = comments;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  DateTime _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _fullUrl(String path) {
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return ApiEndpoints.host + path;
    return '${ApiEndpoints.host}/media/$path';
  }

  List<ActivityFeedItem> _buildItems() {
    final items = <ActivityFeedItem>[];

    for (final p in _posts) {
      final dt = _parseDate(p.pubDate ?? p.updatedAt);
      final exchange = ExchangeMetadata.tryParse(p.feeling);

      if (exchange == null) continue;

      items.add(
        ActivityFeedItem(
          type: ActivityFeedItemType.post,
          key: 'p-${p.id}',
          timestamp: dt,
          post: p,
          parentPost: p,
          exchange: exchange,
          groupId: p.groupId,
        ),
      );
    }

    items.sort((a, b) {
      final d = b.timestamp.compareTo(a.timestamp);
      if (d != 0) return d;
      return a.key.compareTo(b.key);
    });

    return items;
  }

  List<ActivityFeedItem> _applyFilters(List<ActivityFeedItem> items) {
    final groupId = _selectedGroupId;
    final kind = _selectedKind;
    final comp = _selectedComp;

    return items
        .where((item) {
          if (groupId != null) {
            final effectiveGroupId = item.groupId ?? item.parentPost?.groupId;
            if (effectiveGroupId != groupId) return false;
          }

          if (kind != null || comp != null) {
            final meta = item.exchange;
            if (meta == null) return false;
            if (kind != null && meta.kind != kind) return false;
            if (comp != null && meta.compensation != comp) return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  String _groupName(int? groupId) {
    if (groupId == null) return 'Unknown';
    for (final g in _groups) {
      if (g.id == groupId) return g.name;
    }
    return 'Group $groupId';
  }

  Future<void> _openDetail(ActivityFeedItem item) async {
    if (item.type == ActivityFeedItemType.post) {
      final post = item.post;
      if (post == null) return;

      final exchange = item.exchange;
      if (exchange != null) {
        context.push('/exchange/post/${post.id}', extra: post);
        return;
      }

      final gid = post.groupId ?? 1;
      context.push('/community/group/$gid/post/${post.id}', extra: post);
      return;
    }

    final parent = item.parentPost;
    if (parent != null) {
      final gid = parent.groupId ?? 1;
      context.push('/community/group/$gid/post/${parent.id}', extra: parent);
      return;
    }

    final c = item.comment;
    if (c == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to open post ${c.postId}.')));
  }

  @override
  Widget build(BuildContext context) {
    final all = _buildItems();
    final filtered = _applyFilters(all);
    final effectiveSelectedGroupId =
        _groups.any((g) => g.id == _selectedGroupId) ? _selectedGroupId : null;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Listings'),
              actions: [
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/exchange/create');
          if (result == true && mounted) {
            _load();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.header != null) widget.header!,
                    if (widget.header != null) const SizedBox(height: 12),
                    _buildSavedSearches(context),
                    if (_savedSearchesLoaded && _savedSearches.isNotEmpty)
                      const SizedBox(height: 10),
                    _FeedFilters(
                      groups: _groups,
                      selectedGroupId: effectiveSelectedGroupId,
                      selectedKind: _selectedKind,
                      selectedComp: _selectedComp,
                      onChangedGroup: (v) =>
                          setState(() => _selectedGroupId = v),
                      onChangedKind: (v) => setState(() => _selectedKind = v),
                      onChangedComp: (v) => setState(() => _selectedComp = v),
                      onSaveSearch: _promptSaveSearch,
                      onReset: () {
                        setState(() {
                          _selectedGroupId = null;
                          _selectedKind = null;
                          _selectedComp = null;
                        });
                      },
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Failed to load listings: $_error',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (!_loading && _error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${filtered.length} items',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              );
            }

            final item = filtered[index - 1];

            if (item.type == ActivityFeedItemType.post) {
              final post = item.post;
              if (post == null) return const SizedBox.shrink();

              return _FeedPostCard(
                key: ValueKey(item.key),
                post: post,
                exchange: item.exchange,
                groupName: _groupName(post.groupId),
                fullUrl: _fullUrl,
                onOpenDetail: () => _openDetail(item),
                onComment: () => _showCommentComposer(post),
                onReport: () async {
                  final authorLabel = post.isAnonymous
                      ? 'Anonymous'
                      : (post.authorUsername ??
                            (post.author != null
                                ? 'User ${post.author}'
                                : 'Unknown user'));

                  await showReportDialog(
                    context: context,
                    baseRequest: ReportRequest(
                      type: ReportTargetType.post,
                      reason: '',
                      targetId: post.id,
                      targetUserId: post.author,
                      targetUsername: authorLabel,
                      details: '${post.title ?? ''}\n\n${post.body ?? ''}'
                          .trim(),
                    ),
                  );
                },
              );
            }

            final comment = item.comment;
            if (comment == null) return const SizedBox.shrink();

            return _FeedCommentCard(
              key: ValueKey(item.key),
              comment: comment,
              parentPost: item.parentPost,
              groupName: _groupName(item.groupId),
              onOpenDetail: () => _openDetail(item),
              onReply: () {
                final post = item.parentPost;
                if (post == null) {
                  _openDetail(item);
                  return;
                }
                _showCommentComposer(
                  post,
                  initialText: '@${comment.authorUsername} ',
                );
              },
              onReport: () async {
                await showReportDialog(
                  context: context,
                  baseRequest: ReportRequest(
                    type: ReportTargetType.comment,
                    reason: '',
                    targetId: comment.id,
                    targetUserId: comment.authorId,
                    targetUsername: comment.authorUsername,
                    details: comment.content,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCommentComposer(Post post, {String? initialText}) async {
    final controller = TextEditingController();
    if (initialText != null) {
      controller.text = initialText;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
    File? image;
    bool submitting = false;

    Future<void> pickImage(StateSetter setModalState) async {
      final picked = await _commentImagePicker.pickImage(
        source: ImageSource.gallery,
      );
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
      setModalState(() {
        image = file;
      });
    }

    Future<void> submit(StateSetter setModalState) async {
      final content = controller.text.trim();
      if (content.isEmpty) return;

      setModalState(() {
        submitting = true;
      });

      final now = DateTime.now();
      final me = _authService.currentUser;

      final optimistic = Comment(
        id: -now.microsecondsSinceEpoch,
        content: content,
        authorId: me?.id ?? 0,
        authorUsername: me?.username ?? 'You',
        authorProfilePic: me?.fullProfilePicUrl,
        authorIsStaff: me?.isStaff ?? false,
        pubDate: now.toIso8601String(),
        postId: post.id,
      );

      if (mounted) {
        setState(() {
          _comments = [optimistic, ..._comments];
        });
      }

      try {
        final created = image != null
            ? await _communityService.addCommentMultipart(
                postId: post.id,
                content: content,
                imageFilePath: image!.path,
              )
            : await _communityService.addComment(
                postId: post.id,
                content: content,
              );

        if (!mounted) return;

        setState(() {
          _comments = _comments
              .map((c) => c.id == optimistic.id ? created : c)
              .toList(growable: false);
        });

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _comments = _comments
              .where((c) => c.id != optimistic.id)
              .toList(growable: false);
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
        }
      } finally {
        setModalState(() {
          submitting = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomInsets + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Comment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (post.title ?? '').trim().isEmpty
                        ? '(Untitled post)'
                        : (post.title ?? '').trim(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: submitting
                            ? null
                            : () => pickImage(setModalState),
                        icon: const Icon(Icons.photo_camera_back_outlined),
                        label: const Text('Attach photo'),
                      ),
                      if (image != null) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  image!,
                                  fit: BoxFit.cover,
                                  width: 48,
                                  height: 48,
                                ),
                              ),
                              Positioned(
                                right: -6,
                                top: -10,
                                child: IconButton(
                                  iconSize: 18,
                                  onPressed: submitting
                                      ? null
                                      : () {
                                          setModalState(() {
                                            image = null;
                                          });
                                        },
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () => submit(setModalState),
                          child: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Post'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedFilters extends StatelessWidget {
  final List<Group> groups;
  final int? selectedGroupId;
  final ExchangeKind? selectedKind;
  final ExchangeCompensation? selectedComp;

  final ValueChanged<int?> onChangedGroup;
  final ValueChanged<ExchangeKind?> onChangedKind;
  final ValueChanged<ExchangeCompensation?> onChangedComp;
  final VoidCallback onSaveSearch;
  final VoidCallback onReset;

  const _FeedFilters({
    required this.groups,
    required this.selectedGroupId,
    required this.selectedKind,
    required this.selectedComp,
    required this.onChangedGroup,
    required this.onChangedKind,
    required this.onChangedComp,
    required this.onSaveSearch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey<int?>(selectedGroupId),
                    isExpanded: true,
                    initialValue: selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'All groups',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...groups.map(
                        (g) => DropdownMenuItem<int?>(
                          value: g.id,
                          child: Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onChangedGroup,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<ExchangeKind?>(
                    key: ValueKey<ExchangeKind?>(selectedKind),
                    isExpanded: true,
                    initialValue: selectedKind,
                    decoration: const InputDecoration(
                      labelText: 'Offer/Request',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<ExchangeKind?>(
                        value: null,
                        child: Text(
                          'Any',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<ExchangeKind?>(
                        value: ExchangeKind.offer,
                        child: Text(
                          'Offer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<ExchangeKind?>(
                        value: ExchangeKind.request,
                        child: Text(
                          'Request',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: onChangedKind,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<ExchangeCompensation?>(
                    key: ValueKey<ExchangeCompensation?>(selectedComp),
                    isExpanded: true,
                    initialValue: selectedComp,
                    decoration: const InputDecoration(
                      labelText: 'Comp',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<ExchangeCompensation?>(
                        value: null,
                        child: Text(
                          'Any',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<ExchangeCompensation?>(
                        value: ExchangeCompensation.free,
                        child: Text(
                          'Free',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<ExchangeCompensation?>(
                        value: ExchangeCompensation.trade,
                        child: Text(
                          'Trade',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<ExchangeCompensation?>(
                        value: ExchangeCompensation.paid,
                        child: Text(
                          'Paid',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: onChangedComp,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.clear),
                    label: const Text('Reset'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: onSaveSearch,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save search'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final Post post;
  final ExchangeMetadata? exchange;
  final String groupName;
  final String Function(String path) fullUrl;
  final VoidCallback onOpenDetail;
  final VoidCallback onComment;
  final Future<void> Function() onReport;

  const _FeedPostCard({
    super.key,
    required this.post,
    required this.exchange,
    required this.groupName,
    required this.fullUrl,
    required this.onOpenDetail,
    required this.onComment,
    required this.onReport,
  });

  DateTime _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = _parseDate(post.pubDate ?? post.updatedAt);

    final displayAuthor = post.isAnonymous
        ? 'Anonymous'
        : (post.authorUsername ??
              (post.author != null ? 'User ${post.author}' : 'Unknown user'));

    final exchangeSubtitleParts = <String>[];
    if (exchange != null) {
      exchangeSubtitleParts.add(
        exchange!.kind == ExchangeKind.offer ? 'Offer' : 'Request',
      );
      exchangeSubtitleParts.add(switch (exchange!.compensation) {
        ExchangeCompensation.free => 'Free',
        ExchangeCompensation.trade => 'Trade',
        ExchangeCompensation.paid => 'Paid',
      });
      if (exchange!.price != null && exchange!.price!.trim().isNotEmpty) {
        exchangeSubtitleParts.add(exchange!.price!.trim());
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayProfilePic(
                    radius: 18,
                    imageUrl: post.authorProfilePic,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayAuthor,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$groupName · ${timeago.format(dt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (exchangeSubtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: exchangeSubtitleParts
                                .map(
                                  (t) => Chip(
                                    label: Text(t),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async => onReport(),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                (post.title ?? '').trim().isEmpty
                    ? '(Untitled)'
                    : (post.title ?? '').trim(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SmartLinkBody(text: post.body),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.images
                      .map(
                        (u) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            fullUrl(u),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onComment,
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: const Text('Comment'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCommentCard extends StatelessWidget {
  final Comment comment;
  final Post? parentPost;
  final String groupName;
  final VoidCallback onOpenDetail;
  final VoidCallback onReply;
  final Future<void> Function() onReport;

  const _FeedCommentCard({
    super.key,
    required this.comment,
    required this.parentPost,
    required this.groupName,
    required this.onOpenDetail,
    required this.onReply,
    required this.onReport,
  });

  DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = _parseDate(comment.pubDate);

    final title = (parentPost?.title ?? '').trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DisplayProfilePic(
                    radius: 18,
                    imageUrl: comment.authorProfilePic,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.authorUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$groupName · ${timeago.format(dt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'On: $title',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async => onReport(),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SmartLinkBody(text: comment.content),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply),
                    label: const Text('Reply'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open post'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
