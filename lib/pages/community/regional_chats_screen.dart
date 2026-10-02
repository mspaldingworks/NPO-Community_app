import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/group.dart';

typedef RegionsLoader = Future<List<RegionalGroup>> Function();
typedef RegionMembershipSetter =
    Future<void> Function(int groupId, {required bool join});

/// Emerge KY regional groups. Members are placed in their home region from
/// their county and can join (or leave) any of the others.
class RegionalChatsScreen extends StatefulWidget {
  const RegionalChatsScreen({super.key, this.loadRegions, this.setMembership});

  /// Optional injected data calls (used in tests).
  final RegionsLoader? loadRegions;
  final RegionMembershipSetter? setMembership;

  @override
  State<RegionalChatsScreen> createState() => _RegionalChatsScreenState();
}

class _RegionalChatsScreenState extends State<RegionalChatsScreen> {
  late final CommunityService _service = CommunityService();
  late Future<List<RegionalGroup>> _regionsFuture;
  final Set<int> _pending = {};

  RegionsLoader get _load => widget.loadRegions ?? _service.fetchRegions;
  RegionMembershipSetter get _set =>
      widget.setMembership ?? _service.setRegionMembership;

  @override
  void initState() {
    super.initState();
    _regionsFuture = _load();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _regionsFuture = future);
    await future;
  }

  Future<void> _toggle(RegionalGroup region) async {
    final join = !region.isMember;
    setState(() => _pending.add(region.group.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _set(region.group.id, join: join);
      await _refresh();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            join
                ? 'Could not join ${region.group.name}.'
                : 'Could not leave ${region.group.name}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(region.group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regional groups')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RegionalGroup>>(
          future: _regionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _message('Regional groups are unavailable right now.');
            }
            final regions = snapshot.data ?? [];
            if (regions.isEmpty) {
              return _message('No regional groups have been set up yet.');
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: regions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final region = regions[index];
                final busy = _pending.contains(region.group.id);
                return ListTile(
                  leading: Icon(
                    region.isHome ? Icons.home_outlined : Icons.hub_outlined,
                  ),
                  title: Text(region.group.name),
                  subtitle: region.isHome ? const Text('Your region') : null,
                  onTap: region.isMember
                      ? () => context.push(
                          '/community/group/${region.group.id}',
                          extra: region.group.name,
                        )
                      : null,
                  trailing: busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : region.isMember
                      ? OutlinedButton(
                          onPressed: () => _toggle(region),
                          child: const Text('Leave'),
                        )
                      : FilledButton(
                          onPressed: () => _toggle(region),
                          child: const Text('Join'),
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
