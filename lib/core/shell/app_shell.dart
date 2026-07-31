import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Bottom-navigation shell.
///
/// Wraps a `StatefulShellRoute`, so each tab keeps its own navigation stack and
/// scroll position — switching to Profile and back returns to the same place in
/// the session list, which a plain `IndexedStack` of screens would not do.
///
/// The shell exists from the start on purpose: retrofitting one means rewriting
/// every route, because `StatefulShellRoute` has to own its branches.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Scaffold(
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
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.sports_tennis_outlined),
              selectedIcon: const Icon(Icons.sports_tennis_rounded),
              label: l10n.navSessions,
            ),
            NavigationDestination(
              icon: const Icon(Icons.article_outlined),
              selectedIcon: const Icon(Icons.article_rounded),
              label: l10n.navFeed,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
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
