import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class AppSortOption<T> {
  const AppSortOption({
    required this.value,
    required this.label,
    required this.icon,
    this.keyValue,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? keyValue;
}

class AppSortSelector extends StatelessWidget {
  const AppSortSelector({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.buttonKey,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final foregroundColor = isActive
        ? theme.colorScheme.primary
        : palette.mutedForeground;

    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        foregroundColor: foregroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(AppIcons.chevronDown, size: 14),
        ],
      ),
    );
  }
}

Future<T?> showAppSortSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<AppSortOption<T>> options,
  String keyPrefix = 'home-sort',
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(title: title, showCloseButton: false),
          for (final option in options)
            Builder(
              builder: (context) {
                final isSelected = option.value == selected;
                final foregroundColor = isSelected
                    ? theme.colorScheme.primary
                    : palette.mutedForeground;
                return ListTile(
                  key: ValueKey(
                    '$keyPrefix-${option.keyValue ?? option.value}',
                  ),
                  leading: Icon(option.icon, color: foregroundColor),
                  title: Text(
                    option.label,
                    style: TextStyle(color: foregroundColor),
                  ),
                  trailing: isSelected
                      ? Icon(AppIcons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                );
              },
            ),
        ],
      ),
    );
  },
);
