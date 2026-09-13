import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_round_overrides.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_round_robin_section.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Bracket settings: the web `SingleEliminationConfig`,
/// `DoubleEliminationConfig` and `StepConfigurePlayoffs` (RR → SE), which
/// share fields under different config keys.
class TournamentFormatEliminationSection extends StatelessWidget {
  const TournamentFormatEliminationSection({
    required this.format,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final TournamentCategoryFormat format;
  final Map<String, dynamic> values;
  final FormatConfigChanged onChanged;

  bool get _isPlayoffs =>
      format == TournamentCategoryFormat.roundRobinToSingleElimination;

  String get _matchFormatKey =>
      _isPlayoffs ? 'eliminationMatchFormat' : 'matchFormat';

  String get _seedingKey =>
      _isPlayoffs ? 'eliminationSeedingMethod' : 'seedingMethod';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matchFormat = values[_matchFormatKey] as String? ?? 'BEST_OF_3';
    final thirdPlace = values['thirdPlaceMatch'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tournamentFormatPlayoffs,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isPlayoffs) _qualifiers(context),
        _select(
          label: l10n.tournamentFormatSeedingMethod,
          value: values[_seedingKey] as String? ?? 'manual',
          options: TournamentFormatConfig.seedingMethods,
          optionLabel: (method) => tournamentSeedingLabel(l10n, method),
          onChanged: (method) => onChanged(_seedingKey, method),
        ),
        _select(
          label: l10n.tournamentFormatMatchFormat,
          value: matchFormat,
          options: TournamentFormatConfig.matchFormats,
          optionLabel: (value) => tournamentBestOfLabel(l10n, value),
          onChanged: (value) => onChanged(_matchFormatKey, value),
        ),
        TournamentFormatRoundOverrides(
          baseFormat: matchFormat,
          includeThirdPlace:
              format == TournamentCategoryFormat.singleElimination &&
              thirdPlace,
          values: TournamentFormatRoundOverrides.read(values),
          onChanged: (rounds) => onChanged('roundFormats', rounds),
        ),
        if (format == TournamentCategoryFormat.singleElimination)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tournamentFormatThirdPlaceMatch),
            value: thirdPlace,
            onChanged: (value) => onChanged('thirdPlaceMatch', value),
          ),
        if (format == TournamentCategoryFormat.doubleElimination)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tournamentFormatTrueDoubleElimination),
            subtitle: Text(l10n.tournamentFormatTrueDoubleEliminationDesc),
            value: values['isTrueDoubleElimination'] != false,
            onChanged: (value) => onChanged('isTrueDoubleElimination', value),
          ),
      ],
    );
  }

  Widget _qualifiers(BuildContext context) {
    final count = (values['qualifiersPerGroup'] as num?)?.toInt() ?? 2;
    void set(int next) => onChanged(
      'qualifiersPerGroup',
      next.clamp(
        TournamentFormatConfig.minQualifiersPerGroup,
        TournamentFormatConfig.maxQualifiersPerGroup,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).tournamentFormatQualifiersPerGroup,
            ),
          ),
          IconButton.outlined(
            onPressed: count > TournamentFormatConfig.minQualifiersPerGroup
                ? () => set(count - 1)
                : null,
            icon: const Icon(AppIcons.removeCircle),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton.outlined(
            onPressed: count < TournamentFormatConfig.maxQualifiersPerGroup
                ? () => set(count + 1)
                : null,
            icon: const Icon(AppIcons.addCircle),
          ),
        ],
      ),
    );
  }

  Widget _select({
    required String label,
    required String value,
    required List<String> options,
    required String Function(String) optionLabel,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : options.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(optionLabel(option))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}
