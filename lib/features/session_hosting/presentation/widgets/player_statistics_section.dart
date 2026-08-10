import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/player_statistics_ranking.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_detail_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_export_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

class PlayerStatisticsSection extends ConsumerStatefulWidget {
  const PlayerStatisticsSection({required this.session, super.key});
  final Session session;

  @override
  ConsumerState<PlayerStatisticsSection> createState() =>
      _PlayerStatisticsSectionState();
}

class _PlayerStatisticsSectionState
    extends ConsumerState<PlayerStatisticsSection> {
  PlayerStatisticsSort? _sort;
  bool _showGenderMvp = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statistics = ref.watch(playerStatisticsProvider(widget.session.id));
    final showShuttlecocks =
        ref.watch(showShuttlecockCountProvider).asData?.value ?? false;
    return Column(
      key: const Key('host-player-statistics-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.hostPlayerStatsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('host-player-statistics-info'),
              tooltip: l10n.hostPlayerStatsInfo,
              onPressed: () => _showRankingInfo(context),
              icon: const Icon(AppIcons.info),
            ),
            if (statistics.asData?.value.isNotEmpty ?? false)
              IconButton(
                key: const Key('host-player-statistics-export'),
                tooltip: l10n.hostPlayerStatsExport,
                onPressed: () => showPlayerStatisticsExportSheet(
                  context,
                  session: widget.session,
                  players: sortPlayerStatistics(
                    statistics.requireValue,
                    _sort,
                  ),
                  showShuttlecocks: showShuttlecocks,
                ),
                icon: const Icon(AppIcons.download),
              ),
          ],
        ),
        statistics.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  const Icon(AppIcons.error, size: 36),
                  const SizedBox(height: 8),
                  Text(l10n.hostPlayerStatsError),
                  TextButton(
                    key: const Key('host-player-statistics-retry'),
                    onPressed: () => ref.invalidate(
                      playerStatisticsProvider(widget.session.id),
                    ),
                    child: Text(l10n.hostPlayerStatsRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (players) {
            if (players.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.hostPlayerStatsEmpty)),
                ),
              );
            }
            final sorted = sortPlayerStatistics(players, _sort);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  key: const Key('host-player-statistics-gender-mvp'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hostPlayerStatsGenderMvp),
                  value: _showGenderMvp,
                  onChanged: (value) => setState(() => _showGenderMvp = value),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    key: const Key('host-player-statistics-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: _StatisticsTable(
                      players: sorted,
                      allPlayers: players,
                      sort: _sort,
                      showGenderMvp: _showGenderMvp,
                      showShuttlecocks: showShuttlecocks,
                      onSort: _cycleSort,
                      onPlayerTap: (player) => unawaited(
                        showHostPlayerDetailSheet(
                          context,
                          sessionId: widget.session.id,
                          playerId: player.playerId,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.hostPlayerStatsCount(players.length)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showPlayerStatisticsExportSheet(
                          context,
                          session: widget.session,
                          players: sorted,
                          showShuttlecocks: showShuttlecocks,
                        ),
                        icon: const Icon(AppIcons.image),
                        label: Text(l10n.hostPlayerStatsExport),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _cycleSort(PlayerStatisticsSortField field) {
    setState(() {
      if (_sort?.field != field) {
        _sort = PlayerStatisticsSort(
          field,
          StatisticsSortDirection.ascending,
        );
      } else if (_sort?.direction == StatisticsSortDirection.ascending) {
        _sort = PlayerStatisticsSort(
          field,
          StatisticsSortDirection.descending,
        );
      } else {
        _sort = null;
      }
    });
  }

  Future<void> _showRankingInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.hostPlayerStatsRankingTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.hostPlayerStatsEligibilityTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(l10n.hostPlayerStatsEligibility),
              const SizedBox(height: 18),
              Text(
                l10n.hostPlayerStatsOrderTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(l10n.hostPlayerStatsOrder),
              const SizedBox(height: 12),
              Text(
                l10n.hostPlayerStatsPointDiffHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsTable extends StatelessWidget {
  const _StatisticsTable({
    required this.players,
    required this.allPlayers,
    required this.sort,
    required this.showGenderMvp,
    required this.showShuttlecocks,
    required this.onSort,
    required this.onPlayerTap,
  });
  final List<PlayerStatistics> players;
  final List<PlayerStatistics> allPlayers;
  final PlayerStatisticsSort? sort;
  final bool showGenderMvp;
  final bool showShuttlecocks;
  final ValueChanged<PlayerStatisticsSortField> onSort;
  final ValueChanged<PlayerStatistics> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final columns = <(String, PlayerStatisticsSortField)>[
      (l10n.hostPlayerStatsNo, PlayerStatisticsSortField.playerNumber),
      (l10n.hostPlayerStatsName, PlayerStatisticsSortField.name),
      (l10n.hostPlayerStatsGender, PlayerStatisticsSortField.gender),
      (l10n.hostPlayerStatsLevel, PlayerStatisticsSortField.level),
      (l10n.hostPlayerStatsMatches, PlayerStatisticsSortField.totalMatches),
      (l10n.hostPlayerStatsWins, PlayerStatisticsSortField.wins),
      (l10n.hostPlayerStatsLosses, PlayerStatisticsSortField.losses),
      (l10n.hostPlayerStatsWinRate, PlayerStatisticsSortField.winRate),
      (
        l10n.hostPlayerStatsPointDiff,
        PlayerStatisticsSortField.averagePointDifferential,
      ),
      if (showShuttlecocks)
        (
          l10n.hostPlayerStatsShuttlecocks,
          PlayerStatisticsSortField.totalShuttlecocks,
        ),
    ];
    final overall = calculateMvp(allPlayers);
    final male = calculateMvp(allPlayers, gender: Gender.male);
    final female = calculateMvp(allPlayers, gender: Gender.female);
    final overallIds = overall.players.map((e) => e.playerId).toSet();
    final maleIds = male.players.map((e) => e.playerId).toSet();
    final femaleIds = female.players.map((e) => e.playerId).toSet();
    final sortedColumn = sort == null
        ? null
        : columns.indexWhere((item) => item.$2 == sort!.field);

    return DataTable(
      key: const Key('host-player-statistics-table'),
      showCheckboxColumn: false,
      sortColumnIndex: sortedColumn == null || sortedColumn < 0
          ? null
          : sortedColumn,
      sortAscending: sort?.direction != StatisticsSortDirection.descending,
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(column.$1),
            onSort: (_, _) => onSort(column.$2),
          ),
      ],
      rows: [
        for (var index = 0; index < players.length; index++)
          DataRow(
            key: ValueKey('host-player-statistics-${players[index].playerId}'),
            onSelectChanged: (_) => onPlayerTap(players[index]),
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 130,
                    maxWidth: 220,
                  ),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        players[index].name ??
                            '#${players[index].playerNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (!showGenderMvp &&
                          overallIds.contains(players[index].playerId))
                        _MvpBadge(
                          label: overall.players.length > 1
                              ? l10n.hostPlayerStatsSharedMvp
                              : l10n.hostPlayerStatsMvp,
                          player: players[index],
                          minMatches: overall.minMatches,
                        ),
                      if (showGenderMvp &&
                          maleIds.contains(players[index].playerId))
                        _MvpBadge(
                          label: l10n.hostPlayerStatsMaleMvp,
                          player: players[index],
                          minMatches: male.minMatches,
                          color: Colors.blue,
                        ),
                      if (showGenderMvp &&
                          femaleIds.contains(players[index].playerId))
                        _MvpBadge(
                          label: l10n.hostPlayerStatsFemaleMvp,
                          player: players[index],
                          minMatches: female.minMatches,
                          color: Colors.pink,
                        ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(_gender(l10n, players[index].gender))),
              DataCell(
                Text(
                  players[index].level == null
                      ? '—'
                      : levelShortLabel(players[index].level!) ?? '—',
                ),
              ),
              DataCell(Text('${players[index].totalMatches}')),
              DataCell(Text('${players[index].wins}')),
              DataCell(Text('${players[index].losses}')),
              DataCell(Text('${players[index].winRate.toStringAsFixed(0)}%')),
              DataCell(
                Tooltip(
                  message: l10n.hostPlayerStatsPointDiffHelp,
                  child: Text(
                    players[index].averagePointDifferential?.toStringAsFixed(
                          1,
                        ) ??
                        '—',
                  ),
                ),
              ),
              if (showShuttlecocks)
                DataCell(
                  Text(
                    players[index].totalShuttlecocks?.toStringAsFixed(1) ?? '—',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MvpBadge extends StatelessWidget {
  const _MvpBadge({
    required this.label,
    required this.player,
    required this.minMatches,
    this.color = Colors.amber,
  });
  final String label;
  final PlayerStatistics player;
  final int minMatches;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        '${player.winRate.toStringAsFixed(0)}% · ${player.wins}/${player.totalMatches} · ≥ $minMatches',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.amber ? Colors.orange.shade900 : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

String _gender(AppLocalizations l10n, Gender? gender) => switch (gender) {
  Gender.male => l10n.hostPlayerGenderMale,
  Gender.female => l10n.hostPlayerGenderFemale,
  Gender.other => l10n.hostPlayerGenderOther,
  null => '—',
};
