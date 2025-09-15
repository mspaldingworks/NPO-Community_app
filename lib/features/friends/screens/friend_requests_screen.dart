import 'package:flutter/material.dart';
import 'package:transconnect/core/services/friend_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final FriendService _friendService = FriendService();
  late Future<List<dynamic>> _requestsFuture;

  void _respondToRequest(String requestId, String action) async {
    try {
      await _friendService.respondToFriendRequest(requestId, action);
      // Refresh the list after responding
      setState(() {
        _requestsFuture = _friendService.fetchFriendRequests();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request ${action}ed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond to request: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _requestsFuture = _friendService.fetchFriendRequests();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('You have no friend requests.'));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            // Assuming the request object has user info and an ID.
            // You might need to adjust this based on your actual data model.
            final username = request['from_user']['username'] ?? 'Unknown User';
            final requestId = request['id'] ?? '';

            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_add),
              ),
              title: Text('$username wants to be your friend'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _respondToRequest(requestId, 'accept'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _respondToRequest(requestId, 'decline'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
