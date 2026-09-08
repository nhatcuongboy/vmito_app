import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_standings_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_standings.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_standings_bracket.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

typedef TournamentRegistrationOpener =
    void Function(String tournamentId, String registrationId);

/// Dormant native port of `/tournament/[id]/standings`.
///
/// This screen is intentionally not registered with the router. The public
/// tournament route continues to use its web view until the native
/// tournament shell is ready.
class TournamentStandingsScreen extends ConsumerStatefulWidget {
  const TournamentStandingsScreen({
    required this.idOrSlug,
    this.onOpenRegistration,
    super.key,
  });

  final String idOrSlug;
  final TournamentRegistrationOpener? onOpenRegistration;

  @override
  ConsumerState<TournamentStandingsScreen> createState() =>
      _TournamentStandingsScreenState();
}

class _TournamentStandingsScreenState
    extends ConsumerState<TournamentStandingsScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TournamentStandingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idOrSlug != widget.idOrSlug) _load();
  }

  void _load() {
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(
              tournamentStandingsControllerProvider(widget.idOrSlug).notifier,
            )
            .load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      tournamentStandingsControllerProvider(widget.idOrSlug),
    );
    final controller = ref.read(
      tournamentStandingsControllerProvider(widget.idOrSlug).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tournamentStandingsTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          if (!state.hasLoaded) return const _StandingsSkeleton();
          if (state.error != null && state.tournament == null) {
            return _StandingsError(onRetry: () => controller.load(force: true));
          }
          final tournament = state.tournament;
          if (tournament == null) {
            return _StandingsError(onRetry: () => controller.load(force: true));
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              key: const Key('tournament-standings-content'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? AppSpacing.lg : AppSpacing.md,
                AppSpacing.md,
                wide ? AppSpacing.lg : AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StandingsToolbar(
                          state: state,
                          wide: constraints.maxWidth >= 900,
                          onCategory: controller.selectCategory,
                          onStage: controller.setStage,
                          onView: controller.setView,
                          onShowPlayers: (value) => unawaited(
                            controller.setShowPlayerNames(value: value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _InlineWarning(
                              onRetry: controller.refresh,
                            ),
                          ),
                        if (state.stage == TournamentStandingsStage.playoffs)
                          TournamentPlayoffsView(
                            categories: state.visibleCategories,
                            matches: state.matches,
                            showPlayerNames: state.showPlayerNames,
                          )
                        else
                          _PoolStandings(
                            state: state,
                            wide: wide,
                            onOpenRegistration: widget.onOpenRegistration,
                            onRecalculate: (categoryId, groupId) async {
                              try {
                                await controller.recalculate(
                                  categoryId,
                                  groupId,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.tournamentStandingsRecalculated,
                                      ),
                                    ),
                                  );
                                }
                              } on Object {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.tournamentStandingsRecalculateFailed,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        if (state.stage == TournamentStandingsStage.pool &&
                            state.hasAnyStandings) ...[
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            key: const Key(
                              'tournament-standings-ranking-info',
                            ),
                            onPressed: () => _showRankingInfo(
                              context,
                              state.visibleCategories,
                            ),
                            icon: const Icon(Icons.calculate_outlined),
                            label: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.tournamentStandingsRankingsExplained,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StandingsToolbar extends StatelessWidget {
  const _StandingsToolbar({
    required this.state,
    required this.wide,
    required this.onCategory,
    required this.onStage,
    required this.onView,
    required this.onShowPlayers,
  });

  final TournamentStandingsState state;
  final bool wide;
  final ValueChanged<String?> onCategory;
  final ValueChanged<TournamentStandingsStage> onStage;
  final ValueChanged<TournamentStandingsView> onView;
  final ValueChanged<bool> onShowPlayers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = state.tournament?.categories ?? const [];
    final categoryPicker = categories.length > 1
        ? DropdownButtonFormField<String?>(
            key: ValueKey(state.selectedCategoryId),
            initialValue: state.selectedCategoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.tournamentStandingsCategoryFilter,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String?>(
                child: Text(
                  l10n.tournamentStandingsAllCategories,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              for (final category in categories)
                DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(
                    category.name.isEmpty ? category.type : category.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
            ],
            onChanged: onCategory,
          )
        : null;
    final stage = Row(
      children: [
        Expanded(
          child: _StageButton(
            selected: state.stage == TournamentStandingsStage.pool,
            icon: Icons.account_tree_outlined,
            label: l10n.tournamentStandingsPoolPlay,
            onPressed: () => onStage(TournamentStandingsStage.pool),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StageButton(
            selected: state.stage == TournamentStandingsStage.playoffs,
            icon: Icons.device_hub_outlined,
            label: l10n.tournamentStandingsPlayoffs,
            onPressed: () => onStage(TournamentStandingsStage.playoffs),
          ),
        ),
      ],
    );
    final secondary = Row(
      children: [
        if (state.stage == TournamentStandingsStage.pool)
          Expanded(
            child: DropdownButtonFormField<TournamentStandingsView>(
              initialValue: state.view,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(
                  value: TournamentStandingsView.pools,
                  child: Text(
                    l10n.tournamentStandingsPools,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
                DropdownMenuItem(
                  value: TournamentStandingsView.overall,
                  child: Text(
                    l10n.tournamentStandingsOverall,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) onView(value);
              },
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        FilterChip(
          selected: state.showPlayerNames,
          avatar: const Icon(Icons.badge_outlined, size: 18),
          label: Text(l10n.tournamentStandingsShowPlayerNames),
          onSelected: onShowPlayers,
        ),
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categoryPicker != null) ...[
            categoryPicker,
            const SizedBox(height: AppSpacing.md),
          ],
          stage,
          const SizedBox(height: AppSpacing.sm),
          secondary,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (categoryPicker != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 280, child: categoryPicker),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            SizedBox(width: 430, child: stage),
            const Spacer(),
            SizedBox(width: 360, child: secondary),
          ],
        ),
      ],
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    return selected
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _PoolStandings extends StatelessWidget {
  const _PoolStandings({
    required this.state,
    required this.wide,
    required this.onOpenRegistration,
    required this.onRecalculate,
  });

  final TournamentStandingsState state;
  final bool wide;
  final TournamentRegistrationOpener? onOpenRegistration;
  final Future<void> Function(String categoryId, String groupId) onRecalculate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.tournament!.categories.isEmpty) {
      return _EmptyMessage(text: l10n.tournamentStandingsNoCategories);
    }
    if (!state.hasAnyStandings) {
      return _EmptyMessage(text: l10n.tournamentStandingsEmpty);
    }
    return Column(
      key: ValueKey(
        wide ? 'tournament-standings-wide' : 'tournament-standings-mobile',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var categoryIndex = 0;
          categoryIndex < state.visibleCategories.length;
          categoryIndex++
        ) ...[
          if (categoryIndex > 0) const SizedBox(height: AppSpacing.xl),
          _CategoryHeading(category: state.visibleCategories[categoryIndex]),
          const SizedBox(height: AppSpacing.sm),
          if (state.view == TournamentStandingsView.overall)
            _OverallCategory(
              state: state,
              category: state.visibleCategories[categoryIndex],
              wide: wide,
              showPlayerNames: state.showPlayerNames,
              onOpenRegistration: onOpenRegistration,
            )
          else
            _GroupedCategory(
              state: state,
              category: state.visibleCategories[categoryIndex],
              wide: wide,
              showPlayerNames: state.showPlayerNames,
              onOpenRegistration: onOpenRegistration,
              onRecalculate: onRecalculate,
            ),
        ],
      ],
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({required this.category});

  final TournamentCategory category;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.sell_outlined, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          category.name.isEmpty ? category.type : category.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _OverallCategory extends StatelessWidget {
  const _OverallCategory({
    required this.state,
    required this.category,
    required this.wide,
    required this.showPlayerNames,
    required this.onOpenRegistration,
  });

  final TournamentStandingsState state;
  final TournamentCategory category;
  final bool wide;
  final bool showPlayerNames;
  final TournamentRegistrationOpener? onOpenRegistration;

  @override
  Widget build(BuildContext context) {
    final rows = buildTournamentOverallStandings(
      state.standingsByCategory[category.id] ?? const [],
    );
    if (rows.isEmpty) {
      return _EmptyMessage(
        text: AppLocalizations.of(context).tournamentStandingsEmptyCategory,
      );
    }
    return _StandingsRows(
      rows: [
        for (final row in rows)
          _StandingEntry(
            standing: row.standing,
            rank: row.rank,
            groupLabel: _groupLabel(context, row.group),
          ),
      ],
      wide: wide,
      showPlayerNames: showPlayerNames,
      tournamentId: state.tournament!.id,
      onOpenRegistration: onOpenRegistration,
    );
  }
}

class _GroupedCategory extends StatelessWidget {
  const _GroupedCategory({
    required this.state,
    required this.category,
    required this.wide,
    required this.showPlayerNames,
    required this.onOpenRegistration,
    required this.onRecalculate,
  });

  final TournamentStandingsState state;
  final TournamentCategory category;
  final bool wide;
  final bool showPlayerNames;
  final TournamentRegistrationOpener? onOpenRegistration;
  final Future<void> Function(String categoryId, String groupId) onRecalculate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = state.standingsByCategory[category.id] ?? const [];
    if (groups.isEmpty) {
      return _EmptyMessage(text: l10n.tournamentStandingsEmptyCategory);
    }
    final highlightWinner = tournamentGroupStageComplete(
      category.id,
      state.matches,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          _GroupCard(
            title: _groupLabel(
              context,
              groups[index].group,
              fallbackNumber: index + 1,
            ),
            teamCount: groups[index].rows.length,
            recalculate: state.canManage && groups[index].group != null
                ? () => onRecalculate(category.id, groups[index].group!.id)
                : null,
            recalculating:
                state.recalculatingGroupId == groups[index].group?.id,
            child: groups[index].rows.isEmpty
                ? _EmptyMessage(text: l10n.tournamentStandingsEmptyGroup)
                : _StandingsRows(
                    rows: [
                      for (
                        var rowIndex = 0;
                        rowIndex < groups[index].rows.length;
                        rowIndex++
                      )
                        _StandingEntry(
                          standing: groups[index].rows[rowIndex],
                          rank: groups[index].rows[rowIndex].rank > 0
                              ? groups[index].rows[rowIndex].rank
                              : rowIndex + 1,
                          winner:
                              highlightWinner &&
                              (groups[index].rows[rowIndex].rank > 0
                                      ? groups[index].rows[rowIndex].rank
                                      : rowIndex + 1) ==
                                  1,
                        ),
                    ],
                    wide: wide,
                    showPlayerNames: showPlayerNames,
                    tournamentId: state.tournament!.id,
                    onOpenRegistration: onOpenRegistration,
                  ),
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.teamCount,
    required this.child,
    required this.recalculate,
    required this.recalculating,
  });

  final String title;
  final int teamCount;
  final Widget child;
  final VoidCallback? recalculate;
  final bool recalculating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(l10n.tournamentStandingsTeamsCount(teamCount)),
                ),
                if (recalculate != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: l10n.tournamentStandingsRecalculate,
                    onPressed: recalculating ? null : recalculate,
                    icon: recalculating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _StandingEntry {
  const _StandingEntry({
    required this.standing,
    required this.rank,
    this.groupLabel,
    this.winner = false,
  });

  final TournamentStanding standing;
  final int rank;
  final String? groupLabel;
  final bool winner;
}

class _StandingsRows extends StatelessWidget {
  const _StandingsRows({
    required this.rows,
    required this.wide,
    required this.showPlayerNames,
    required this.tournamentId,
    required this.onOpenRegistration,
  });

  final List<_StandingEntry> rows;
  final bool wide;
  final bool showPlayerNames;
  final String tournamentId;
  final TournamentRegistrationOpener? onOpenRegistration;

  @override
  Widget build(BuildContext context) => wide
      ? _StandingsTable(
          rows: rows,
          showPlayerNames: showPlayerNames,
          tournamentId: tournamentId,
          onOpenRegistration: onOpenRegistration,
        )
      : _StandingsCards(
          rows: rows,
          showPlayerNames: showPlayerNames,
          tournamentId: tournamentId,
          onOpenRegistration: onOpenRegistration,
        );
}

class _StandingsCards extends StatelessWidget {
  const _StandingsCards({
    required this.rows,
    required this.showPlayerNames,
    required this.tournamentId,
    required this.onOpenRegistration,
  });

  final List<_StandingEntry> rows;
  final bool showPlayerNames;
  final String tournamentId;
  final TournamentRegistrationOpener? onOpenRegistration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasResults = rows.any((row) => row.standing.hasResult);
    return Column(
      key: const Key('tournament-standings-cards'),
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          Semantics(
            label:
                '${l10n.tournamentStandingsRank} ${rows[index].rank}, ${_teamLabel(rows[index].standing.registration, false)}, ${rows[index].standing.points} ${l10n.tournamentStandingsPoints}',
            child: ExpansionTile(
              leading: CircleAvatar(
                child: Text(hasResults ? '${rows[index].rank}' : '-'),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: _RegistrationName(
                      standing: rows[index].standing,
                      showPlayerNames: showPlayerNames,
                      tournamentId: tournamentId,
                      onOpen: onOpenRegistration,
                    ),
                  ),
                  if (rows[index].winner)
                    Tooltip(
                      message: l10n.tournamentStandingsGroupWinner,
                      child: Icon(
                        Icons.emoji_events,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${rows[index].standing.points}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rows[index].groupLabel case final group?) Text(group),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _compactMetric(
                        l10n.tournamentStandingsPlayed,
                        rows[index].standing.matchesPlayed,
                      ),
                      _compactMetric(
                        l10n.tournamentStandingsWon,
                        rows[index].standing.matchesWon,
                      ),
                      _compactMetric(
                        l10n.tournamentStandingsLost,
                        rows[index].standing.matchesLost,
                      ),
                      _compactMetric(
                        l10n.tournamentStandingsDifference,
                        _signed(rows[index].standing.pointDifference),
                      ),
                    ],
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _DetailMetric(
                      label: l10n.tournamentStandingsDrawn,
                      value: rows[index].standing.matchesDrawn,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsForfeits,
                      value: rows[index].standing.matchesForfeited,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsCancelled,
                      value: rows[index].standing.matchesCancelled,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsPointsFor,
                      value: rows[index].standing.pointsFor,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsPointsAgainst,
                      value: rows[index].standing.pointsAgainst,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsGamesWon,
                      value: rows[index].standing.gamesWon,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsGamesLost,
                      value: rows[index].standing.gamesLost,
                    ),
                    _DetailMetric(
                      label: l10n.tournamentStandingsGameDifference,
                      value: _signed(rows[index].standing.gameDifference),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      l10n.tournamentStandingsRecentForm,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StandingForm(form: rows[index].standing.recentForm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Widget _compactMetric(String label, Object value) => Text('$label $value');

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text('$label: $value'),
    ),
  );
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.rows,
    required this.showPlayerNames,
    required this.tournamentId,
    required this.onOpenRegistration,
  });

  final List<_StandingEntry> rows;
  final bool showPlayerNames;
  final String tournamentId;
  final TournamentRegistrationOpener? onOpenRegistration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showGroup = rows.any((row) => row.groupLabel != null);
    final showForfeits = rows.any(
      (row) => row.standing.matchesForfeited > 0,
    );
    final showCancelled = rows.any(
      (row) => row.standing.matchesCancelled > 0,
    );
    final hasResults = rows.any((row) => row.standing.hasResult);
    return SingleChildScrollView(
      key: const Key('tournament-standings-table'),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.tournamentStandingsRank)),
          DataColumn(label: Text(l10n.tournamentStandingsTeam)),
          if (showGroup) DataColumn(label: Text(l10n.tournamentStandingsGroup)),
          DataColumn(
            label: Text(l10n.tournamentStandingsPlayed),
            numeric: true,
          ),
          DataColumn(label: Text(l10n.tournamentStandingsWon), numeric: true),
          DataColumn(label: Text(l10n.tournamentStandingsLost), numeric: true),
          DataColumn(label: Text(l10n.tournamentStandingsDrawn), numeric: true),
          if (showForfeits)
            DataColumn(
              label: Text(l10n.tournamentStandingsForfeits),
              numeric: true,
            ),
          if (showCancelled)
            DataColumn(
              label: Text(l10n.tournamentStandingsCancelled),
              numeric: true,
            ),
          DataColumn(
            label: Text(l10n.tournamentStandingsPointsFor),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.tournamentStandingsPointsAgainst),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.tournamentStandingsDifference),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.tournamentStandingsPoints),
            numeric: true,
          ),
          DataColumn(label: Text(l10n.tournamentStandingsRecentForm)),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              color: row.winner
                  ? WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.primaryContainer,
                    )
                  : null,
              cells: [
                DataCell(Text(hasResults ? '${row.rank}' : '-')),
                DataCell(
                  Row(
                    children: [
                      _RegistrationName(
                        standing: row.standing,
                        showPlayerNames: showPlayerNames,
                        tournamentId: tournamentId,
                        onOpen: onOpenRegistration,
                      ),
                      if (row.winner) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.emoji_events,
                          size: 17,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showGroup) DataCell(Text(row.groupLabel ?? '')),
                DataCell(Text('${row.standing.matchesPlayed}')),
                DataCell(Text('${row.standing.matchesWon}')),
                DataCell(Text('${row.standing.matchesLost}')),
                DataCell(Text('${row.standing.matchesDrawn}')),
                if (showForfeits)
                  DataCell(Text('${row.standing.matchesForfeited}')),
                if (showCancelled)
                  DataCell(Text('${row.standing.matchesCancelled}')),
                DataCell(Text('${row.standing.pointsFor}')),
                DataCell(Text('${row.standing.pointsAgainst}')),
                DataCell(Text('${_signed(row.standing.pointDifference)}')),
                DataCell(
                  Text(
                    '${row.standing.points}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                DataCell(_StandingForm(form: row.standing.recentForm)),
              ],
            ),
        ],
      ),
    );
  }
}

class _RegistrationName extends StatelessWidget {
  const _RegistrationName({
    required this.standing,
    required this.showPlayerNames,
    required this.tournamentId,
    required this.onOpen,
  });

  final TournamentStanding standing;
  final bool showPlayerNames;
  final String tournamentId;
  final TournamentRegistrationOpener? onOpen;

  @override
  Widget build(BuildContext context) {
    final label = _teamLabel(standing.registration, showPlayerNames);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    final registrationId = standing.registration.id.isNotEmpty
        ? standing.registration.id
        : standing.categoryRegistrationId;
    return onOpen == null || registrationId.isEmpty
        ? text
        : InkWell(
            onTap: () => onOpen!(tournamentId, registrationId),
            child: text,
          );
  }
}

class _StandingForm extends StatelessWidget {
  const _StandingForm({required this.form});

  final List<TournamentStandingResult> form;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < 5; index++) ...[
        if (index > 0) const SizedBox(width: 3),
        _FormDot(result: form.elementAtOrNull(index)),
      ],
    ],
  );
}

class _FormDot extends StatelessWidget {
  const _FormDot({required this.result});

  final TournamentStandingResult? result;

  @override
  Widget build(BuildContext context) {
    final style = switch (result) {
      TournamentStandingResult.win => (Colors.green, Icons.check),
      TournamentStandingResult.loss => (Colors.red, Icons.close),
      TournamentStandingResult.draw => (Colors.grey, Icons.remove),
      null => (Colors.transparent, null),
    };
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: style.$1,
        border: result == null
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: style.$2 == null
          ? null
          : Icon(style.$2, size: 13, color: Colors.white),
    );
  }
}

class _StandingsSkeleton extends StatelessWidget {
  const _StandingsSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('tournament-standings-loading'),
    padding: const EdgeInsets.all(AppSpacing.md),
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) => const Card(
      child: SizedBox(height: 72),
    ),
  );
}

class _StandingsError extends StatelessWidget {
  const _StandingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.tournamentStandingsError, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.tournamentStandingsRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Text(AppLocalizations.of(context).tournamentStandingsError),
    actions: [
      TextButton(
        onPressed: () => unawaited(onRetry()),
        child: Text(AppLocalizations.of(context).tournamentStandingsRetry),
      ),
    ],
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

String _groupLabel(
  BuildContext context,
  TournamentCategoryGroup? group, {
  int fallbackNumber = 0,
}) {
  final l10n = AppLocalizations.of(context);
  if (group == null) {
    return l10n.tournamentStandingsGroupFallback(fallbackNumber);
  }
  final name = group.name?.trim();
  if (name == null || name.isEmpty) {
    return l10n.tournamentStandingsGroupFallback(group.number);
  }
  final old = RegExp(r'^group\s+(.+)$', caseSensitive: false).firstMatch(name);
  if (old != null) return l10n.tournamentStandingsGroupNamed(old.group(1)!);
  if (RegExp(r'^[A-Za-z]$').hasMatch(name)) {
    return l10n.tournamentStandingsGroupNamed(name.toUpperCase());
  }
  return name;
}

String _teamLabel(TournamentRegistration registration, bool showPlayers) {
  final players = registration.playerNames.trim();
  final team = registration.teamLabel.trim();
  return showPlayers && players.isNotEmpty ? players : team;
}

Object _signed(int value) => value > 0 ? '+$value' : value;

Future<void> _showRankingInfo(
  BuildContext context,
  List<TournamentCategory> categories,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _RankingInfoSheet(
    categories: categories
        .where(
          (category) =>
              category.format == TournamentCategoryFormat.roundRobin ||
              category.format ==
                  TournamentCategoryFormat.roundRobinToSingleElimination,
        )
        .toList(growable: false),
  ),
);

class _RankingInfoSheet extends StatelessWidget {
  const _RankingInfoSheet({required this.categories});

  final List<TournamentCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Text(
              l10n.tournamentStandingsRankingsExplained,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.tournamentStandingsRankingsExplanation),
            for (final category in categories) ...[
              const SizedBox(height: AppSpacing.lg),
              _RankingCategoryCard(category: category),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankingCategoryCard extends StatelessWidget {
  const _RankingCategoryCard({required this.category});

  final TournamentCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = TournamentRoundRobinConfig.fromCategory(category);
    final points = [
      (config.winPoints, l10n.tournamentStandingsWinPoints),
      (config.lossPoints, l10n.tournamentStandingsLossPoints),
      (config.tiePoints, l10n.tournamentStandingsTiePoints),
      (config.cancelledMatchPoints, l10n.tournamentStandingsCancelledPoints),
      (config.gameWinPoints, l10n.tournamentStandingsGameWinPoints),
      (config.gameLossPoints, l10n.tournamentStandingsGameLossPoints),
      (config.forfeitWinPoints, l10n.tournamentStandingsForfeitWinPoints),
      (config.forfeitLossPoints, l10n.tournamentStandingsForfeitLossPoints),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              category.name.isEmpty ? category.type : category.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.tournamentStandingsPointsEarning}: ${_pointsEarning(l10n, config.pointsEarning)}',
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoTitle(text: l10n.tournamentStandingsScoringRules),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final point in points)
                  Chip(label: Text('${point.$1} ${point.$2}')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoTitle(text: l10n.tournamentStandingsTiebreakers),
            for (var index = 0; index < config.tiebreakers.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 12,
                  child: Text('${index + 1}'),
                ),
                title: Text(_configLabel(l10n, config.tiebreakers[index])),
                subtitle: Text(
                  _configDescription(l10n, config.tiebreakers[index]),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            _InfoTitle(text: l10n.tournamentStandingsStatistics),
            _ConfigChips(items: config.statistics),
            const SizedBox(height: AppSpacing.md),
            _InfoTitle(text: l10n.tournamentStandingsColumns),
            _ConfigChips(items: config.standingsColumns),
          ],
        ),
      ),
    );
  }
}

class _InfoTitle extends StatelessWidget {
  const _InfoTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _ConfigChips extends StatelessWidget {
  const _ConfigChips({required this.items});

  final List<TournamentRoundRobinItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in items)
          Chip(
            label: Text(
              '${item.abbreviation.isEmpty ? item.id : item.abbreviation} · ${_configLabel(l10n, item)}',
            ),
          ),
      ],
    );
  }
}

