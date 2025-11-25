import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/pages/auth/signin_screen.dart';
import 'package:transconnect/pages/auth/register_screen.dart';
import 'package:transconnect/pages/auth/onboarding_screen.dart';
import 'package:transconnect/pages/auth/video_splash_screen.dart';
import 'package:transconnect/features/chat/screens/chat_list_screen.dart';
import 'package:transconnect/features/chat/screens/chat_message_screen.dart';
import 'package:transconnect/features/chat/screens/create_conversation_screen.dart';
import 'package:transconnect/features/chat/screens/select_friends_for_chat_screen.dart';
import 'package:transconnect/models/conversation.dart';
import 'package:transconnect/features/community/screens/community_screen.dart';
import 'package:transconnect/features/community/screens/post_list_screen.dart';
import 'package:transconnect/features/community/screens/create_post_screen.dart';
import 'package:transconnect/features/community/screens/post_detail_screen.dart';
import 'package:transconnect/features/community/screens/edit_post_screen.dart';
import 'package:transconnect/features/friends/screens/user_search_screen.dart';
import 'package:transconnect/navigation/scaffold_with_nav_bar.dart';
import 'package:transconnect/pages/dashboard/dashboard_screen.dart';
import 'package:transconnect/pages/resources/create_resource_screen.dart';
import 'package:transconnect/pages/resources/edit_resource_screen.dart';
import 'package:transconnect/pages/resources/resources_screen.dart';
import 'package:transconnect/features/profile/screens/profile_screen.dart';
import 'package:transconnect/models/resource.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/pages/forms/lgl_form_screen.dart';
import 'package:transconnect/features/events/screens/calendar_screen.dart';

class AppRouter {
  final AuthService authService;

  AppRouter({required this.authService});

  late final GoRouter router = GoRouter(
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const VideoSplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/user-search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => ChatListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateConversationScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final conversationId = state.pathParameters['id']!;
              final conversation = state.extra is Conversation
                  ? state.extra as Conversation
                  : null;
              return ChatMessageScreen(
                conversationId: conversationId,
                conversation: conversation,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/select-friends-for-chat',
        builder: (context, state) => const SelectFriendsForChatScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Community
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CommunityScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'group/:id',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final groupName = state.extra as String? ?? 'Group';
                      return PostListScreen(groupId: id, groupName: groupName);
                    },
                    routes: [
                      GoRoute(
                        path: 'create-post',
                        builder: (context, state) {
                          final groupId = int.parse(state.pathParameters['id']!);
                          return CreatePostScreen(groupId: groupId);
                        },
                      ),
                      GoRoute(
                        path: 'post/:postId',
                        builder: (context, state) {
                          final groupId = int.parse(state.pathParameters['id']!);
                          final postId = int.parse(state.pathParameters['postId']!);
                          return PostDetailScreen(groupId: groupId, postId: postId);
                        },
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (context, state) {
                              final post = state.extra as Post;
                              return EditPostScreen(post: post);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),
          // Events
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events/calendar',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CalendarScreen(),
                ),
              ),
            ],
          ),
          // Resources
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ResourcesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateResourceScreen(),
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final resource = state.extra as Resource;
                      return EditResourceScreen(resource: resource);
                    },
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
      ),
      GoRoute(
        path: '/forms/lgl',
        builder: (context, state) => const LglFormScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = authService.currentUser != null;
      final String location = state.matchedLocation;
      final bool onAuthRoute = location == '/login' || location == '/signup';
      final bool onSplashOrOnboarding = location == '/splash' || location == '/onboarding';

      if (!loggedIn && !onAuthRoute && !onSplashOrOnboarding) {
        return '/splash';
      }
      if (loggedIn && (onAuthRoute || onSplashOrOnboarding)) {
        return '/home';
      }
      return null;
    },
  );
}

// Helper class to bridge a Stream to a Listenable for GoRouter.
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