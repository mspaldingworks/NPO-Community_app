import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/group.dart';

class RegionalChatsScreen extends StatefulWidget {
  const RegionalChatsScreen({super.key});

  @override
  State<RegionalChatsScreen> createState() => _RegionalChatsScreenState();
}

class _RegionalChatsScreenState extends State<RegionalChatsScreen> {
  late final Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = CommunityService().fetchGroups();
  }

  bool _isChapterSpace(Group group) {
    final name = group.name.trim().toLowerCase();
    return name.contains('chapter') || name.contains('region');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chapter Spaces')),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Chapter spaces are unavailable.'));
          }

          final groups = (snapshot.data ?? []).where(_isChapterSpace).toList();
          if (groups.isEmpty) {
            return const Center(
              child: Text('No chapter spaces are available.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: Text(group.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/community/group/${group.id}',
                  extra: group.name,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
