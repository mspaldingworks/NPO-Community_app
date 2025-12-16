import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/core/services/friends_controller.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/utils/flair_utils.dart';

class PendingRequestTile extends StatelessWidget {
  final FriendRequest request;

  const PendingRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();    
    final imageUrl = request.fromUser.fullProfilePicUrl;
    print((imageUrl ?? 'No image'));

    final isPrivate = FlairUtils.isProfilePrivate(request.fromUser.flair);
    final String? pronounsDisplay = isPrivate
        ? null
        : (FlairUtils.extractPronouns(request.fromUser.flair) ?? '')
            .split(RegExp(r'[\n,]'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' • ');

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          if (request.fromUser.id <= 0) return;
          context.push('/users/${request.fromUser.id}');
        },
        child: DisplayProfilePic(radius: 40, imageUrl: imageUrl),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.fromUser.username, style: const TextStyle(fontWeight: FontWeight.bold)),
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
      subtitle: request.createdAt != null
          ? Text('Sent ${timeAgo(request.createdAt!)}')
          : const Text('Pending request'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              final success = await controller.acceptRequest(request.fromUser.username);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Friend request accepted!' : 'Failed to accept request.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Accept'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final success = await controller.declineRequest(request.fromUser.username);
               if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Friend request declined.' : 'Failed to decline request.'),
                    backgroundColor: success ? Colors.grey : Colors.red,
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
