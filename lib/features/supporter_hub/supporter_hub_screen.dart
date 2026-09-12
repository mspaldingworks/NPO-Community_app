import 'package:flutter/material.dart';
import 'package:npo_community/features/fundraising/fundraising_controller.dart';
import 'package:npo_community/features/fundraising/models/givebutter_campaign.dart';
import 'package:npo_community/features/fundraising/screens/create_campaign_screen.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_controller.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SupporterHubScreen extends StatelessWidget {
  const SupporterHubScreen({super.key});

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard),
      label: 'Overview',
    ),
    NavigationDestination(
      icon: Icon(Icons.check_circle_outline),
      selectedIcon: Icon(Icons.check_circle),
      label: 'Tasks',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'Events',
    ),
    NavigationDestination(
      icon: Icon(Icons.trending_up_outlined),
      selectedIcon: Icon(Icons.trending_up),
      label: 'Fundraising',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'People',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupporterHubController>();
    final pages = <Widget>[
      const _OverviewView(),
      const _TasksView(),
      const _EventsView(),
      const _FundraisingView(),
      const _PeopleView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const _Wordmark(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _showMessage(context, 'You are all caught up.'),
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_none),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              label: 'Account',
              button: true,
              child: const CircleAvatar(radius: 17, child: Text('MS')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: controller.selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.selectedIndex,
        onDestinationSelected: controller.selectTool,
        destinations: _destinations,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFE1F0D5),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(7),
            child: Icon(Icons.hub_outlined, size: 18),
          ),
        ),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'NPO Community',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OverviewView extends StatelessWidget {
  const _OverviewView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupporterHubController>();
    final openTasks = controller.tasks.where((task) => !task.isComplete);

    return _ToolPage(
      title: 'Good morning, Maddie',
      subtitle: 'Here is what needs attention across the organization.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${controller.openTaskCount}',
                  label: 'Open tasks',
                  icon: Icons.task_alt,
                  color: const Color(0xFF2F6B4F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  value: '${controller.volunteerOpenings}',
                  label: 'Roles to fill',
                  icon: Icons.volunteer_activism_outlined,
                  color: const Color(0xFFC25432),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Priority work',
            actionLabel: 'View tasks',
            onPressed: () => controller.selectTool(1),
          ),
          const SizedBox(height: 8),
          ...openTasks.take(3).map((task) => _TaskRow(task: task)),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Upcoming events',
            actionLabel: 'View events',
            onPressed: () => controller.selectTool(2),
          ),
          const SizedBox(height: 8),
          ...controller.events
              .take(2)
              .map((event) => _EventRow(event: event, compact: true)),
          const SizedBox(height: 24),
          const _AsanaConnection(),
        ],
      ),
    );
  }
}

class _TasksView extends StatefulWidget {
  const _TasksView();

  @override
  State<_TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<_TasksView> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupporterHubController>();
    final tasks = controller.tasks
        .where((task) => _showCompleted || !task.isComplete)
        .toList();

    return _ToolPage(
      title: 'Tasks',
      subtitle:
          '${controller.openTaskCount} open across NPO Community and Asana.',
      action: FilledButton.icon(
        onPressed: () => _showAddTask(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: Column(
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Open')),
              ButtonSegment(value: true, label: Text('All')),
            ],
            selected: {_showCompleted},
            onSelectionChanged: (selection) {
              setState(() => _showCompleted = selection.first);
            },
          ),
          const SizedBox(height: 16),
          ...tasks.map((task) => _TaskRow(task: task)),
        ],
      ),
    );
  }

  Future<void> _showAddTask(BuildContext context) async {
    final titleController = TextEditingController();
    final ownerController = TextEditingController(text: 'You');
    final controller = context.read<SupporterHubController>();
    final shouldAdd = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New task', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Task'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(labelText: 'Owner'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create task'),
            ),
          ],
        ),
      ),
    );
    if (shouldAdd == true && titleController.text.trim().isNotEmpty) {
      controller.addTask(
        title: titleController.text.trim(),
        owner: ownerController.text.trim().isEmpty
            ? 'Unassigned'
            : ownerController.text.trim(),
        dueLabel: 'No due date',
        project: 'General',
      );
    }
    titleController.dispose();
    ownerController.dispose();
  }
}

class _EventsView extends StatelessWidget {
  const _EventsView();

  @override
  Widget build(BuildContext context) {
    final events = context.watch<SupporterHubController>().events;
    return _ToolPage(
      title: 'Events & volunteering',
      subtitle: 'Plan programs, fill roles, and keep every event moving.',
      action: IconButton.filled(
        tooltip: 'Plan event',
        onPressed: () => _showMessage(
          context,
          'Event planning will connect to the NPO API.',
        ),
        icon: const Icon(Icons.add),
      ),
      child: Column(
        children: events.map((event) => _EventRow(event: event)).toList(),
      ),
    );
  }
}

class _FundraisingView extends StatelessWidget {
  const _FundraisingView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FundraisingController>();

    Widget body;
    switch (controller.status) {
      case FundraisingStatus.idle:
      case FundraisingStatus.loading:
        body = const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      case FundraisingStatus.error:
        body = _GivebutterErrorCard(
          message: controller.error ?? 'Could not load campaigns.',
          onRetry: controller.loadCampaigns,
        );
      case FundraisingStatus.loaded:
        body = controller.campaigns.isEmpty
            ? _GivebutterEmptyState(
                onCreateCampaign: () => _pushCreate(context, controller),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controller.campaigns
                    .map((c) => _GivebutterCampaignCard(campaign: c))
                    .toList(),
              );
    }

