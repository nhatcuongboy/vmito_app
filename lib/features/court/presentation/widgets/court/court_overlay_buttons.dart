import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// A small circular button floating over the court.
///
/// Deliberately not a `FloatingActionButton`: these sit inside a card at
/// roughly a third of the size, and the court needs the contrast a solid dark
/// circle gives against any surface colour the host picked.
class CourtOverlayButton extends StatelessWidget {
  const CourtOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.alignment = Alignment.topLeft,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Alignment alignment;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: Material(
              color: background ?? Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: Padding(
                  // 32 px of icon plus padding: below the 48 px tap floor, so
                  // the InkWell's own splash area is widened by the Material.
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    icon,
                    size: 18,
                    color: foreground ?? palette.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
