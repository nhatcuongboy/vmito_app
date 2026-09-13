import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/city_selector_field_tile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_area_filter_section.dart'
    show AppAreaFilterSection;
import 'package:vmito_app/shared/widgets/ward_selection_summary.dart';

/// The ward/commune/special-zone field: a trigger tile summarizing the
/// selection by administrative type, plus a deletable chip per selection —
/// mirrors [AppAreaFilterSection]'s district field, including its plain
/// (non-highlighted) [InputChip] styling, so both surfaces feel like the
/// same component.
class CitySelectorWardField extends StatelessWidget {
  const CitySelectorWardField({
    required this.wards,
    required this.enabled,
    required this.onTap,
    required this.onClear,
    required this.onRemove,
    super.key,
  });

  final Set<String> wards;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasWards = wards.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CitySelectorFieldTile(
          key: const Key('city-selector-ward-field'),
          icon: AppIcons.mapPin,
          label: hasWards
              ? wardSelectionSummary(l10n, wards)
              : l10n.sessionFilterDistricts,
          hasValue: hasWards,
          onClear: hasWards ? onClear : null,
          onTap: enabled ? onTap : null,
        ),
        if (hasWards) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final ward in wards)
                InputChip(
                  label: Text(ward),
                  deleteIconColor: scheme.primary,
                  onDeleted: () => onRemove(ward),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
