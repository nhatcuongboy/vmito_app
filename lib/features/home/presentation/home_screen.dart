import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/session/presentation/player/public_sessions_content.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The app's discovery landing page.
///
/// It mirrors the web discovery navigation: sessions are the default content,
/// while venues, clubs and tournaments are fetched when their segment is
/// selected. A keyed subtree deliberately recreates the active browser on
/// every selection (including a re-tap), so the selected data is revalidated.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeDiscoveryTab _selectedTab = HomeDiscoveryTab.sessions;
  var _contentRevision = 0;
  bool _isFabExtended = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final discoveryHeader = HomeDiscoveryTabs(
      selected: _selectedTab,
      onSelected: (tab) => setState(() {
        _selectedTab = tab;
        _contentRevision++;
        _isFabExtended = true;
      }),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.menuOpenTooltip,
          icon: const Icon(AppIcons.menu),
          onPressed: () =>
              ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(_selectedTab.label(l10n)),
        actions: [
          if (isAuthenticated) ...[
            IconButton(
              tooltip: l10n.notificationsTitle,
              icon: const Icon(AppIcons.notifications),
              onPressed: () => context.go(AppRoutes.notifications),
            ),
            IconButton(
              tooltip: l10n.authSignOut,
              icon: const Icon(AppIcons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ] else
            IconButton(
              tooltip: l10n.authSignIn,
              icon: const Icon(AppIcons.login),
              onPressed: () => context.push(AppRoutes.signIn),
            ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.metrics.pixels <= 0) {
              if (!_isFabExtended) {
                setState(() => _isFabExtended = true);
              }
            } else if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isFabExtended) {
                  setState(() => _isFabExtended = false);
                }
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isFabExtended) {
                  setState(() => _isFabExtended = true);
                }
              }
            }
          }
          return false;
        },
        child: KeyedSubtree(
          key: ValueKey('${_selectedTab.name}-$_contentRevision'),
          child: switch (_selectedTab) {
            HomeDiscoveryTab.sessions => BrowseSessionsContent(
              discoveryHeader: discoveryHeader,
            ),
            HomeDiscoveryTab.venues => BrowseVenuesScreen(
              embedded: true,
              discoveryHeader: discoveryHeader,
            ),
            HomeDiscoveryTab.clubs => BrowseClubsScreen(
              embedded: true,
              discoveryHeader: discoveryHeader,
            ),
            HomeDiscoveryTab.tournaments => BrowseTournamentsContent(
              discoveryHeader: discoveryHeader,
            ),
          },
        ),
      ),
      floatingActionButton:
          (isAuthenticated && _selectedTab == HomeDiscoveryTab.sessions)
              ? SizedBox(
                  height: 40,
                  child: FloatingActionButton.extended(
                    key: const Key('home-create-session-fab'),
                    isExtended: _isFabExtended,
                    onPressed: () => context.push(AppRoutes.createSession),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 2,
                    extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    icon: const Icon(AppIcons.add, size: 18),
                    label: Text(
                      l10n.createSessionTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : null,
    );
  }
}
