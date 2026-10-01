import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/features/alumni_running/alumni_running_screen.dart';
import 'package:npo_community/features/alumni_running/api_campaign_repository.dart';
import 'package:npo_community/features/alumni_running/campaign_channel_screen.dart';
import 'package:npo_community/features/alumni_running/campaign_repository.dart';
import 'package:npo_community/features/alumni_running/candidate_detail_screen.dart';
import 'package:npo_community/features/alumni_running/demo_campaign_repository.dart';

/// Picks the hub's data source at the composition root: synthetic in demo
/// builds (zero network), the API everywhere else.
CampaignRepository createCampaignRepository(AppConfig config) =>
    config.networkEnabled ? ApiCampaignRepository() : DemoCampaignRepository();

/// `/alumni/running`, `/alumni/running/:id`, `/alumni/running/:id/channel`.
GoRoute campaignHubRoute({GlobalKey<NavigatorState>? parentNavigatorKey}) =>
    GoRoute(
      path: '/alumni/running',
      parentNavigatorKey: parentNavigatorKey,
      builder: (context, state) => const AlumniRunningScreen(),
      routes: [
        GoRoute(
          path: ':id',
          parentNavigatorKey: parentNavigatorKey,
          builder: (context, state) =>
              CandidateDetailScreen(candidateId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'channel',
              parentNavigatorKey: parentNavigatorKey,
              builder: (context, state) => CampaignChannelScreen(
                candidateId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );
