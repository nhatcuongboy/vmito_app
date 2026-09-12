import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:vmito_app/features/auth/presentation/reset_password_screen.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/features/auth/presentation/sign_up_screen.dart';
import 'package:vmito_app/features/court/presentation/live_session_screen.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorites_screen.dart';
import 'package:vmito_app/features/feedback/presentation/feedback_screen.dart';
import 'package:vmito_app/features/home/presentation/home_screen.dart';
import 'package:vmito_app/features/home/presentation/home_search_screen.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:vmito_app/features/legal/presentation/legal_screen.dart';
import 'package:vmito_app/features/notification/presentation/notifications_screen.dart';
import 'package:vmito_app/features/payment/presentation/reminders_screen.dart';
import 'package:vmito_app/features/payment/presentation/transaction_dashboard_screen.dart';
import 'package:vmito_app/features/profile/presentation/account_security_screen.dart';
import 'package:vmito_app/features/profile/presentation/change_password_screen.dart';
import 'package:vmito_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:vmito_app/features/profile/presentation/profile_screen.dart';
import 'package:vmito_app/features/profile/presentation/settings_screen.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/player/browse_sessions_screen.dart';
import 'package:vmito_app/features/session/presentation/player/create_session_screen.dart';
import 'package:vmito_app/features/session/presentation/player/edit_session_screen.dart';
import 'package:vmito_app/features/session/presentation/player/my_sessions_search_screen.dart';
import 'package:vmito_app/features/session/presentation/player/session_detail_screen.dart';
import 'package:vmito_app/features/session_hosting/presentation/host_session_management_screen.dart';
import 'package:vmito_app/features/session_hosting/presentation/session_join_request_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/social/presentation/club_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/club_fee_screen.dart';
import 'package:vmito_app/features/social/presentation/club_form_screen.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_join_request_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/club_management_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/club_management_screen.dart';
import 'package:vmito_app/features/social/presentation/post_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/features/social/presentation/session_rating_screen.dart';
import 'package:vmito_app/features/social/presentation/social_hub_screen.dart';
import 'package:vmito_app/features/splash/presentation/splash_screen.dart';
import 'package:vmito_app/features/tournament/presentation/create_tournament_screen.dart';
import 'package:vmito_app/features/tournament/presentation/host_tournaments_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_detail_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_management_screen.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_screen.dart';

