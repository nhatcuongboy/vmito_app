import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_categories_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_structure_refresh.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_category_editor.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Native port of vmito-fe `manage/panels/CategoriesPanel.tsx`.
class TournamentCategoriesPanel extends ConsumerWidget {
  const TournamentCategoriesPanel({
    required this.tournament,
    required this.idOrSlug,
    super.key,
  });

  final TournamentDetail tournament;
  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = tournamentCategoriesProvider(tournament.id);
    final state = ref.watch(provider);
    final canEdit = state.loaded && !state.busy;
    return TournamentResourceFrame(
      loading: state.loading,
      error: state.loaded ? null : state.error,
      onRetry: ref.read(provider.notifier).reload,
      header: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tournamentManageCategories,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: canEdit ? () => _edit(context) : null,
              icon: const Icon(AppIcons.add),
              label: Text(l10n.tournamentCategoriesAdd),
            ),
          ],
        ),
      ],
      children: [
        if (state.loaded && state.items.isEmpty)
          _EmptyState(onAdd: canEdit ? () => _edit(context) : null),
        for (final category in state.items)
          Card(
            child: ListTile(
              title: Text(category.name),
              subtitle: Text(
                [
                  tournamentCategoryTypeLabel(l10n, category.type),
                  if (category.registrationMode ==
                      TournamentRegistrationMode.individual)
                    l10n.tournamentCategoriesIndividual
                  else
                    l10n.tournamentCategoriesTeamSizeSummary(category.teamSize),
                ].join(' · '),
              ),
              onTap: canEdit ? () => _edit(context, category) : null,
              trailing: IconButton(
                tooltip: l10n.tournamentCategoriesDelete,
                icon: const Icon(AppIcons.delete),
                onPressed: canEdit
                    ? () => _delete(context, ref, category)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, [TournamentCategory? category]) =>
      openResourceEditor(
        context,
        TournamentCategoryEditor(
          tournament: tournament,
          idOrSlug: idOrSlug,
          category: category,
        ),
      );

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TournamentCategory category,
  ) async {
    if (!await confirmResourceDelete(context, category.name)) return;
    final provider = tournamentCategoriesProvider(tournament.id);
    final deleted = await ref.read(provider.notifier).delete(category.id);
    if (!context.mounted) return;
    if (deleted) {
      refreshTournamentStructure(ref, idOrSlug);
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.tournamentCategoriesDeleteFailed}: '
          '${resourceErrorMessage(context, ref.read(provider).error)}',
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(AppIcons.grid, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.tournamentCategoriesEmptyTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tournamentCategoriesEmptyDescription,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onAdd,
            child: Text(l10n.tournamentCategoriesAdd),
          ),
        ],
      ),
    );
  }
}