String _pointsEarning(AppLocalizations l10n, String value) => switch (value) {
  'manual' => l10n.tournamentStandingsManualPoints,
  'tiebreakers_only' => l10n.tournamentStandingsTiebreakersOnly,
  _ => l10n.tournamentStandingsBasedOnResults,
};

String _configLabel(
  AppLocalizations l10n,
  TournamentRoundRobinItem item,
) => switch (item.id) {
  'total_points' || 'points' => l10n.tournamentDetailTiebreakerTotalPoints,
  'game_differential' => l10n.tournamentDetailTiebreakerGameDifferential,
  'total_wins' || 'wins' => l10n.tournamentDetailTiebreakerTotalWins,
  'point_differential' ||
  'points_differential' => l10n.tournamentDetailTiebreakerPointDifferential,
  'matches_played' => l10n.tournamentStandingsPlayed,
  'ties' => l10n.tournamentStandingsDrawn,
  'losses' => l10n.tournamentStandingsLost,
  'games_won' => l10n.tournamentStandingsGamesWon,
  'games_lost' => l10n.tournamentStandingsGamesLost,
  'points_for_stat' || 'points_for_col' => l10n.tournamentStandingsPointsFor,
  'points_against_stat' ||
  'points_against_col' => l10n.tournamentStandingsPointsAgainst,
  'forfeits' => l10n.tournamentStandingsForfeits,
  'cancelled' => l10n.tournamentStandingsCancelled,
  _ => item.label.isEmpty ? item.id : item.label,
};

String _configDescription(
  AppLocalizations l10n,
  TournamentRoundRobinItem item,
) => switch (item.id) {
  'total_points' => l10n.tournamentStandingsTotalPointsDescription,
  'game_differential' => l10n.tournamentStandingsGameDifferenceDescription,
  'total_wins' => l10n.tournamentStandingsTotalWinsDescription,
  'point_differential' => l10n.tournamentStandingsPointDifferenceDescription,
  _ => item.description,
};
