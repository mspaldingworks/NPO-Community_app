import 'package:flutter/material.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_controller.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';

/// The Alumni Directory tab: browse and search Emerge Kentucky alumni,
/// backed by the server-side NGP VAN CRM.
class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key, this.controller});

  /// Optional injected controller (used in tests / demo mode).
  final AlumniDirectoryController? controller;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alumni Directory')),
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
                label: Text("'${year % 100} cohort"),
                selected: _controller.cohortYear == year,
                onSelected: (_) => _controller.setCohortYear(year),
              ),
            ),
        ],
      ),
    );
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
        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView.separated(
            itemCount: _controller.alumni.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _AlumniTile(profile: _controller.alumni[index]),
          ),
        );
    }
  }
}

class _AlumniTile extends StatelessWidget {
  const _AlumniTile({required this.profile});

  final AlumniProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[
      if (profile.cohortYear != null) 'Cohort ${profile.cohortYear}',
      if (profile.location != null) profile.location!,
      if (profile.officeSought != null) profile.officeSought!,
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Text(profile.initials),
      ),
      title: Text(profile.fullName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: profile.email == null ? null : const Icon(Icons.chevron_right),
      onTap: profile.email == null
          ? null
          : () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => _AlumniDetailSheet(profile: profile),
            ),
    );
  }
}

class _AlumniDetailSheet extends StatelessWidget {
  const _AlumniDetailSheet({required this.profile});

  final AlumniProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.fullName, style: textTheme.titleLarge),
            if (profile.cohortYear != null) ...[
              const SizedBox(height: 4),
              Text(
                'Emerge Kentucky · Cohort ${profile.cohortYear}',
                style: textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (profile.officeSought != null)
              _DetailRow(icon: Icons.how_to_vote, text: profile.officeSought!),
            if (profile.location != null)
              _DetailRow(icon: Icons.place_outlined, text: profile.location!),
            if (profile.email != null)
              _DetailRow(icon: Icons.email_outlined, text: profile.email!),
            if (profile.phone != null)
              _DetailRow(icon: Icons.phone_outlined, text: profile.phone!),
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
