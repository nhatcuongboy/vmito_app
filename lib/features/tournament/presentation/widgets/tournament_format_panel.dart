import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_categories_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/domain/tournament_scoring_rules.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_category_picker.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_editor.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_scoring_rules_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Native port of vmito-fe `manage/panels/FormatPanel.tsx`. The web wizard
/// modal becomes a full-screen editor.
class TournamentFormatPanel extends ConsumerStatefulWidget {
  const TournamentFormatPanel({
    required this.tournament,
    required this.idOrSlug,
    this.initialCategoryId,
    super.key,
  });

  final TournamentDetail tournament;
  final String idOrSlug;
  final String? initialCategoryId;

  @override
  ConsumerState<TournamentFormatPanel> createState() =>
      _TournamentFormatPanelState();
}

class _TournamentFormatPanelState extends ConsumerState<TournamentFormatPanel> {
  late String? _categoryId = widget.initialCategoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = tournamentCategoriesProvider(widget.tournament.id);
    final state = ref.watch(provider);
    final category = resolveSelectedCategory(state.items, _categoryId);
    if (state.loaded && category == null) {
      return TournamentCategoryRequired(
        onAction: () => context.replace(
          AppRoutes.manageTournament(widget.idOrSlug, option: 'categories'),
        ),
      );
    }
    return TournamentResourceFrame(
      loading: state.loading,
      error: state.loaded ? null : state.error,
      onRetry: ref.read(provider.notifier).reload,
      header: [
        if (category != null) ...[
          TournamentCategoryPicker(
            categories: state.items,
            selected: category,
            onChanged: (value) => setState(() => _categoryId = value.id),
          ),
          OutlinedButton.icon(
            onPressed: state.busy ? null : () => _switchFormat(category),
            icon: const Icon(AppIcons.edit),
            label: Text(l10n.tournamentFormatSwitch),
          ),
        ],
      ],
      children: [
        if (category != null) ...[
          if (category.formatConfig.isEmpty) const _DefaultFormatHint(),
          _FormatSummary(category: category),
          const SizedBox(height: AppSpacing.md),
          TournamentScoringRulesCard(
            // Re-seed the draft whenever the saved rules change.
            key: ValueKey(
              '${category.id}-${TournamentScoringRules.signature(category)}',
            ),
            tournamentId: widget.tournament.id,
            idOrSlug: widget.idOrSlug,
            category: category,
            sportType: widget.tournament.sportType,
          ),
        ],
      ],
    );
  }

  Future<void> _switchFormat(TournamentCategory category) => openResourceEditor(
    context,
    TournamentFormatEditor(
      tournamentId: widget.tournament.id,
      idOrSlug: widget.idOrSlug,
      category: category,
    ),
  );
}

class _DefaultFormatHint extends StatelessWidget {
  const _DefaultFormatHint();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.info, size: 18, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppLocalizations.of(context).tournamentFormatDefaultHint,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FormatSummary extends StatelessWidget {
  const _FormatSummary({required this.category});

  final TournamentCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (name, description) = tournamentFormatCopy(l10n, category.format);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(description),
            if (TournamentFormatConfig.hasRoundRobin(category.format)) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.tournamentDetailPoints(
                  category.winPoints,
                  category.tiePoints,
                  category.lossPoints,
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
