import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Standard bottom sheet action-button area: surface background, a top
/// border separating it from scrollable content, and safe-area/keyboard
/// aware bottom padding.
///
/// [applySafeArea] should stay true for footers docked at the physical
/// bottom of the sheet (the common case). Sheets that already reserve their
/// own bottom inset (e.g. a scrolling form sheet padded for the keyboard)
/// can pass false to avoid reserving it twice.
class AppSheetActionBar extends StatelessWidget {
  const AppSheetActionBar({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.applySafeArea = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: applySafeArea && !keyboardOpen
          ? SafeArea(top: false, child: child)
          : child,
    );
  }
}
