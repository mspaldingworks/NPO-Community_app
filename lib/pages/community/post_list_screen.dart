import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/community/group_feed.dart';
import 'package:npo_community/features/group_console/group_console_service.dart';
import 'package:npo_community/models/group.dart';

/// One group's feed with its name in the bar and a shortcut to its console.
///
/// The Candidates Running group gets two tabs: "Who's running", the same
/// cards as the Ballot page (race, campaign, donate, volunteer events), and
/// the group's chat.
class PostListScreen extends StatelessWidget {
  const PostListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.group,
    this.service,
    this.console,
    this.candidates,
    this.openLink,
    this.showPhotos,
    this.now,
  });

  final int groupId;
  final String groupName;

  /// The group itself when the caller has it; decides the candidates layout.
  final Group? group;

  /// Injected in tests.
  final CommunityService? service;
  final GroupConsoleService? console;

  /// Ballot-page overrides, injected in tests.
  final List<AlumniCandidate>? candidates;
  final CampaignLinkOpener? openLink;
  final bool? showPhotos;
  final DateTime Function()? now;

  bool get _isCandidates => group?.isCandidates ?? false;

  @override
  Widget build(BuildContext context) {
    final consoleButton = IconButton(
      tooltip: 'Group info, events and polls',
      icon: const Icon(Icons.info_outline),
      onPressed: () =>
          context.push('/community/group/$groupId/console', extra: groupName),
    );
    final feed = GroupFeed(
      groupId: groupId,
      groupName: groupName,
      service: service,
      console: console,
    );

    if (!_isCandidates) {
      return Scaffold(
        appBar: AppBar(title: Text(groupName), actions: [consoleButton]),
        body: feed,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(groupName),
          actions: [consoleButton],
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('tab-running'), text: "Who's running"),
              Tab(key: Key('tab-chat'), text: 'Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AlumniRunningList(
              candidates: candidates,
              openLink: openLink,
              showPhotos: showPhotos,
              now: now,
            ),
            feed,
          ],
        ),
      ),
    );
  }
}
