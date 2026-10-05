import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_controller.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/events/volunteer_roles.dart';
import 'package:npo_community/pages/chat/chat_message_screen.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/widgets/emerge/emerge_components.dart';

/// The Alumni Directory tab: browse and search Emerge Kentucky alumni,
/// backed by the server-side NGP VAN CRM.
class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key, this.controller, this.currentUserId});

  /// Optional injected controller (used in tests / demo mode).
  final AlumniDirectoryController? controller;

  /// The signed-in member, so she gets no Message button on herself;
  /// read from the app's AuthService when not given.
  final int? currentUserId;

  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  late final AlumniDirectoryController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AlumniDirectoryController();
    _controller.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Only dispose controllers we created ourselves.
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// Demo builds show this screen in a plain MaterialApp with no GoRouter,
  /// so fall back to a Navigator push there.
  void _openBallot() {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/alumni/running');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AlumniRunningScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Directory'),
        actions: [
          IconButton(
            tooltip: 'Ballot',
            icon: const Icon(Icons.how_to_vote_outlined),
            onPressed: _openBallot,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              _buildSearchField(),
              _buildCohortFilters(),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search alumni by name',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _controller.setSearch('');
                  },
                ),
        ),
        onSubmitted: _controller.setSearch,
      ),
    );
  }

  Widget _buildCohortFilters() {
    final cohorts = _controller.availableCohorts;
    if (cohorts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: const Text('All cohorts'),
              selected: _controller.cohortYear == null,
              onSelected: (_) => _controller.setCohortYear(null),
            ),
          ),
          for (final year in cohorts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                label: Text("Class of '${year % 100}"),
                selected: _controller.cohortYear == year,
                onSelected: (_) => _controller.setCohortYear(year),
              ),
            ),
        ],
      ),
    );
  }

  int? _viewerId(BuildContext context) {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Provider.of<AuthService>(context, listen: false).currentUser?.id;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Widget _buildBody() {
    switch (_controller.status) {
      case AlumniDirectoryStatus.idle:
      case AlumniDirectoryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AlumniDirectoryStatus.error:
        return _MessageState(
          icon: Icons.error_outline,
          title: 'Could not load alumni',
          message: _controller.error ?? 'Please try again.',
          onRetry: _controller.load,
        );
      case AlumniDirectoryStatus.loaded:
        if (_controller.alumni.isEmpty) {
          return const _MessageState(
            icon: Icons.people_outline,
            title: 'No alumni found',
            message: 'Try a different search or cohort filter.',
          );
        }
        // Header + list, echoing the website's "All Alumnae: 334 Ready to
        // Run" title block above the roster.
        final count = _controller.alumni.length;
        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView.separated(
            itemCount: count + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    if (_controller.isOffline) const _OfflineNotice(),
                    EmergeTitleBlock(
                      title: '$count Ready to Run',
                      showDots: true,
                    ),
                  ],
                );
              }
              return _AlumniTile(
                currentUserId: _viewerId(context),
                profile: _controller.alumni[index - 1],
              );
            },
          ),
        );
    }
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing the last saved directory.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a direct message with an alumna: by route under the app's router,
/// else by a plain push (demo builds and tests).
void openDirectMessage(BuildContext context, AlumniProfile profile) {
  final id = profile.accountId;
  if (id == null) return;
  if (GoRouter.maybeOf(context) != null) {
    context.push('/chat/$id', extra: profile.fullName);
  } else {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatMessageScreen(
          conversationId: '$id',
          initialName: profile.fullName,
        ),
      ),
    );
  }
}

/// Whether the viewer can message this alumna: she has claimed her account
/// (so she can log in and read it), is not a memorial, and is not the viewer.
bool canMessage(AlumniProfile profile, int? viewerId) =>
    profile.accountId != null &&
    profile.claimed &&
    !profile.isMemorial &&
    profile.accountId != viewerId;

class _AlumniTile extends StatelessWidget {
  const _AlumniTile({required this.profile, required this.currentUserId});

  final AlumniProfile profile;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[
      if (profile.isMemorial) 'In memoriam',
      if (profile.cohortYear != null) 'Class of ${profile.cohortYear}',
      if (profile.location != null) profile.location!,
      if (profile.officeSought != null) profile.officeSought!,
      if (profile.volunteerRoles.isNotEmpty)
        profile.volunteerRoles.map(volunteerRoleShortLabel).join(', '),
      if (!profile.claimed && !profile.isMemorial) "Hasn't joined yet",
    ];
    final messageable = canMessage(profile, currentUserId);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Text(profile.initials),
      ),
      title: Text(profile.fullName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: messageable
          ? IconButton(
              key: Key('message-${profile.accountId}'),
              tooltip: 'Message ${profile.firstName}',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => openDirectMessage(context, profile),
            )
          : null,
      onTap: profile.isMemorial
          ? null
          : () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => _AlumniDetailSheet(
                profile: profile,
                messageable: messageable,
              ),
            ),
    );
  }
}

class _AlumniDetailSheet extends StatelessWidget {
  const _AlumniDetailSheet({required this.profile, this.messageable = false});

  final AlumniProfile profile;
  final bool messageable;

  @override
  Widget build(BuildContext context) {
    final detailParts = <String>[
      'Emerge Kentucky',
      if (profile.cohortYear != null) 'Class of ${profile.cohortYear}',
      if (profile.location != null) profile.location!,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmergeBioCard(
              name: profile.fullName,
              subtitle: profile.officeSought,
              detail: detailParts.join(' · '),
              initials: profile.initials,
            ),
            const SizedBox(height: 8),
            if (profile.email != null)
              _DetailRow(icon: Icons.email_outlined, text: profile.email!),
            if (profile.phone != null)
              _DetailRow(icon: Icons.phone_outlined, text: profile.phone!),
            if (messageable) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('sheet-message'),
                onPressed: () {
                  Navigator.of(context).pop();
                  openDirectMessage(context, profile);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('Message ${profile.firstName}'),
              ),
            ] else if (!profile.claimed && !profile.isMemorial) ...[
              const SizedBox(height: 12),
              Text(
                "${profile.firstName} hasn't claimed her profile yet, so she "
                'can\'t receive messages in the app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
