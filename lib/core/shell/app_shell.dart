import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/bottom_bar_scroll_visibility_controller.dart';
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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  // A router rebuild can keep the previous shell alive for one frame. This
  // key therefore belongs to a shell instance rather than being app-global.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _bottomBarVisibility = BottomBarScrollVisibilityController();
  Listenable? _routerDelegate;
  bool _navigationRefreshScheduled = false;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routerDelegate = GoRouter.of(context).routerDelegate;
    if (!identical(_routerDelegate, routerDelegate)) {
      _routerDelegate?.removeListener(_handleNavigationChanged);
      _routerDelegate = routerDelegate..addListener(_handleNavigationChanged);
    }

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_keyboardVisible == keyboardVisible) return;
    _keyboardVisible = keyboardVisible;
    _bottomBarVisibility.updateKeyboardVisibility(
      isVisible: keyboardVisible,
    );
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _bottomBarVisibility.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routerDelegate?.removeListener(_handleNavigationChanged);
    _bottomBarVisibility.dispose();
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    final index = widget.navigationShell.currentIndex;
    final isAtTabRoot =
        GoRouterState.of(context).uri.path ==
        AppRoutes.shellDestinations[index];
    if (!isAtTabRoot) return;
    unawaited(
      ref.read(tabReselectionControllerProvider).handleReselect(index),
    );
  }

  void _handleNavigationChanged() {
    if (_navigationRefreshScheduled) return;
    _navigationRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final isSignedIn = ref.watch(isSignedInProvider);
    final sessionIdentity = ref.watch(
      authControllerProvider.select((auth) => (auth.status, auth.user?.id)),
    );
    final location = GoRouterState.of(context).uri.path;
    final shouldKeepBottomBarVisible = location == AppRoutes.notifications;
    final shouldHideBottomBar = AppRoutes.hidesBottomNavigation(location);

    return ProviderScope(
      // Recreate screen-local snapshots and scroll positions at every account
      // boundary. Provider state is cleared separately by session cleanup.
      key: ValueKey(sessionIdentity),
      overrides: [
        appShellScaffoldKeyProvider.overrideWithValue(_scaffoldKey),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const SlideOutMenu(),
        // A child route's page transition owns the edge while it can pop. At
        // a branch root the same drag is available to open the menu instead.
        drawerEnableOpenDragGesture: !GoRouter.of(context).canPop(),
        drawerScrimColor: Colors.black.withValues(alpha: 0.6),
        body: NotificationListener<ScrollMetricsNotification>(
          onNotification: shouldKeepBottomBarVisible
              ? (_) => false
              : _bottomBarVisibility.handleMetricsNotification,
          child: NotificationListener<ScrollNotification>(
            onNotification: shouldKeepBottomBarVisible
                ? (_) => false
                : _bottomBarVisibility.handleScrollNotification,
            child: widget.navigationShell,
          ),
        ),
        bottomNavigationBar: isSignedIn && !shouldHideBottomBar
            ? ValueListenableBuilder<bool>(
                valueListenable: _bottomBarVisibility,
                builder: (context, scrollWantsBarVisible, child) {
                  final visible =
                      shouldKeepBottomBarVisible || scrollWantsBarVisible;
                  final duration = _keyboardVisible
                      ? Duration.zero
                      : const Duration(milliseconds: 220);
                  return ClipRect(
                    child: AnimatedAlign(
                      key: const Key('app-bottom-navigation-reveal'),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      heightFactor: visible ? 1 : 0,
                      child: AnimatedSlide(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        offset: visible ? Offset.zero : const Offset(0, 1),
                        child: child,
                      ),
                    ),
                  );
                },
                child: DecoratedBox(
                  key: const Key('app-bottom-navigation-surface'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: palette.border),
                    ),
                  ),
                  // `NavigationBar` clamps labels at 1.3x, which still wraps
                  // five Vietnamese labels on a narrow phone. Labels are
                  // redundant with the icons, so cap them lower here.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
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
                          icon: const Icon(AppIcons.calendarClock),
                          label: l10n.navSessions,
                        ),
                        NavigationDestination(
                          icon: const NewsfeedBadgeIcon(icon: AppIcons.feed),
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
    // `SystemSoundType.click` is a no-op on iOS; selection haptics fire on both.
    unawaited(HapticFeedback.selectionClick());

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
