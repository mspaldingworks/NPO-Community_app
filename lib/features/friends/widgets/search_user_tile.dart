import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/features/friends/controllers/friends_controller.dart';
import 'package:transconnect/models/user.dart';

class SearchUserTile extends StatelessWidget {
  final Friend user;

  const SearchUserTile({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FriendsController>();
    final isSent = controller.isRequestSent(user.username);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profilePic != null
            ? NetworkImage(user.profilePic!)
            : null,
        child: user.profilePic == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(user.city ?? 'No location'),
      trailing: ElevatedButton(
        onPressed: isSent
            ? null
            : () async {
                final success = await controller.sendFriendRequest(user.username);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.green),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send request.'), backgroundColor: Colors.red),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSent ? Colors.grey : Theme.of(context).primaryColor,
        ),
        child: Text(isSent ? 'Sent' : 'Add'),
      ),
    );
  }
}
