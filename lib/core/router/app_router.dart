import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:vmito_app/features/auth/presentation/reset_password_screen.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/features/auth/presentation/sign_up_screen.dart';
import 'package:vmito_app/features/home/presentation/home_screen.dart';
import 'package:vmito_app/features/live_session/presentation/live_session_screen.dart';
import 'package:vmito_app/features/notification/presentation/notifications_screen.dart';
import 'package:vmito_app/features/profile/presentation/profile_screen.dart';
import 'package:vmito_app/features/session/presentation/browse_sessions_screen.dart';
import 'package:vmito_app/features/session/presentation/create_session_screen.dart';
import 'package:vmito_app/features/session/presentation/edit_session_screen.dart';
import 'package:vmito_app/features/session/presentation/host_session_management_screen.dart';
import 'package:vmito_app/features/session/presentation/session_detail_screen.dart';
import 'package:vmito_app/features/session/presentation/transaction_dashboard_screen.dart';
import 'package:vmito_app/features/social/presentation/club_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/club_form_screen.dart';
import 'package:vmito_app/features/social/presentation/club_management_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/club_management_screen.dart';
import 'package:vmito_app/features/social/presentation/post_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/features/social/presentation/session_rating_screen.dart';
import 'package:vmito_app/features/social/presentation/social_hub_screen.dart';
import 'package:vmito_app/features/splash/presentation/splash_screen.dart';

/// Keys the shell's own navigator so full-screen routes (splash, sign-in) can
/// push *above* the bottom bar rather than inside a tab.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's [GoRouter], rebuilt whenever auth status changes.
///
/// `redirect` is the single gate: no screen checks auth for itself.
///
/// Layout is a `StatefulShellRoute` with one branch per bottom-nav
/// destination, so each tab keeps its own stack — opening a session from the
/// Sessions tab and switching to Profile and back returns to that session.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = AppRoutes.stripLocale(state.matchedLocation);

      // Tokens are still being read from the Keychain. Hold on the splash
      // screen rather than bouncing a signed-in user to sign-in.
      if (!auth.isResolved) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (auth.isSignedIn) {
        // Signed in but sitting on splash or an auth screen — move on.
        if (location == AppRoutes.splash || location.startsWith('/auth/')) {
          return AppRoutes.home;
        }
        return null;
      }

      // Signed out but browsing is allowed. Land on the sessions tab rather
      // than home, which has nothing to show without an account.
      if (location == AppRoutes.splash) return AppRoutes.browseSessions;
      if (AppRoutes.isPublic(location)) return null;

      return AppRoutes.signIn;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.nameSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRoutes.nameSignIn,
        // Above the shell: sign-in has no bottom bar.
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SignInScreen(
          registrationCompleted: state.uri.queryParameters['registered'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: AppRoutes.nameSignUp,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TransactionDashboardScreen(),
      ),
      GoRoute(
        path: '/user/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PublicProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),

      // Branch order must match AppRoutes.shellDestinations — go_router
      // identifies a branch by index, not by path.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.nameHome,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.browseSessions,
                builder: (context, state) => const BrowseSessionsScreen(),
                routes: [
                  // Declared before ':id' — go_router matches in order, so the
                  // parameterised route would otherwise capture "create".
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateSessionScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: AppRoutes.nameSessionDetail,
                    builder: (context, state) => SessionDetailScreen(
                      sessionId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EditSessionScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'clone',
                        builder: (context, state) => EditSessionScreen(
                          sessionId: state.pathParameters['id']!,
                          isClone: true,
                        ),
                      ),
                      GoRoute(
                        path: 'manage',
                        builder: (context, state) =>
                            HostSessionManagementScreen(
                              sessionId: state.pathParameters['id']!,
                            ),
                      ),
                      GoRoute(
                        path: 'rate',
                        builder: (context, state) => SessionRatingScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'live',
                        name: AppRoutes.nameLiveSession,
                        builder: (context, state) => LiveSessionScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
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
                path: AppRoutes.feed,
                builder: (context, state) => const SocialHubScreen(),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (context, state) => const ClubManagementScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) => const ClubFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ClubManagementDetailScreen(
                          clubId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            builder: (context, state) => ClubFormScreen(
                              clubId: state.pathParameters['id'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'clubs/:id',
                    builder: (context, state) => ClubDetailScreen(
                      clubId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':postId',
                    builder: (context, state) => PostDetailScreen(
                      postId: state.pathParameters['postId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
