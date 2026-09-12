import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// A compact pill chip shared by the popular-city row and the selected-ward
/// chips, so both read as the same size — either tappable to select
/// ([onTap]) or deletable ([onDeleted]), never both.
class CitySelectorCompactChip extends StatelessWidget {
  const CitySelectorCompactChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = theme.extension<AppPalette>()!;
    final isActive = selected || onDeleted != null;
    final content = Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm + 4,
        right: onDeleted != null ? AppSpacing.xs : AppSpacing.sm + 4,
        top: AppSpacing.xs + 2,
        bottom: AppSpacing.xs + 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isActive ? scheme.primary : scheme.onSurface,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            InkWell(
              onTap: onDeleted,
              customBorder: const CircleBorder(),
              child: Icon(AppIcons.close, size: 16, color: scheme.primary),
            ),
          ],
        ],
      ),
    );
    return Material(
      color: isActive ? scheme.primary.withValues(alpha: .12) : scheme.surface,
      shape: StadiumBorder(
        side: BorderSide(color: isActive ? scheme.primary : palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
