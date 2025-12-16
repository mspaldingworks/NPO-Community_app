import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/friends_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/core/utils/flair_utils.dart';

class PendingSentTile extends StatelessWidget {
  final FriendRequest request;

  const PendingSentTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();
    final toUser = request.toUser ?? request.fromUser; // fallback just in case
    final imageUrl = toUser.fullProfilePicUrl;

    final isPrivate = FlairUtils.isProfilePrivate(toUser.flair);
    final String? pronounsDisplay = isPrivate
        ? null
        : (FlairUtils.extractPronouns(toUser.flair) ?? '')
            .split(RegExp(r'[\n,]'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' • ');

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
          Text(toUser.username, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                pronounsDisplay,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      subtitle: Text(subtitleText),
      trailing: OutlinedButton(
        onPressed: () async {
          final success = await controller.declineRequest(toUser.username);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Friend request canceled.' : 'Failed to cancel request.'),
                backgroundColor: success ? Colors.grey : Colors.red,
              ),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        child: const Text('Cancel'),
      ),
    );
  }
}
