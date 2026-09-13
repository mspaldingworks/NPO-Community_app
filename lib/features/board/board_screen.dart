import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/view_mode_service.dart';
import 'package:npo_community/features/board/board_member.dart';
import 'package:npo_community/features/board/board_service.dart';

/// The board's working view: who serves, in what seat, on which committees.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late Future<List<BoardMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = BoardService().fetchBoardMembers();
  }

  Future<void> _refresh() async {
    final future = BoardService().fetchBoardMembers();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = context.watch<ViewModeService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          TextButton.icon(
            onPressed: () => viewMode.setMode(ViewMode.member),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Member view'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<BoardMember>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message('The board roster is unavailable right now.');
            }

            final members = snapshot.data ?? const <BoardMember>[];
            if (members.isEmpty) {
              return _message(
                'No board members have been recorded yet.\n\n'
                'Add them from the admin site, and they will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final committees = member.committeeLabelList;

                return ListTile(
                  isThreeLine: committees.isNotEmpty,
                  leading: CircleAvatar(
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(member.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.positionLabel),
                      if (committees.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            committees.join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
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
