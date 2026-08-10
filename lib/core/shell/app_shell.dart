import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/slide_out_menu.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Bottom-navigation shell.
///
/// Wraps a `StatefulShellRoute`, so each tab keeps its own navigation stack and
/// scroll position — switching to Profile and back returns to the same place in
/// the session list, which a plain `IndexedStack` of screens would not do.
///
/// The shell exists from the start on purpose: retrofitting one means rewriting
/// every route, because `StatefulShellRoute` has to own its branches.
///
/// Also owns the [SlideOutMenu] drawer. Tab screens build their own nested
/// `Scaffold`s, so they open it through [appShellScaffoldKeyProvider] rather
/// than `Scaffold.of(context)`, which would resolve to their own Scaffold.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Scaffold(
      key: ref.watch(appShellScaffoldKeyProvider),
      drawer: const SlideOutMenu(),
      drawerScrimColor: Colors.black.withValues(alpha: 0.6),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(AppIcons.home),
              selectedIcon: const Icon(AppIcons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.sessions),
              selectedIcon: const Icon(AppIcons.sessions),
              label: l10n.navSessions,
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.feed),
              selectedIcon: const Icon(AppIcons.feed),
              label: l10n.navFeed,
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.notifications),
              selectedIcon: const Icon(AppIcons.notifications),
              label: l10n.navNotifications,
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.profile),
              selectedIcon: const Icon(AppIcons.profile),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // `initialLocation: true` when re-tapping the current tab pops it back to
    // its root — the behaviour every native app has, and the only way out of a
    // deep stack without hunting for the back button.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
