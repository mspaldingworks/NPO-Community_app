import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/pages/auth/register_screen.dart';
import 'package:transconnect/pages/auth/signin_screen.dart';
import 'package:transconnect/pages/auth/welcome_screen.dart';
import 'package:transconnect/features/community/screens/chat_screen.dart';
import 'package:transconnect/features/community/screens/community_screen.dart';
import 'package:transconnect/features/community/screens/post_detail_screen.dart';
import 'package:transconnect/features/community/screens/post_list_screen.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/pages/dashboard/dashboard_screen.dart';
import 'package:transconnect/features/profile/screens/profile_screen.dart';
import 'package:transconnect/pages/resources/resources_screen.dart';
import 'package:transconnect/pages/resources/create_resource_screen.dart';
import 'package:transconnect/features/settings/screens/settings_screen.dart';
import 'package:transconnect/navigation/scaffold_with_nav_bar.dart';
import 'package:transconnect/features/events/screens/calendar_screen.dart';
import 'package:transconnect/features/friends/screens/user_search_screen.dart';
import 'package:transconnect/features/chat/screens/chat_list_screen.dart';
import 'package:transconnect/features/chat/screens/chat_message_screen.dart';

class AppRouter {
  final AuthService authService;
  late final GoRouter router;

  AppRouter({required this.authService}) {
    router = GoRouter(
      initialLocation: '/home',
      navigatorKey: _rootNavigatorKey,
      refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
      redirect: (context, state) async {
        if (state.matchedLocation == '/') {
          return '/home';
        }

        final isLoggedIn = await authService.isUserAuthenticated();
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
      routes: _routes,
    );
  }
}

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

final List<RouteBase> _routes = [
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
  GoRoute(
    path: '/chat/:channelId',
    builder: (context, state) {
      final channelId = state.pathParameters['channelId']!;
      return ChatScreen(channelId: channelId);
    },
  ),
  GoRoute(
    path: '/user-search',
    builder: (context, state) => const UserSearchScreen(),
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
                path: ':groupId',
                builder: (context, state) {
                  final groupId = int.parse(state.pathParameters['groupId']!);
                  final groupName = state.extra as String? ?? 'Group';
                  return PostListScreen(
                    groupId: groupId,
                    groupName: groupName,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'posts/:postId',
                    builder: (context, state) {
                      final post = state.extra as Post;
                      return PostDetailScreen(post: post);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':conversationId',
                builder: (context, state) {
                  final conversationId = state.pathParameters['conversationId']!;
                  return ChatMessageScreen(conversationId: conversationId);
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
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateResourceScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
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
  GoRoute(
    path: '/calendar',
    builder: (context, state) => const CalendarScreen(),
  ),
];
