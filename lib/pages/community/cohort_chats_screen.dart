import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/group.dart';

/// One group chat per program cohort year.
///
/// Every alum can browse any year, so this lists all cohorts rather than only
/// the viewer's own. Their year is pinned to the top and marked, since that is
/// the one they'll usually want.
class CohortChatsScreen extends StatefulWidget {
  const CohortChatsScreen({super.key});

  @override
  State<CohortChatsScreen> createState() => _CohortChatsScreenState();
}

class _CohortChatsScreenState extends State<CohortChatsScreen> {
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = CommunityService().fetchGroups();
  }

  Future<void> _refresh() async {
    final future = CommunityService().fetchGroups();
    setState(() => _groupsFuture = future);
    await future;
  }

  /// Cohort groups are named "Class of <year>"; pull the year back out so the
  /// list can be ordered and matched against the viewer's own cohort.
  static int? _yearOf(Group group) {
    final match = RegExp(r'Class of (\d{4})').firstMatch(group.name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    final myYear = context.watch<AuthService>().currentUser?.programYear;

    return Scaffold(
      appBar: AppBar(title: const Text('Class Chats')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Group>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message('Class chats are unavailable right now.');
            }

            final cohorts =
                (snapshot.data ?? []).where((g) => _yearOf(g) != null).toList()
                  ..sort((a, b) => _yearOf(b)!.compareTo(_yearOf(a)!));

            if (cohorts.isEmpty) {
              return _message('No class chats have been set up yet.');
            }

            // Pin the viewer's own cohort to the top.
            if (myYear != null) {
              final mineIndex = cohorts.indexWhere((g) => _yearOf(g) == myYear);
              if (mineIndex > 0) {
                cohorts.insert(0, cohorts.removeAt(mineIndex));
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cohorts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = cohorts[index];
                final year = _yearOf(group);
                final isMine = myYear != null && year == myYear;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMine
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isMine ? Icons.school : Icons.groups_outlined,
                      size: 20,
                      color: isMine
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(group.name),
                  subtitle: isMine ? const Text('Your class') : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/community/group/${group.id}',
                    extra: group.name,
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
