import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/models/group.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<Group>> _groupsFuture;
  late final CommunityService _communityService;

  @override
  void initState() {
    super.initState();
    _communityService = CommunityService();
    _groupsFuture = _communityService.fetchGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Groups'),
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No groups found.'));
          } else {
            final groups = snapshot.data!;
            bool isRegion(Group g) {
              final n = g.name.trim().toLowerCase();
              return n == 'kentuckiana regional'
                  || n == 'greater lexington'
                  || n == 'central ky'
                  || n == 'eastern ky'
                  || n == 'western ky'
                  || n == 'south-central ky'
                  || n == 'south central ky'
                  || n == 'northern ky'
                  || n == 'northern kentucky';
            }

            final regionGroups = groups.where(isRegion).toList();
            final otherGroups = groups.where((g) => !isRegion(g)).toList();

            final totalItems = otherGroups.length + (regionGroups.isNotEmpty ? 1 : 0);
            return ListView.builder(
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (regionGroups.isNotEmpty && index == 0) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: const Text('Regional Chats'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        GoRouter.of(context).push('/community/regional');
                      },
                    ),
                  );
                }

                final adjustedIndex = regionGroups.isNotEmpty ? index - 1 : index;
                final group = otherGroups[adjustedIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(group.name),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      GoRouter.of(context).push('/community/group/${group.id}', extra: group.name);
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
