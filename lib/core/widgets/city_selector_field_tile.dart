import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// The bordered "select" row used for the province and ward fields in the
/// location selector — same visual language as [AppAreaFilterSection]'s
/// city/district trigger tiles, so the two areas of the app read as one
/// component even though this one drives local state instead of a
/// `reactive_forms` control.
class CitySelectorFieldTile extends StatelessWidget {
  const CitySelectorFieldTile({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.onClear,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = theme.extension<AppPalette>()!;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? theme.colorScheme.surface
                : palette.muted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: !enabled
                  ? palette.border.withValues(alpha: 0.4)
                  : (hasValue ? scheme.primary : palette.border),
              width: hasValue ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: !enabled
                    ? palette.mutedForeground.withValues(alpha: 0.4)
                    : (hasValue ? scheme.primary : palette.mutedForeground),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: !enabled
                        ? palette.mutedForeground.withValues(alpha: 0.5)
                        : (hasValue
                              ? scheme.onSurface
                              : palette.mutedForeground),
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasValue && onClear != null)
                InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxs),
                    child: Icon(AppIcons.close, size: 18),
                  ),
                )
              else
                Icon(
                  AppIcons.chevronDown,
                  size: 18,
                  color: enabled
                      ? palette.mutedForeground
                      : palette.mutedForeground.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
