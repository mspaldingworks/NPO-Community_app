import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/features/community/group_feed.dart';
import 'package:npo_community/pages/community/post_list_screen.dart';
import 'package:npo_community/models/group.dart';
import 'package:npo_community/models/user.dart';

/// The Community tab: the statewide group's feed, live, with the other
/// groups one tap away in a chip row above it.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.service,
    this.userDirectory,
    this.currentUserId,
    this.pollInterval = const Duration(seconds: 20),
  });

  /// Injected in tests.
  final CommunityService? service;
  final Future<List<User>> Function()? userDirectory;
  final int? currentUserId;
  final Duration pollInterval;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final CommunityService _service = widget.service ?? CommunityService();
  late Future<List<Group>> _groups = _service.fetchGroups();
  late Future<List<ClassGroup>> _classes = _service.fetchClasses();

  Future<void> _reloadGroups() async {
    final groups = _service.fetchGroups();
    final classes = _service.fetchClasses();
    setState(() {
      _groups = groups;
      _classes = classes;
    });
    await groups;
  }

  /// Opens a class chat: by route under the app's router, else by a plain
  /// push (demo builds and tests).
  void _openClass(ClassGroup entry) {
    if (!entry.isMember) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'The ${entry.group.name} chat is for members of that class.',
          ),
        ),
      );
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push(
        '/community/group/${entry.group.id}',
        extra: entry.group.name,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostListScreen(
            groupId: entry.group.id,
            groupName: entry.group.name,
            service: _service,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Group>>(
      future: _groups,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Community')),
            body: snapshot.hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _reloadGroups,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          );
        }
        final groups = snapshot.data!;
        final statewide = groups.where((g) => g.isStatewide).firstOrNull;
        final others = groups
            .where((g) => !g.isStatewide && !g.isRegional && !g.isCohort)
            .toList();
        if (statewide == null) {
          return _GroupsDirectory(groups: groups);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(statewide.name),
            actions: [
              IconButton(
                tooltip: 'Group info, events and polls',
                icon: const Icon(Icons.info_outline),
                onPressed: () => context.push(
                  '/community/group/${statewide.id}/console',
                  extra: statewide.name,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _GroupSwitcher(others: others),
              _ClassPicker(future: _classes, onOpen: _openClass),
              const Divider(height: 1),
              Expanded(
                child: GroupFeed(
                  key: ValueKey('statewide-feed-${statewide.id}'),
                  groupId: statewide.id,
                  groupName: statewide.name,
                  service: _service,
                  userDirectory: widget.userDirectory,
                  currentUserId: widget.currentUserId,
                  live: true,
                  pollInterval: widget.pollInterval,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Regional groups, class chats and any other groups, as chips.
class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({required this.others});

  final List<Group> others;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ActionChip(
            key: const Key('chip-regional'),
            avatar: const Icon(Icons.hub_outlined, size: 18),
            label: const Text('Regional groups'),
            onPressed: () => context.push('/community/regional'),
          ),
          for (final group in others) ...[
            const SizedBox(width: 8),
            ActionChip(
              key: Key('chip-group-${group.id}'),
              avatar: Icon(
                group.isCandidates ? Icons.how_to_vote_outlined : Icons.groups,
                size: 18,
              ),
              label: Text(group.name),
              onPressed: () => context.push(
                '/community/group/${group.id}',
                extra: group.name,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every year Emerge Kentucky had a class, as a dropdown. Picking a year
/// opens that class's chat; years the member isn't in are marked.
class _ClassPicker extends StatelessWidget {
  const _ClassPicker({required this.future, required this.onOpen});

  final Future<List<ClassGroup>> future;
  final void Function(ClassGroup entry) onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClassGroup>>(
      future: future,
      builder: (context, snapshot) {
        final classes = snapshot.data ?? const <ClassGroup>[];
        if (classes.isEmpty) return const SizedBox.shrink();
        final own = classes.where((c) => c.isOwnClass).firstOrNull;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: DropdownMenu<int>(
            key: const Key('class-picker'),
            width: MediaQuery.sizeOf(context).width - 24,
            leadingIcon: const Icon(Icons.school_outlined),
            label: const Text('Class chats'),
            hintText: 'Pick a class year',
            initialSelection: own?.group.id,
            requestFocusOnTap: false,
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            dropdownMenuEntries: [
              for (final entry in classes)
                DropdownMenuEntry<int>(
                  value: entry.group.id,
                  label: entry.group.name,
                  leadingIcon: Icon(
                    entry.isMember ? Icons.forum_outlined : Icons.lock_outline,
                    size: 18,
                  ),
                  trailingIcon: entry.isOwnClass
                      ? const Text('yours')
                      : entry.memberCount > 0
                      ? Text('${entry.memberCount}')
                      : null,
                ),
            ],
            onSelected: (id) {
              if (id == null) return;
              final entry = classes.firstWhere((c) => c.group.id == id);
              onOpen(entry);
            },
          ),
        );
      },
    );
  }
}

/// Fallback when the member has no statewide group: a plain list.
class _GroupsDirectory extends StatelessWidget {
  const _GroupsDirectory({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Regional groups'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/community/regional'),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Class chats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/community/classes'),
          ),
          for (final group in groups.where((g) => !g.isRegional && !g.isCohort))
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(group.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/community/group/${group.id}',
                extra: group.name,
              ),
            ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No groups yet.', textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
