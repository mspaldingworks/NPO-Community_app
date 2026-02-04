import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/pages/auth/signin_screen.dart';
import 'package:transconnect/pages/auth/register_screen.dart';
import 'package:transconnect/pages/auth/onboarding_screen.dart';
import 'package:transconnect/pages/auth/video_splash_screen.dart';
import 'package:transconnect/pages/chat/chat_list_screen.dart';
import 'package:transconnect/pages/chat/chat_message_screen.dart';
import 'package:transconnect/pages/chat/create_conversation_screen.dart';
import 'package:transconnect/pages/chat/select_friends_for_chat_screen.dart';
import 'package:transconnect/pages/community/community_screen.dart';
import 'package:transconnect/pages/community/post_list_screen.dart';
import 'package:transconnect/pages/community/create_post_screen.dart';
import 'package:transconnect/pages/community/post_detail_screen.dart';
import 'package:transconnect/pages/community/edit_post_screen.dart';
import 'package:transconnect/pages/community/regional_chats_screen.dart';
import 'package:transconnect/pages/community/gender_chats_screen.dart';
import 'package:transconnect/pages/community/wellness_screen.dart';
import 'package:transconnect/pages/community/photo_album_screen.dart';
import 'package:transconnect/pages/community/politics_screen.dart';
import 'package:transconnect/pages/friends/user_search_screen.dart';
import 'package:transconnect/pages/dev/chat_test_screen.dart';
import 'package:transconnect/navigation/scaffold_with_nav_bar.dart';
import 'package:transconnect/pages/dashboard/dashboard_screen.dart';
import 'package:transconnect/pages/exchange/exchange_hub_screen.dart';
import 'package:transconnect/pages/exchange/create_exchange_post_screen.dart';
import 'package:transconnect/pages/exchange/exchange_post_detail_screen.dart';
import 'package:transconnect/pages/resources/create_resource_screen.dart';
import 'package:transconnect/pages/resources/edit_resource_screen.dart';
import 'package:transconnect/pages/resources/resources_screen.dart';
import 'package:transconnect/features/migration_planner/presentation/migration_planner_screen.dart';
import 'package:transconnect/pages/profile/profile_screen.dart';
import 'package:transconnect/pages/profile/public_user_profile_screen.dart';
import 'package:transconnect/pages/settings/app_info_screen.dart';
import 'package:transconnect/pages/settings/settings_screen.dart';
import 'package:transconnect/models/resource.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/pages/forms/lgl_form_screen.dart';
import 'package:transconnect/pages/events/calendar_screen.dart';
import 'package:transconnect/pages/admin/moderation_screen.dart';
import 'package:transconnect/features/geocaching/models/geopoint.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';
import 'package:transconnect/features/geocaching/screens/cache_details_screen.dart';
import 'package:transconnect/features/geocaching/screens/cache_admin_screen.dart';
import 'package:transconnect/features/geocaching/screens/geocache_filter_screen.dart';
import 'package:transconnect/features/geocaching/screens/geocache_list_screen.dart';
import 'package:transconnect/features/geocaching/screens/place_cache_screen.dart';
import 'package:transconnect/features/meadow/screens/meadow_screen.dart';

