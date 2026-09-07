import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Drag handle for sheets Flutter's `showDragHandle` can't reach — i.e. a
/// `DraggableScrollableSheet` returned directly from a modal builder.
///
/// Only put this on tall/resizable sheets; small fixed-height confirm sheets
/// don't resize and don't need one.
class AppSheetGrabber extends StatelessWidget {
  const AppSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).extension<AppPalette>()!.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
