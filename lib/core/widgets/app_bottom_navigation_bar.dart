import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';

/// The shared five-destination bottom navigation used across the app.
///
/// Besides keeping contextual navigation visually aligned with the main app
/// shell, this wrapper owns the surface border and the Vietnamese-label text
/// scaling constraint. Selection visuals and accessibility semantics remain
/// delegated to Material's [NavigationBar].
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        theme.extension<AppPalette>()?.border ?? theme.dividerColor;

    final clampedIndex = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: NavigationBar(
          maintainBottomViewPadding: true,
          selectedIndex: clampedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      ),
    );
  }
}
