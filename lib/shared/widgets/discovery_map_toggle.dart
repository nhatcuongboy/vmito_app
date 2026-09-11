import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Compact floating action for changing a discovery result between list and
/// map modes. It always describes the destination mode.
class DiscoveryMapToggle extends StatelessWidget {
  const DiscoveryMapToggle({
    required this.showMap,
    required this.onPressed,
    this.isExtended = true,
    super.key,
  });

  final bool showMap;
  final VoidCallback onPressed;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final l10n = AppLocalizations.of(context);
    final label = showMap ? l10n.discoveryMapShowList : l10n.discoveryMapShow;
    final icon = showMap ? AppIcons.list : AppIcons.mapPin;
    final backgroundColor = palette?.brandSurface ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF183028)
            : const Color(0xFFE2F3E8));
    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.35);

    return Tooltip(
      message: label,
      child: SizedBox(
        height: 44,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            backgroundColor: backgroundColor,
            foregroundColor: theme.colorScheme.primary,
            elevation: 4,
            shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.25),
            side: BorderSide(color: borderColor),
            shape: const StadiumBorder(),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                if (isExtended)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
