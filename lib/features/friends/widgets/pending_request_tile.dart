import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/features/friends/controllers/friends_controller.dart';
import 'package:transconnect/models/friend_request.dart';

class PendingRequestTile extends StatelessWidget {
  final FriendRequest request;

  const PendingRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: request.fromUser.profilePic != null
            ? NetworkImage(request.fromUser.profilePic!)
            : null,
        child: request.fromUser.profilePic == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(request.fromUser.username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Sent ${timeAgo(request.createdAt)}'),
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
