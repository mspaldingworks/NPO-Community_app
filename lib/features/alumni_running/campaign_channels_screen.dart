import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/widgets/campaign_widgets.dart';

/// Campaign supporter channels the user has chosen to join.
class CampaignChannelsScreen extends StatefulWidget {
  const CampaignChannelsScreen({super.key});

  @override
  State<CampaignChannelsScreen> createState() => _CampaignChannelsScreenState();
}

class _CampaignChannelsScreenState extends State<CampaignChannelsScreen> {
  @override
  void initState() {
    super.initState();
    final hub = context.read<CampaignHubController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => hub.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    final joined = hub.joinedCandidates;

    final Widget body;
    if (hub.status == CampaignHubStatus.error) {
      body = Center(child: Text(hub.error ?? 'Unable to load channels.'));
    } else if (hub.status != CampaignHubStatus.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (joined.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "You haven't joined any campaign channels. Open an alum on "
                'the ballot to join their supporter channel.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/alumni/running'),
                icon: const Icon(Icons.how_to_vote_outlined),
                label: const Text('Alumni on the Ballot'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView.separated(
        itemCount: joined.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final candidate = joined[index];
          return ListTile(
            leading: CandidateAvatar(candidate: candidate, radius: 20),
            title: Text('${candidate.name} team'),
            subtitle: Text(candidate.office),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/alumni/running/${candidate.id}/channel'),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Channels')),
      body: body,
    );
  }
}
