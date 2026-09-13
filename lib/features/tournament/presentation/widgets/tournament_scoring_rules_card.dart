import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_categories_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_structure_refresh.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_scoring_rules.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_scoring_stage_fields.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

/// Native port of vmito-fe `manage/panels/ScoringRulesCard.tsx`. The parent
/// keys it by the saved rules, so the draft re-seeds after every save.
class TournamentScoringRulesCard extends ConsumerStatefulWidget {
  const TournamentScoringRulesCard({
    required this.tournamentId,
    required this.idOrSlug,
    required this.category,
    required this.sportType,
    super.key,
  });

  final String tournamentId;
  final String idOrSlug;
  final TournamentCategory category;
  final scoring.SportType sportType;

  @override
  ConsumerState<TournamentScoringRulesCard> createState() =>
      _TournamentScoringRulesCardState();
}

class _TournamentScoringRulesCardState
    extends ConsumerState<TournamentScoringRulesCard> {
  late final scoring.TournamentSportProfile _profile = scoring
      .getTournamentSportProfile(widget.sportType);
  late final ScoringRulesByStage _initial = TournamentScoringRules.initial(
    widget.category,
    _profile.defaultScoring,
  );
  late ScoringRulesByStage _values = {..._initial};
  ScoringStage _stage = ScoringStage.group;

  bool get _isDirty => ScoringStage.values.any(
    (stage) => _values[stage] != _initial[stage],
  );

  bool get _isValid => _values.values.every((rules) => rules.isValid);

  void _update(StageRules rules) =>
      setState(() => _values = {..._values, _stage: rules});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref
        .watch(tournamentCategoriesProvider(widget.tournamentId))
        .busy;
    final current = _values[_stage]!;
    final effective = TournamentScoringRules.effective(_values, _stage);
    final (_, stageHint) = tournamentScoringStageCopy(l10n, _stage);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.tournamentScoringTitle, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.tournamentScoringDescription),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.tournamentScoringSummaryTitle,
              style: textTheme.labelLarge,
            ),
            for (final stage in ScoringStage.values) _stageTile(stage),
            const SizedBox(height: AppSpacing.sm),
            Text(stageHint, style: textTheme.bodySmall),
            if (_stage != ScoringStage.group)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.tournamentScoringInheritTitle),
                subtitle: Text(
                  _stage == ScoringStage.finalRound
                      ? l10n.tournamentScoringInheritHintFinal
                      : l10n.tournamentScoringInheritHintKnockout,
                ),
                value: current.inherit,
                // Turning inheritance off starts from what the stage plays now.
                onChanged: (inherit) => _update(
                  inherit
                      ? current.copyWith(inherit: true)
                      : effective.copyWith(inherit: false),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            TournamentScoringStageFields(
              key: ValueKey(_stage),
              rules: effective,
              enabled: !current.inherit,
              presets: _profile.scoringPresets,
              defaults: _profile.defaultScoring,
              onChanged: _update,
            ),
            if (!current.isValid) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.tournamentScoringInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: !_isDirty || !_isValid || busy ? null : _save,
              child: Text(
                busy ? l10n.commonLoading : l10n.tournamentScoringSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageTile(ScoringStage stage) {
    final l10n = AppLocalizations.of(context);
    final rules = TournamentScoringRules.effective(_values, stage);
    final inherited = stage != ScoringStage.group && _values[stage]!.inherit;
    final (title, _) = tournamentScoringStageCopy(l10n, stage);
    final presetId = TournamentScoringRules.presetId(
      _profile.scoringPresets,
      rules,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      selected: _stage == stage,
      selectedTileColor: AppColors.success.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      onTap: () => setState(() => _stage = stage),
      title: Text(title),
      subtitle: Text(
        [
          tournamentSetCountLabel(l10n, rules.matchFormat),
          l10n.tournamentScoringSummaryPoints(rules.pointsToWin),
          if (rules.winByTwo) l10n.tournamentScoringSummaryWinByTwo,
          if (rules.pointCap == null)
            l10n.tournamentScoringSummaryNoCap
          else
            l10n.tournamentScoringSummaryCap(rules.pointCap!),
        ].join(' · '),
      ),
      trailing: Text(
        inherited
            ? l10n.tournamentScoringSummaryInherited
            : tournamentScoringPresetLabel(l10n, presetId),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Future<void> _save() async {
    final provider = tournamentCategoriesProvider(widget.tournamentId);
    final saved = await ref
        .read(provider.notifier)
        .update(
          widget.category.id,
          TournamentScoringRules.updatePayload(widget.category, _values),
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (saved) refreshTournamentStructure(ref, widget.idOrSlug);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? l10n.tournamentManageSaved
              : resourceErrorMessage(context, ref.read(provider).error),
        ),
      ),
    );
  }
}
