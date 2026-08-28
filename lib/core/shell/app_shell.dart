import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/newsfeed_badge_icon.dart';
import 'package:vmito_app/core/widgets/slide_out_menu.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
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
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // A router rebuild can keep the previous shell alive for one frame. This
  // key therefore belongs to a shell instance rather than being app-global.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Any tab's list scrolling down hides the bar, matching Instagram/TikTok —
  // a fresh tab always starts with it visible.
  bool _navBarVisible = true;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      setState(() => _navBarVisible = true);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Swiping a horizontal PageView/TabBarView is not "scrolling the page".
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.reverse:
          if (_navBarVisible) setState(() => _navBarVisible = false);
        case ScrollDirection.forward:
          if (!_navBarVisible) setState(() => _navBarVisible = true);
        case ScrollDirection.idle:
          break;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final isSignedIn = ref.watch(isSignedInProvider);
    final location = GoRouterState.of(context).uri.path;
    final shouldKeepBottomBarVisible = location == AppRoutes.notifications;
    final shouldHideBottomBar = AppRoutes.hidesBottomNavigation(location);

    return ProviderScope(
      overrides: [
        appShellScaffoldKeyProvider.overrideWithValue(_scaffoldKey),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const SlideOutMenu(),
        drawerEnableOpenDragGesture: false,
        drawerScrimColor: Colors.black.withValues(alpha: 0.6),
        body: NotificationListener<ScrollNotification>(
          onNotification: shouldKeepBottomBarVisible
              ? (_) => false
              : _handleScrollNotification,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: isSignedIn && !shouldHideBottomBar
            ? ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: shouldKeepBottomBarVisible || _navBarVisible
                      ? 1
                      : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: palette.border)),
                    ),
                    child: NavigationBar(
                      maintainBottomViewPadding: true,
                      selectedIndex: widget.navigationShell.currentIndex,
                      onDestinationSelected: _onDestinationSelected,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(AppIcons.home),
                          label: l10n.navHome,
                        ),
                        NavigationDestination(
                          icon: const Icon(AppIcons.sessions),
                          label: l10n.navSessions,
                        ),
                        NavigationDestination(
                          icon: NewsfeedBadgeIcon(
                            icon: AppIcons.feed,
                            semanticLabel: l10n.navFeed,
                          ),
                          selectedIcon: NewsfeedBadgeIcon(
                            icon: AppIcons.feed,
                            semanticLabel: l10n.navFeed,
                          ),
                          label: l10n.navFeed,
                        ),
                        NavigationDestination(
                          icon: const Icon(AppIcons.favorite),
                          label: l10n.navFavorites,
                        ),
                        NavigationDestination(
                          icon: const Icon(AppIcons.profile),
                          label: l10n.navProfile,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _onDestinationSelected(int index) {
    final isCurrentTab = index == widget.navigationShell.currentIndex;
    final isAtTabRoot =
        GoRouterState.of(context).uri.path ==
        AppRoutes.shellDestinations[index];

    if (isCurrentTab && isAtTabRoot) {
      unawaited(
        ref.read(tabReselectionControllerProvider).handleReselect(index),
      );
      return;
    }

    // `initialLocation: true` when re-tapping the current tab pops it back to
    // its root — the behaviour every native app has, and the only way out of a
    // deep stack without hunting for the back button.
    widget.navigationShell.goBranch(
      index,
      initialLocation: isCurrentTab,
    );
  }
}
