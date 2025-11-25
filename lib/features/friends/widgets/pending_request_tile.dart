import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/features/friends/controllers/friends_controller.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PendingRequestTile extends StatelessWidget {
  final FriendRequest request;

  const PendingRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();    
    final imageUrl = request.fromUser.fullProfilePicUrl;
    print((imageUrl ?? 'No image'));

    return ListTile(
      leading: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        // 1. If URL is null, backgroundImage is null
        // 2. If URL exists, CachedNetworkImageProvider handles 
        //    cache check -> download -> save -> display logic.
        backgroundImage: imageUrl != null 
            ? CachedNetworkImageProvider(imageUrl) 
            : null,
        child: imageUrl == null
            ? const Icon(Icons.person, size: 40)
            : null, 
      ),
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
