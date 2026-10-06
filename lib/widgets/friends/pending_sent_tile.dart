import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/friends_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/models/friend_request.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/core/utils/time_ago.dart';

class PendingSentTile extends StatelessWidget {
  final FriendRequest request;

  const PendingSentTile({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FriendsController>();
    final toUser = request.toUser ?? request.fromUser; // fallback just in case
    final imageUrl = toUser.fullProfilePicUrl;

    final isInProgress = controller.isRequestActionInProgress(toUser.username);

    final subtitleText = request.createdAt != null
        ? 'Sent ${timeAgo(request.createdAt!)}'
        : 'Request sent';

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          if (toUser.id <= 0) return;
          context.push('/users/${toUser.id}');
        },
        child: DisplayProfilePic(radius: 40, imageUrl: imageUrl),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            toUser.username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(subtitleText),
      trailing: OutlinedButton(
        onPressed: isInProgress
            ? null
            : () async {
                final success = await controller.declineRequest(
                  toUser.username,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Friend request canceled.'
                            : 'Failed to cancel request.',
                      ),
                      backgroundColor: success ? Colors.grey : Colors.red,
                    ),
                  );
                }
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        child: isInProgress
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Cancel'),
      ),
    );
  }
}
