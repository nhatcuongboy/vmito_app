import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// A compact, inset group used by settings-style screens.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    this.title,
    super.key,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedForeground =
        theme.extension<AppPalette>()?.mutedForeground ??
        theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title case final title?) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: mutedForeground,
              ),
            ),
          ),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(
                    indent: AppSpacing.md + 36 + AppSpacing.sm + 4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A navigable row with optional current-value text.
class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedForeground =
        theme.extension<AppPalette>()?.mutedForeground ??
        theme.colorScheme.onSurfaceVariant;
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SettingsTileIcon(
                  icon: icon,
                  destructive: destructive,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (value case final value?) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedForeground,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: destructive
                      ? theme.colorScheme.error.withValues(alpha: 0.72)
                      : mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row that owns a boolean value.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    secondary: SettingsTileIcon(icon: icon),
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class SettingsTileIcon extends StatelessWidget {
  const SettingsTileIcon({
    required this.icon,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandSurface =
        theme.extension<AppPalette>()?.brandSurface ??
        theme.colorScheme.primary.withValues(alpha: 0.10);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final background = destructive
        ? theme.colorScheme.error.withValues(alpha: 0.10)
        : brandSurface;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: color),
    );
  }
}