/// Keys the shell's own navigator so full-screen routes (splash, sign-in) can
/// push *above* the bottom bar rather than inside a tab.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's [GoRouter], refreshed in place whenever auth state changes.
///
/// `redirect` is the single gate: no screen checks auth for itself.
///
/// Layout is a `StatefulShellRoute` with one branch per bottom-nav
/// destination, so each tab keeps its own stack — opening a session from the
/// Sessions tab and switching to Profile and back returns to that session.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Recreating GoRouter resets its location to splash and loses the redirect
  // carried by a pushed sign-in page. Refresh the existing navigation stack.
  final authRefresh = ValueNotifier(ref.read(authControllerProvider));

  HomeDiscoveryTab? parseHomeDiscoveryTab(String? tab) => switch (tab) {
    'sessions' => HomeDiscoveryTab.sessions,
    'venues' => HomeDiscoveryTab.venues,
    'clubs' => HomeDiscoveryTab.clubs,
    'tournaments' => HomeDiscoveryTab.tournaments,
    _ => null,
  };

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authRefresh,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = AppRoutes.stripLocale(state.uri.path);

      // Tokens are still being read from the Keychain. Hold on the splash
      // screen rather than bouncing a signed-in user to sign-in.
      if (!auth.isResolved) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final normalizedLocation = AppRoutes.normalizeWebLocation(state.uri);
      if (normalizedLocation != state.uri.toString()) {
        return normalizedLocation;
      }

      if (auth.status == AuthStatus.authenticated) {
        // Signed in but sitting on splash or an auth screen — move on.
        if (location == AppRoutes.splash || location.startsWith('/auth/')) {
          final redirect = state.uri.queryParameters['redirect'];
          if (redirect != null && redirect.isNotEmpty) {
            return redirect;
          }
          return AppRoutes.home;
        }
        if (location == AppRoutes.transactions &&
            auth.user?.role != UserRole.host &&
            auth.user?.role != UserRole.admin) {
          return AppRoutes.home;
        }
        return null;
      }

      // Signed-out and join-code guests land on public discovery. Protected
      // session management requires a full account, not merely guest state.
      if (location == AppRoutes.splash) return AppRoutes.home;
      if (AppRoutes.isPublic(location)) return null;

      // An explicit logout starts a fresh navigation session. In contrast, a
      // session expiry or a login prompt keeps the requested route so the user
      // can resume the interrupted action after authenticating.
      if (auth.wasExplicitlySignedOut) return AppRoutes.signIn;

      return AppRoutes.signInWithRedirect(state.uri.toString());
    },
    routes: [
      GoRoute(
        path: AppRoutes.venues,
        redirect: (context, state) => state.uri.path == AppRoutes.venues
            ? AppRoutes.homeForDiscoveryTab(HomeDiscoveryTab.venues.name)
            : null,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BrowseVenuesScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                VenueDetailScreen(venueId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.clubs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BrowseClubsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ClubDetailScreen(clubId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.nameSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRoutes.nameSignIn,
        // Above the shell: sign-in has no bottom bar.
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SignInScreen(
          registrationCompleted: state.uri.queryParameters['registered'] == '1',
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: AppRoutes.nameSignUp,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        name: AppRoutes.nameFeedback,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        name: AppRoutes.nameTerms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LegalScreen(
          document: LegalDocument.terms,
        ),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        name: AppRoutes.namePrivacy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LegalScreen(
          document: LegalDocument.privacy,
        ),
      ),
      GoRoute(
        path: '/user/:id',
        name: AppRoutes.namePublicProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PublicProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.hostTournaments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HostTournamentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTournament,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final role = ref.read(authControllerProvider).user?.role;
          return role == UserRole.host || role == UserRole.admin
              ? null
              : AppRoutes.homeForDiscoveryTab('tournaments');
        },
        builder: (context, state) => const CreateTournamentScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.tournaments}/:id/manage',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TournamentManagementScreen(
          idOrSlug: state.pathParameters['id']!,
          initialOption: state.uri.queryParameters['option'],
          initialCategoryId: state.uri.queryParameters['categoryId'],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.tournaments}/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TournamentDetailScreen(
          idOrSlug: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/tournament/:id',
        redirect: (context, state) =>
            AppRoutes.tournamentDetail(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/:locale/tournament/:id',
        redirect: (context, state) =>
            AppRoutes.tournamentDetail(state.pathParameters['id']!),
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
                builder: (context, state) => HomeScreen(
                  initialVenueId: state.uri.queryParameters['venueId'],
                  initialVenueName: state.uri.queryParameters['venueName'],
                  initialDiscoveryTab: parseHomeDiscoveryTab(
                    state.uri.queryParameters[AppRoutes.homeDiscoveryTabQuery],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.homeSearchPath,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => HomeSearchScreen(
                      tab:
                          parseHomeDiscoveryTab(
                            state.uri.queryParameters[AppRoutes
                                .homeDiscoveryTabQuery],
                          ) ??
                          HomeDiscoveryTab.sessions,
                      initialQuery: state.uri.queryParameters['q'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.leaderboard,
                name: AppRoutes.nameLeaderboard,
                builder: (context, state) {
                  final parsed = LeaderboardPeriod.fromWire(
                    state.uri.queryParameters['period'],
                  );
                  final period = leaderboardPeriods.contains(parsed)
                      ? parsed
                      : LeaderboardPeriod.week;
                  return LeaderboardScreen(
                    initialPeriod: period,
                    initialPeriodKey: period == LeaderboardPeriod.all
                        ? null
                        : state.uri.queryParameters['periodKey'],
                  );
                },
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
                  // Off the shell: the form owns the bottom of the screen with
                  // its own submit bar, and stacking that on the 64pt tab bar
                  // would put the safe-area inset on the wrong one.
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CreateSessionScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.mySessionsSearchPath,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => MySessionsSearchScreen(
                      scope: switch (state.uri.queryParameters['scope']) {
                        'joined' => MySessionScope.joined,
                        _ => MySessionScope.hosted,
                      },
                      initialQuery: state.uri.queryParameters['q'] ?? '',
                    ),
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
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => EditSessionScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'clone',
                        parentNavigatorKey: rootNavigatorKey,
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
                              initialTab:
                                  state.uri.queryParameters['tab'] == 'roster'
                                  ? 1
                                  : 0,
                            ),
                      ),
                      GoRoute(
                        path: 'rate',
                        builder: (context, state) => SessionRatingScreen(
                          sessionId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'join-requests/:requestId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            SessionJoinRequestDetailScreen(
                              sessionId: state.pathParameters['id']!,
                              requestId: state.pathParameters['requestId']!,
                              canDecide:
                                  state.uri.queryParameters['role'] !=
                                  'applicant',
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
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ClubManagementScreen(
                      initialTab:
                          state.uri.queryParameters[AppRoutes
                              .clubManagementTabQuery] ??
                          'managing',
                    ),
                    routes: [
                      GoRoute(
                        path: 'create',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const ClubFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ClubManagementDetailScreen(
                          clubId: state.pathParameters['id']!,
                          initialTab:
                              state.uri.queryParameters['tab'] == 'requests'
                              ? 1
                              : 0,
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => ClubFormScreen(
                              clubId: state.pathParameters['id'],
                            ),
                          ),
                          GoRoute(
                            path: 'fees',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => ClubFeeScreen(
                              clubId: state.pathParameters['id']!,
                            ),
                          ),
                          GoRoute(
                            path: 'requests/:requestId',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) =>
                                ClubJoinRequestDetailScreen(
                                  clubId: state.pathParameters['id']!,
                                  requestId: state.pathParameters['requestId']!,
                                  canDecide:
                                      state.uri.queryParameters['role'] !=
                                      'applicant',
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'clubs/:id',
                    redirect: (context, state) =>
                        AppRoutes.clubDetail(state.pathParameters['id']!),
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
                path: AppRoutes.favorites,
                builder: (context, state) => FavoritesScreen(
                  initialType: FavoriteType.fromWire(
                    state.uri.queryParameters['type'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.nameProfile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: AppRoutes.nameEditProfile,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.nameSettings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'account-security',
                    name: AppRoutes.nameAccountSecurity,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AccountSecurityScreen(),
                    routes: [
                      GoRoute(
                        path: 'change-password',
                        name: AppRoutes.nameChangePassword,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            const ChangePasswordScreen(),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionDashboardScreen(),
              ),
              GoRoute(
                path: AppRoutes.reminders,
                name: AppRoutes.nameReminders,
                builder: (context, state) => const RemindersScreen(),
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
  ref
    ..listen(authControllerProvider, (_, next) {
      if (router.routerDelegate.currentConfiguration.isNotEmpty) {
        final currentUri = router.state.uri;
        final location = AppRoutes.stripLocale(currentUri.path);
        final leavingAuth =
            next.status == AuthStatus.authenticated &&
            location.startsWith('/auth/');
        final losingAccess =
            next.isResolved &&
            next.status != AuthStatus.authenticated &&
            !AppRoutes.isPublic(location);
        if (leavingAuth || losingAccess) {
          // Pushed pages are not the stack's base URI. Evaluate the visible
          // location through the redirect above after sign-in or session loss.
          router.go(currentUri.toString());
          return;
        }
      }
      authRefresh.value = next;
    })
    ..onDispose(() {
      router.dispose();
      authRefresh.dispose();
    });
  return router;
});
