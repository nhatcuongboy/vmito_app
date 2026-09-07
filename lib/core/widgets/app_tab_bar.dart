import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';

/// A styled TabBar wrapper that provides consistent styling across the app.
///
/// This widget wraps a [TabBar] with a bottom border decoration and applies
/// standard styling including:
/// - Bottom border using theme colors (AppPalette.border or dividerColor)
/// - Transparent divider color to avoid double borders
/// - Full-width tab indicators (TabBarIndicatorSize.tab)
/// - Primary color for the active tab indicator
///
/// Usage:
/// ```dart
/// AppBar(
///   bottom: AppTabBar(
///     tabs: [
///       Tab(text: 'Tab 1'),
///       Tab(text: 'Tab 2'),
///     ],
///   ),
/// )
/// ```
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({
    required this.tabs,
    this.controller,
    this.onTap,
    this.isScrollable = false,
    super.key,
  });

  /// The list of tabs to display.
  final List<Widget> tabs;

  /// Optional controller for managing tab state.
  final TabController? controller;

  /// Optional callback when a tab is tapped.
  final ValueChanged<int>? onTap;

  /// Whether the tabs should be scrollable (default: false).
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        theme.extension<AppPalette>()?.border ?? theme.dividerColor;

    return PreferredSize(
      preferredSize: preferredSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: TabBar(
          controller: controller,
          onTap: onTap,
          isScrollable: isScrollable,
          dividerColor: Colors.transparent,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: tabs,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
}
