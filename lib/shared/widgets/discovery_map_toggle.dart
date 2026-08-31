import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Compact floating action for changing a discovery result between list and
/// map modes. It always describes the destination mode.
class DiscoveryMapToggle extends StatelessWidget {
  const DiscoveryMapToggle({
    required this.showMap,
    required this.onPressed,
    super.key,
  });

  final bool showMap;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = showMap ? l10n.discoveryMapShowList : l10n.discoveryMapShow;
    final icon = showMap ? AppIcons.list : AppIcons.mapPin;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.primary,
        elevation: 5,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.32),
        side: BorderSide(color: theme.dividerColor),
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
