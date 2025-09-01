import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/features/community/models/group_model.dart';
import 'package:transconnect/features/community/services/community_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<Group>> _groupsFuture;
  final CommunityService _communityService = CommunityService();

  @override
  void initState() {
    super.initState();
    _groupsFuture = _communityService.fetchGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
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
            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  title: Text('# ${group.name}'),
                  onTap: () {
                    context.go('/community/${group.name.toLowerCase()}');
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
