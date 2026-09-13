import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_setup_steps.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_setup_step_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Native port of the web shell's Dashboard tab (host and admin only).
class TournamentDashboardTab extends ConsumerStatefulWidget {
  const TournamentDashboardTab({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  ConsumerState<TournamentDashboardTab> createState() =>
      _TournamentDashboardTabState();
}

class _TournamentDashboardTabState
    extends ConsumerState<TournamentDashboardTab> {
  // Seeded once from the first load, like the web: incomplete steps open,
  // completed ones collapsed. Later refreshes do not re-open steps.
  Set<TournamentSetupStep>? _expanded;

  @override
  Widget build(BuildContext context) {
    final provider = tournamentDetailControllerProvider(widget.idOrSlug);
    return ref
        .watch(provider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(provider),
          ),
          data: (state) {
            final tournament = state.tournament;
            final done = {
              for (final step in TournamentSetupStep.values)
                if (step.isComplete(tournament)) step,
            };
            final expanded = _expanded ??= {
              for (final step in TournamentSetupStep.values)
                if (!done.contains(step)) step,
            };
            return RefreshIndicator(
              onRefresh: ref.read(provider.notifier).refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: [
                  _ProgressBanner(
                    completed: done.length,
                    total: TournamentSetupStep.values.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final (index, step)
                      in TournamentSetupStep.values.indexed)
                    TournamentSetupStepCard(
                      step: step,
                      number: index + 1,
                      isDone: done.contains(step),
                      isExpanded: expanded.contains(step),
                      onToggle: () => setState(() {
                        if (!expanded.remove(step)) expanded.add(step);
                      }),
                      onAction: () => _openManage(step),
                    ),
                ],
              ),
            );
          },
        );
  }

  Future<void> _openManage(TournamentSetupStep step) async {
    await context.push(
      AppRoutes.manageTournament(widget.idOrSlug, option: step.manageOption),
    );
    // Manage mutations are not broadcast over the socket, so refresh on return
    // — the native counterpart of the web's progress-changed event.
    if (mounted) {
      await ref
          .read(tournamentDetailControllerProvider(widget.idOrSlug).notifier)
          .refresh();
    }
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tournamentDashboardGuideTitle,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(AppIcons.grid, color: scheme.onPrimary),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.tournamentDashboardGuideDescription,
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.tournamentDashboardProgress(completed, total),
              style: TextStyle(color: scheme.onPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              color: scheme.onPrimary,
              backgroundColor: scheme.onPrimary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ],
        ),
      ),
    );
  }
}
