import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/core/services/friends_controller.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';

class PendingRequestTile extends StatelessWidget {
  final FriendRequest request;

  const PendingRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();    
    final imageUrl = request.fromUser.fullProfilePicUrl;
    print((imageUrl ?? 'No image'));

    return ListTile(
      leading: DisplayProfilePic(radius: 40, imageUrl: imageUrl),
      title: Text(request.fromUser.username, style: const TextStyle(fontWeight: FontWeight.bold)),
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