class AppRouter {
  final AuthService authService;

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  AppRouter({required this.authService});

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
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
              return ChatMessageScreen(conversationId: conversationId);
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
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CommunityScreen()),
                routes: [
                  GoRoute(
                    path: 'regional',
                    builder: (context, state) => const RegionalChatsScreen(),
                  ),
                  GoRoute(
                    path: 'gender',
                    redirect: (context, state) => '/community/identity',
                  ),
                  GoRoute(
                    path: 'identity',
                    builder: (context, state) => const GenderChatsScreen(),
                    routes: [
                      GoRoute(
                        path: 'general',
                        builder: (context, state) => const GeneralChatsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'legal',
                    builder: (context, state) => const LegalChatsScreen(),
                  ),
                  GoRoute(
                    path: 'sexual-health',
                    redirect: (context, state) => '/community/wellness',
                  ),
                  GoRoute(
                    path: 'wellness',
                    builder: (context, state) => const WellnessScreen(),
                  ),
                  GoRoute(
                    path: 'photo-album',
                    builder: (context, state) => const PhotoAlbumScreen(),
                  ),
                  GoRoute(
                    path: 'politics',
                    builder: (context, state) => const PoliticsScreen(),
                  ),
                  GoRoute(
                    path: 'mutual-aid',
                    redirect: (context, state) => '/exchange',
                  ),
                  GoRoute(
                    path: 'group/:id',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final groupName = state.extra as String? ?? 'Group';

                      final lowered = groupName.trim().toLowerCase();
                      final isGeneral = lowered == 'general'
                          || lowered == 'general chat'
                          || lowered.startsWith('general ')
                          || lowered == 'the meadow'
                          || lowered == 'meadow';
                      if (isGeneral) {
                        return MeadowScreen(groupId: id, groupName: groupName);
                      }

                      return PostListScreen(groupId: id, groupName: groupName);
                    },
                    routes: [
                      GoRoute(
                        path: 'create-post',
                        builder: (context, state) {
                          final groupId = int.parse(
                            state.pathParameters['id']!,
                          );
                          return CreatePostScreen(groupId: groupId);
                        },
                      ),
                      GoRoute(
                        path: 'post/:postId',
                        builder: (context, state) {
                          final groupId = int.parse(
                            state.pathParameters['id']!,
                          );
                          final postId = int.parse(
                            state.pathParameters['postId']!,
                          );
                          return PostDetailScreen(
                            groupId: groupId,
                            postId: postId,
                          );
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
          // Exchange
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exchange',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ExchangeHubScreen()),
                routes: [
                  GoRoute(
                    path: 'help',
                    redirect: (context, state) => '/exchange',
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) =>
                        const CreateExchangePostScreen(),
                  ),
                  GoRoute(
                    path: 'post/:postId',
                    builder: (context, state) {
                      final postId = int.parse(state.pathParameters['postId']!);
                      return ExchangePostDetailScreen(
                        postId: postId,
                        initialPost: state.extra as Post?,
                      );
                    },
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
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
                routes: [
                  GoRoute(
                    path: 'feed',
                    redirect: (context, state) => '/exchange',
                  ),
                ],
              ),
            ],
          ),
          // Resources
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ResourcesScreen()),
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
                  GoRoute(
                    path: 'migration',
                    builder: (context, state) => const MigrationPlannerScreen(),
                  ),
                ],
              ),
            ],
          ),
          // The Meadow + Events (reachable from Home cards)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meadow',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MeadowScreen(
                    groupId: 0,
                    groupName: 'The Meadow',
                  ),
                ),
              ),
              GoRoute(
                path: '/events/calendar',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CalendarScreen()),
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
        path: '/profile/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/info',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppInfoScreen(),
      ),
      GoRoute(
        path: '/users/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = int.parse(state.pathParameters['id']!);
          return PublicUserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/forms/lgl',
        builder: (context, state) => const LglFormScreen(),
      ),

      GoRoute(
        path: '/admin/moderation',
        builder: (context, state) => const ModerationScreen(),
      ),

      GoRoute(
        path: '/geocaching',
        builder: (context, state) => const GeocacheListScreen(),
        routes: [
          GoRoute(
            path: 'admin',
            builder: (context, state) => const CacheAdminScreen(),
          ),
          GoRoute(
            path: 'filters',
            builder: (context, state) {
              final initial = state.extra as GeocacheQuery;
              return GeocacheFilterScreen(initial: initial);
            },
          ),
          GoRoute(
            path: 'place',
            builder: (context, state) {
              final location = state.extra as GeoPoint;
              return PlaceCacheScreen(location: location);
            },
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PlaceCacheScreen(cacheId: id);
            },
          ),
          GoRoute(
            path: 'cache/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CacheDetailsScreen(cacheId: id);
            },
          ),
        ],
      ),

      // Development-only routes
      if (const bool.fromEnvironment('dart.vm.product') == false)
        GoRoute(
          path: '/dev/chat-test',
          builder: (context, state) => const ChatTestScreen(),
        ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = authService.currentUser != null;
      final String location = state.matchedLocation;
      final bool onAuthRoute = location == '/login' || location == '/signup';
      final bool onSplashOrOnboarding =
          location == '/splash' || location == '/onboarding';

      const adminUsernames = <String>['Mad.E', 'Mad.E.Made', 'pmaxwell'];
      final isAdmin = adminUsernames.contains(
        authService.currentUser?.username,
      );

      if (!loggedIn && !onAuthRoute && !onSplashOrOnboarding) {
        return '/splash';
      }
      if (loggedIn && (onAuthRoute || onSplashOrOnboarding)) {
        return '/home';
      }

      if (location.startsWith('/admin') && !isAdmin) {
        return '/home';
      }

      if (location.startsWith('/geocaching/admin') && !isAdmin) {
        return '/geocaching';
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
