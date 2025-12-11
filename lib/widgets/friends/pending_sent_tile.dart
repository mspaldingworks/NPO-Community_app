import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/friends_controller.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/utils/time_ago.dart';

class PendingSentTile extends StatelessWidget {
  final FriendRequest request;

  const PendingSentTile({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.read<FriendsController>();
    final toUser = request.toUser ?? request.fromUser; // fallback just in case
    final imageUrl = toUser.fullProfilePicUrl;

    final subtitleText = request.createdAt != null
        ? 'Sent ${timeAgo(request.createdAt!)}'
        : 'Request sent';

    return ListTile(
      leading: DisplayProfilePic(radius: 40, imageUrl: imageUrl),
      title: Text(toUser.username, style: const TextStyle(fontWeight: FontWeight.bold)),
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
