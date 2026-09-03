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
    this.iconSize = 15,
    this.padding = const EdgeInsets.all(5.5),
    this.margin = const EdgeInsets.all(AppSpacing.sm),
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Alignment alignment;
  final Color? background;
  final Color? foreground;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: margin,
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
                  padding: padding,
                  child: Icon(
                    icon,
                    size: iconSize,
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
