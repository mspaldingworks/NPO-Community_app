import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/utils/flair_utils.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/widgets/report_dialog.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final int userId;

  const PublicUserProfileScreen({super.key, required this.userId});

  @override
  State<PublicUserProfileScreen> createState() => _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  Future<User?> _loadUser() async {
    final auth = Provider.of<AuthService>(context, listen: false);
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
          IconButton(
            tooltip: 'Report user',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () async {
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
            },
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
            return const Center(child: Text('User not found.'));
          }

          final isPrivate = FlairUtils.isProfilePrivate(user.flair);
          final pronouns = FlairUtils.extractPronouns(user.flair) ?? '';
          final mutualAid = (FlairUtils.extractMutualAidEmojis(user.flair) ?? '').trim();

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
                if (!isPrivate && mutualAid.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      mutualAid,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
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
                  if (user.fullName != null && user.fullName!.trim().isNotEmpty) ...[
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
                    Text('Pronouns', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(pronouns.trim()),
                    const SizedBox(height: 16),
                  ],
                  if (user.statusMessage != null && user.statusMessage!.trim().isNotEmpty) ...[
                    Text('Status', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(user.statusMessage!.trim()),
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
