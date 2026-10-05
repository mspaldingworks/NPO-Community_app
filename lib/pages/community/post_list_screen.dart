import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/features/community/group_feed.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';

/// One group's feed with its name in the bar and a shortcut to its console.
class PostListScreen extends StatelessWidget {
  const PostListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.service,
    this.console,
  });

  final int groupId;
  final String groupName;

  /// Injected in tests.
  final CommunityService? service;
  final GroupConsoleService? console;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          IconButton(
            tooltip: 'Group info, events and polls',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(
              '/community/group/$groupId/console',
              extra: groupName,
            ),
          ),
        ],
      ),
      body: GroupFeed(
        groupId: groupId,
        groupName: groupName,
        service: service,
        console: console,
      ),
    );
  }
}