    return _ToolPage(
      title: 'Fundraising',
      subtitle: 'Live campaigns powered by Givebutter.',
      action: FilledButton.icon(
        onPressed: controller.isCreating
            ? null
            : () => _pushCreate(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      child: body,
    );
  }

  Future<void> _pushCreate(
    BuildContext context,
    FundraisingController controller,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateCampaignScreen(controller: controller),
      ),
    );
  }
}

class _GivebutterCampaignCard extends StatelessWidget {
  const _GivebutterCampaignCard({required this.campaign});

  final GivebutterCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _SourceBadge(label: campaign.status.toUpperCase()),
              ],
            ),
            if (campaign.subtitle != null && campaign.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                campaign.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  campaign.raisedLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(' raised of ${campaign.goalLabel}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: campaign.goalProgress,
              backgroundColor: const Color(0xFFE8ECE8),
              color: const Color(0xFF2F6B4F),
            ),
            const SizedBox(height: 8),
            Text(
              '${campaign.donors} donor${campaign.donors == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (campaign.url.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _launchUrl(campaign.url),
                child: Text(
                  campaign.url,
                  style: const TextStyle(
                    color: Color(0xFF2F6B4F),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF2F6B4F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _GivebutterErrorCard extends StatelessWidget {
  const _GivebutterErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB33A2B), size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _GivebutterEmptyState extends StatelessWidget {
  const _GivebutterEmptyState({required this.onCreateCampaign});

  final VoidCallback onCreateCampaign;

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.volunteer_activism_outlined,
              size: 40,
              color: Color(0xFF2F6B4F),
            ),
            const SizedBox(height: 12),
            Text(
              'No campaigns yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Create your first Givebutter campaign to start fundraising.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateCampaign,
              icon: const Icon(Icons.add),
              label: const Text('Create campaign'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleView extends StatefulWidget {
  const _PeopleView();

  @override
  State<_PeopleView> createState() => _PeopleViewState();
}

class _PeopleViewState extends State<_PeopleView> {
  SupporterKind? _filter;

  @override
  Widget build(BuildContext context) {
    final allSupporters = context.watch<SupporterHubController>().supporters;
    final supporters = allSupporters
        .where((supporter) => _filter == null || supporter.kind == _filter)
        .toList();

    return _ToolPage(
      title: 'People',
      subtitle: 'Volunteers, donors, and prospects in one working list.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ...SupporterKind.values.map(
                  (kind) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_kindLabel(kind)),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...supporters.map((supporter) => _SupporterRow(supporter: supporter)),
        ],
      ),
    );
  }
}

class _ToolPage extends StatelessWidget {
  const _ToolPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F665F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({this.title, this.actionLabel, this.onPressed});

  final String? title;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onPressed, child: Text(actionLabel!)),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final SupporterTask task;

  @override
  Widget build(BuildContext context) {
    final urgent = task.priority == TaskPriority.urgent;
    return _ListSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isComplete,
            onChanged: (_) =>
                context.read<SupporterHubController>().toggleTask(task.id),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: task.isComplete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(task.project),
                      Text('Owner: ${task.owner}'),
                      Text(
                        task.dueLabel,
                        style: TextStyle(
                          color: urgent ? const Color(0xFFB33A2B) : null,
                          fontWeight: urgent ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (task.source == TaskSource.asana)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _SourceBadge(label: 'ASANA'),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, this.compact = false});

  final EventPlan event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _SourceBadge(label: event.status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 6),
            Text('${event.dateLabel}  |  ${event.location}'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: event.volunteerProgress),
            const SizedBox(height: 7),
            Text(
              '${event.volunteersFilled} of ${event.volunteersNeeded} volunteer roles filled'
              '${compact ? '' : '  |  ${event.openTasks} open tasks'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupporterRow extends StatelessWidget {
  const _SupporterRow({required this.supporter});

  final SupporterRecord supporter;

  @override
  Widget build(BuildContext context) {
    final initials = supporter.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
    return _ListSurface(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(child: Text(initials)),
        title: Text(supporter.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${_kindLabel(supporter.kind)}  |  ${supporter.detail}\n${supporter.nextTouch}',
          ),
        ),
        trailing: IconButton(
          tooltip: 'Contact ${supporter.name}',
          onPressed: () => _showMessage(
            context,
            'Contact action ready for ${supporter.name}.',
          ),
          icon: const Icon(Icons.chat_bubble_outline),
        ),
      ),
    );
  }
}

class _AsanaConnection extends StatelessWidget {
  const _AsanaConnection();

  @override
  Widget build(BuildContext context) {
    return _ListSurface(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const Icon(Icons.sync),
        title: const Text('Asana workspace'),
        subtitle: const Text('3 assigned tasks shown in this demo'),
        trailing: OutlinedButton(
          onPressed: () => _showMessage(
            context,
            'Asana will connect through secure server authorization.',
          ),
          child: const Text('Connect'),
        ),
      ),
    );
  }
}

class _ListSurface extends StatelessWidget {
  const _ListSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE2DC)),
        ),
        child: child,
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECE8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

String _kindLabel(SupporterKind kind) {
  return switch (kind) {
    SupporterKind.volunteer => 'Volunteer',
    SupporterKind.donor => 'Donor',
    SupporterKind.prospect => 'Prospect',
  };
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
