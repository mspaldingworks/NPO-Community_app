import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';

class RegionalChatsScreen extends StatefulWidget {
  const RegionalChatsScreen({super.key});

  @override
  State<RegionalChatsScreen> createState() => _RegionalChatsScreenState();
}

class _RegionalChatsScreenState extends State<RegionalChatsScreen> {
  late final CommunityService _communityService;
  late Future<List<Group>> _regionalGroupsFuture;

  bool _isRegionGroup(Group g) {
    final n = g.name.trim().toLowerCase();
    return n == 'kentuckiana regional' ||
        n == 'greater lexington' ||
        n == 'central ky' ||
        n == 'eastern ky' ||
        n == 'western ky';
  }

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _regionalGroupsFuture = _loadRegionalGroups();
  }

  Future<List<Group>> _loadRegionalGroups() async {
    final groups = await _communityService.fetchGroups();
    return groups.where(_isRegionGroup).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Chats'),
      ),
      body: FutureBuilder<List<Group>>(
        future: _regionalGroupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final groups = snapshot.data ?? const <Group>[];
          if (groups.isEmpty) {
            return const Center(child: Text('No regional groups found.'));
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(group.name),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    GoRouter.of(context)
                        .push('/community/group/${group.id}', extra: group.name);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
