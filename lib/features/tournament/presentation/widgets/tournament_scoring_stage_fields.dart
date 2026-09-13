import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/domain/tournament_scoring_rules.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

/// Presets and custom fields for the selected scoring stage. Disabled while
/// the stage inherits, showing the inherited values.
class TournamentScoringStageFields extends StatefulWidget {
  const TournamentScoringStageFields({
    required this.rules,
    required this.enabled,
    required this.presets,
    required this.defaults,
    required this.onChanged,
    super.key,
  });

  final StageRules rules;
  final bool enabled;
  final List<scoring.RallyScoringDefaults> presets;
  final scoring.RallyScoringDefaults defaults;
  final ValueChanged<StageRules> onChanged;

  @override
  State<TournamentScoringStageFields> createState() =>
      _TournamentScoringStageFieldsState();
}

class _TournamentScoringStageFieldsState
    extends State<TournamentScoringStageFields> {
  late final _points = TextEditingController(
    text: '${widget.rules.pointsToWin}',
  );
  late final _cap = TextEditingController(
    text: _capText(widget.rules.pointCap),
  );

  static String _capText(int? cap) => cap?.toString() ?? '';

  @override
  void didUpdateWidget(TournamentScoringStageFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Presets and the inherit switch change values from outside; typing only
    // round-trips the same number, which must not move the cursor.
    if (int.tryParse(_points.text) != widget.rules.pointsToWin) {
      _points.text = '${widget.rules.pointsToWin}';
    }
    if (int.tryParse(_cap.text) != widget.rules.pointCap) {
      _cap.text = _capText(widget.rules.pointCap);
    }
  }

  @override
  void dispose() {
    _points.dispose();
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rules = widget.rules;
    final enabled = widget.enabled;
    final activePreset = TournamentScoringRules.presetId(widget.presets, rules);
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tournamentScoringPresetTitle, style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preset in widget.presets)
              ChoiceChip(
                label: Text(tournamentScoringPresetLabel(l10n, preset.id)),
                selected: enabled && activePreset == preset.id,
                onSelected: enabled
                    ? (_) => widget.onChanged(
                        rules.copyWith(
                          matchFormat: TournamentScoringRules.presetMatchFormat(
                            preset,
                          ),
                          pointsToWin: preset.pointsToWin,
                          winByTwo: preset.winByTwo,
                          pointCap: preset.pointCap,
                          inherit: false,
                        ),
                      )
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.tournamentScoringCustomTitle, style: labelStyle),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.tournamentScoringMatchFormat),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final format in TournamentFormatConfig.matchFormats)
              ButtonSegment(
                value: format,
                label: Text(tournamentSetCountLabel(l10n, format)),
                enabled: enabled,
              ),
          ],
          selected: {rules.matchFormat},
          onSelectionChanged: (value) =>
              widget.onChanged(rules.copyWith(matchFormat: value.first)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _points,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.tournamentScoringPointsToWin,
          ),
          onChanged: (text) => widget.onChanged(
            rules.copyWith(pointsToWin: int.tryParse(text) ?? 0),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.tournamentScoringWinByTwo),
          value: rules.winByTwo,
          onChanged: enabled
              ? (value) => widget.onChanged(rules.copyWith(winByTwo: value))
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cap,
                enabled: enabled && rules.pointCap != null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.tournamentScoringPointCap,
                  hintText: l10n.tournamentScoringNoCap,
                ),
                onChanged: (text) {
                  final cap = int.tryParse(text);
                  widget.onChanged(
                    rules.copyWith(
                      pointCap: cap != null && cap > 0 ? cap : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: enabled
                  ? () => widget.onChanged(
                      rules.copyWith(
                        pointCap: rules.pointCap == null
                            ? widget.defaults.pointCap ??
                                  widget.defaults.pointsToWin
                            : null,
                      ),
                    )
                  : null,
              child: Text(
                rules.pointCap == null
                    ? l10n.tournamentScoringNoCap
                    : l10n.tournamentScoringDisableCap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
