import 'package:flutter/material.dart';
import 'package:npo_community/core/services/block_service.dart';

/// Settings → Blocked members: who you've blocked, with Unblock.
class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key, this.service});

  /// Optional injected service (used in tests).
  final BlockService? service;

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  late final BlockService _service = widget.service ?? BlockService();
  late Future<List<BlockedMember>> _future = _service.fetchBlocked();

  Future<void> _reload() async {
    final future = _service.fetchBlocked();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _unblock(BlockedMember member) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.unblock(member.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${member.displayName} unblocked.')),
      );
      await _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not unblock: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked members')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<BlockedMember>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message('Could not load your blocked list.');
            }
            final members = snapshot.data!;
            if (members.isEmpty) {
              return _message(
                'You have not blocked anyone. Blocking a member hides you '
                'from each other and stops messages both ways.',
              );
            }
            return ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(member.displayName),
                  subtitle: Text('@${member.username}'),
                  trailing: TextButton(
                    onPressed: () => _unblock(member),
                    child: const Text('Unblock'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _message(String text) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
    children: [Text(text, textAlign: TextAlign.center)],
  );
}

/// Confirms, then blocks [userId]. Returns true when the block was made.
Future<bool> confirmAndBlock(
  BuildContext context, {
  required int userId,
  required String name,
  BlockService? service,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        'You will no longer see each other\'s posts, comments or messages, '
        'and any friendship ends. You can unblock from Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await (service ?? BlockService()).block(userId);
    messenger?.showSnackBar(SnackBar(content: Text('$name blocked.')));
    return true;
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not block: $e')));
    return false;
  }
}
