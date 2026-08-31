import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class DiscoverySortOption<T> {
  const DiscoverySortOption({required this.value, required this.label});

  final T value;
  final String label;
}

class HomeDiscoveryToolbar extends StatelessWidget {
  const HomeDiscoveryToolbar({
    required this.sortLabel,
    required this.onSort,
    required this.onFilter,
    required this.onCityChanged,
    this.filterCount = 0,
    super.key,
  });

  final String sortLabel;
  final VoidCallback onSort;
  final VoidCallback onFilter;
  final ValueChanged<String?> onCityChanged;
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelMaxWidth = ((constraints.maxWidth - 156) / 2).clamp(
                56.0,
                180.0,
              );
              return Row(
                children: [
                  CitySelector(
                    showLabel: true,
                    labelMaxWidth: labelMaxWidth,
                    onChanged: onCityChanged,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: labelMaxWidth + 50,
                    ),
                    child: OutlinedButton.icon(
                      key: const Key('home-discovery-sort'),
                      onPressed: onSort,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(AppIcons.sortAlpha, size: 18),
                      label: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: labelMaxWidth),
                        child: Text(
                          sortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: IconButton.outlined(
                      key: const Key('home-discovery-filter'),
                      tooltip: l10n.sessionFiltersTitle,
                      onPressed: onFilter,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(AppIcons.tune, size: 20),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<T?> showDiscoverySortSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<DiscoverySortOption<T>> options,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final option in options)
          ListTile(
            key: ValueKey('home-sort-${option.value}'),
            title: Text(option.label),
            trailing: option.value == selected
                ? Icon(
                    AppIcons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.of(context).pop(option.value),
          ),
      ],
    ),
  ),
);
