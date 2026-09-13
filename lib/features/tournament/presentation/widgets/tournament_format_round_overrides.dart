import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Port of vmito-fe `PerRoundFormatConfig`: rounds left on "default" are
/// removed from `roundFormats` and play the base format.
class TournamentFormatRoundOverrides extends StatelessWidget {
  const TournamentFormatRoundOverrides({
    required this.baseFormat,
    required this.includeThirdPlace,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String baseFormat;
  final bool includeThirdPlace;
  final Map<String, dynamic> values;

  /// Null when no round is overridden, so the key is dropped from the config.
  final ValueChanged<Map<String, dynamic>?> onChanged;

  static Map<String, dynamic> read(Map<String, dynamic> config) {
    final raw = config['roundFormats'];
    return raw is Map<String, dynamic> ? {...raw} : {};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rounds = [
      ...TournamentFormatConfig.knockoutRounds,
      if (includeThirdPlace) TournamentFormatConfig.thirdPlaceRound,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tournamentFormatPerRoundTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              l10n.tournamentFormatPerRoundHint(
                tournamentBestOfLabel(l10n, baseFormat),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final round in rounds)
              Row(
                children: [
                  Expanded(
                    child: Text(tournamentKnockoutRoundLabel(l10n, round)),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _valueFor(round),
                      items: [
                        DropdownMenuItem(
                          child: Text(l10n.tournamentFormatUseDefault),
                        ),
                        for (final format
                            in TournamentFormatConfig.matchFormats)
                          DropdownMenuItem(
                            value: format,
                            child: Text(tournamentBestOfLabel(l10n, format)),
                          ),
                      ],
                      onChanged: (format) => _change(round, format),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String? _valueFor(String round) {
    final value = values[round];
    return TournamentFormatConfig.matchFormats.contains(value)
        ? value as String
        : null;
  }

  void _change(String round, String? format) {
    final next = {...values};
    if (format == null) {
      next.remove(round);
    } else {
      next[round] = format;
    }
    onChanged(next.isEmpty ? null : next);
  }
}
