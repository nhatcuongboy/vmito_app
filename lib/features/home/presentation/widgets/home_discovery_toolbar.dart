import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_sort_selector.dart';

class HomeDiscoveryToolbar extends StatelessWidget {
  const HomeDiscoveryToolbar({
    required this.sortLabel,
    required this.sortIcon,
    required this.onSort,
    required this.onFilter,
    required this.onCityChanged,
    this.filterCount = 0,
    this.sortIsActive = false,
    super.key,
  });

  final String sortLabel;
  final IconData sortIcon;
  final VoidCallback onSort;
  final VoidCallback onFilter;
  final LocationChanged onCityChanged;
  final int filterCount;
  final bool sortIsActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final filterForeground = filterCount > 0
        ? theme.colorScheme.primary
        : palette.mutedForeground;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.transparent,
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
              final cityMaxWidth = constraints.maxWidth * 0.5;
              return Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cityMaxWidth),
                    child: CitySelector(
                      showLabel: true,
                      labelMaxWidth: (cityMaxWidth - 62).clamp(
                        0.0,
                        double.infinity,
                      ),
                      onChanged: onCityChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AppSortSelector(
                        buttonKey: const Key('home-discovery-sort'),
                        label: sortLabel,
                        icon: sortIcon,
                        isActive: sortIsActive,
                        onPressed: onSort,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: IconButton.outlined(
                      key: const Key('home-discovery-filter'),
                      tooltip: l10n.sessionFiltersTitle,
                      onPressed: onFilter,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: filterForeground,
                      ),
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
