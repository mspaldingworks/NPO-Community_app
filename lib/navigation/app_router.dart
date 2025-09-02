import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/auth/screens/register_screen.dart';
import 'package:transconnect/features/auth/screens/signin_screen.dart';
import 'package:transconnect/features/auth/screens/welcome_screen.dart';
import 'package:transconnect/features/community/screens/chat_screen.dart';
import 'package:transconnect/features/community/screens/community_screen.dart';
import 'package:transconnect/features/dashboard/screens/dashboard_screen.dart';
import 'package:transconnect/features/profile/screens/profile_screen.dart';
import 'package:transconnect/features/resources/screens/resources_screen.dart';
import 'package:transconnect/features/settings/screens/settings_screen.dart';
import 'package:transconnect/navigation/scaffold_with_nav_bar.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  initialLocation: '/home',
  navigatorKey: _rootNavigatorKey,
  refreshListenable: GoRouterRefreshStream(AuthService().authStateChanges),
  redirect: (context, state) {
    final authService = AuthService();
    final isLoggedIn = authService.currentUser != null;
    final location = state.matchedLocation;

    final isAuthRoute =
        location == '/welcome' || location == '/signin' || location == '/register';

    if (!isLoggedIn && !isAuthRoute) {
      return '/welcome';
    }

    if (isLoggedIn && isAuthRoute) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityScreen(),
              routes: [
                GoRoute(
                  path: ':channelId',
                  builder: (context, state) {
                    final channelId = state.pathParameters['channelId']!;
                    return ChatScreen(channelId: channelId);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/resources',
              builder: (context, state) => const ResourcesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
