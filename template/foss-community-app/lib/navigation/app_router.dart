import 'package:go_router/go_router.dart';

import '../pages/admin/admin_page.dart';
import '../pages/auth/auth_page.dart';
import '../pages/chat/chat_page.dart';
import '../pages/community/community_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/dev/dev_page.dart';
import '../pages/directory/directory_page.dart';
import '../pages/events/events_page.dart';
import '../pages/friends/friends_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/resources/resources_page.dart';
import '../pages/settings/settings_page.dart';
import '../features/dev/dev_tools_page.dart';
import '../features/onboarding_tour/onboarding_tour_page.dart';

class AppRouter {
  static GoRouter create() => GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/community', builder: (_, __) => const CommunityPage()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
      GoRoute(path: '/events', builder: (_, __) => const EventsPage()),
      GoRoute(path: '/directory', builder: (_, __) => const DirectoryPage()),
      GoRoute(path: '/friends', builder: (_, __) => const FriendsPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/resources', builder: (_, __) => const ResourcesPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminPage()),
      GoRoute(path: '/dev', builder: (_, __) => const DevPage()),
      GoRoute(path: '/onboarding-tour', builder: (_, __) => const OnboardingTourPage()),
      GoRoute(path: '/dev-tools', builder: (_, __) => const DevToolsPage()),
    ],
  );
}
