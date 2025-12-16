import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/friends_controller.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/utils/flair_utils.dart';

class SearchUserTile extends StatelessWidget {
  final Friend user;

  const SearchUserTile({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FriendsController>();
    final isSent = controller.isRequestSent(user.username);
    final isPrivate = FlairUtils.isProfilePrivate(user.flair);
    final String? pronounsDisplay = isPrivate
        ? null
        : (FlairUtils.extractPronouns(user.flair) ?? '')
            .split(RegExp(r'[\n,]'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' • ');

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          context.push('/users/${user.id}');
        },
        child: DisplayProfilePic(radius: 20, imageUrl: user.fullProfilePicUrl),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                pronounsDisplay,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      subtitle: isPrivate ? const Text('Private profile') : Text(user.city ?? 'No location'),
      onTap: () {
        context.push('/users/${user.id}');
      },
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
