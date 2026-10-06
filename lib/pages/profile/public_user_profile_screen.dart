import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/widgets/report_dialog.dart';
import 'package:npo_community/core/services/block_service.dart';
import 'package:npo_community/core/utils/profile_links.dart';
import 'package:npo_community/core/utils/time_ago.dart';
import 'package:npo_community/pages/settings/blocked_members_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Another member's profile: photo, name and pronouns, her status, then her
/// details and links. A private profile shows only the name and pronouns.
class PublicUserProfileScreen extends StatefulWidget {
  final int userId;

  const PublicUserProfileScreen({super.key, required this.userId});

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  bool _isBlocked = false;

  /// Blocked members are hidden by the server, so check the block list
  /// first and show a plain "blocked" state instead of "not found".
  Future<User?> _loadUser() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final blocked = await BlockService().fetchBlocked();
      _isBlocked = blocked.any((b) => b.id == widget.userId);
    } catch (_) {
      _isBlocked = false;
    }
    if (_isBlocked) return null;
    final users = await auth.getAllUsers();
    try {
      return users.firstWhere((u) => u.id == widget.userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              if (value == 'report') {
                final user = await _loadUser();
                if (!context.mounted || user == null) return;
                await showReportDialog(
                  context: context,
                  baseRequest: ReportRequest(
                    type: ReportTargetType.user,
                    reason: '',
                    targetUserId: user.id,
                    targetUsername: user.username,
                    details: user.statusMessage,
                  ),
                );
              } else if (value == 'block') {
                final user = await _loadUser();
                if (!context.mounted) return;
                final done = await confirmAndBlock(
                  context,
                  userId: widget.userId,
                  name: user?.username ?? 'this member',
                );
                if (done && mounted) setState(() {});
              } else if (value == 'unblock') {
                await BlockService().unblock(widget.userId);
                if (mounted) setState(() {});
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(
                value: _isBlocked ? 'unblock' : 'block',
                child: Text(_isBlocked ? 'Unblock' : 'Block'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<User?>(
        future: _loadUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                _isBlocked
                    ? 'You have blocked this member. Unblock from the menu '
                          'or Settings to see their profile again.'
                    : 'User not found.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final isPrivate = FlairUtils.isProfilePrivate(user.flair);
          final pronouns = FlairUtils.extractPronouns(user.flair) ?? '';
          final status = (user.statusMessage ?? '').trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: DisplayProfilePic(
                    radius: 48,
                    imageUrl: user.fullProfilePicUrl,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.username,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!isPrivate && pronouns.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      pronouns.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (!isPrivate && status.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: const Key('status-card'),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mode_comment_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (user.statusUpdatedAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    timeAgo(user.statusUpdatedAt!),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isPrivate)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This profile is private.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (user.fullName != null &&
                      user.fullName!.trim().isNotEmpty) ...[
                    Text('Name', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(user.fullName!.trim()),
                    const SizedBox(height: 16),
                  ],
                  if (user.city != null && user.city!.trim().isNotEmpty) ...[
                    Text('City', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(user.city!.trim()),
                    const SizedBox(height: 16),
                  ],
                  if (pronouns.trim().isNotEmpty) ...[
                    Text(
                      'Pronouns',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(pronouns.trim()),
                    const SizedBox(height: 16),
                  ],
                  if (user.links.isNotEmpty) ...[
                    Text(
                      'Links',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    for (final link in user.links)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          key: Key('link-${link.url}'),
                          leading: Icon(iconForProfileLink(link)),
                          title: Text(link.displayLabel),
                          subtitle: Text(
                            Uri.tryParse(link.url)?.host ?? link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => launchUrl(
                            Uri.parse(link.url),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
