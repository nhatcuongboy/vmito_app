import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/player_statistics_ranking.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_stat_badge.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_stat_mvp_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Column index of "Tên" — the only column left-aligned instead of centered.
const _nameColumnIndex = 1;

/// The sortable, MVP-annotated player statistics `DataTable`.
class PlayerStatisticsTable extends StatelessWidget {
  const PlayerStatisticsTable({
    required this.players,
    required this.allPlayers,
    required this.sort,
    required this.showGenderMvp,
    required this.showShuttlecocks,
    required this.onSort,
    required this.onPlayerTap,
    super.key,
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
    final palette = Theme.of(context).extension<AppPalette>()!;
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
        for (var i = 0; i < columns.length; i++)
          DataColumn(
            label: i == _nameColumnIndex
                ? Text(columns[i].$1)
                : Expanded(
                    child: Text(columns[i].$1, textAlign: TextAlign.center),
                  ),
            onSort: (_, _) => onSort(columns[i].$2),
          ),
      ],
      rows: [
        for (var index = 0; index < players.length; index++)
          DataRow(
            key: ValueKey('host-player-statistics-${players[index].playerId}'),
            onSelectChanged: (_) => onPlayerTap(players[index]),
            cells: [
              DataCell(Center(child: Text('${index + 1}'))),
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
                        PlayerStatMvpBadge(
                          label: overall.players.length > 1
                              ? l10n.hostPlayerStatsSharedMvp
                              : l10n.hostPlayerStatsMvp,
                          player: players[index],
                          minMatches: overall.minMatches,
                        ),
                      if (showGenderMvp &&
                          maleIds.contains(players[index].playerId))
                        PlayerStatMvpBadge(
                          label: l10n.hostPlayerStatsMaleMvp,
                          player: players[index],
                          minMatches: male.minMatches,
                          color: palette.info,
                        ),
                      if (showGenderMvp &&
                          femaleIds.contains(players[index].playerId))
                        PlayerStatMvpBadge(
                          label: l10n.hostPlayerStatsFemaleMvp,
                          player: players[index],
                          minMatches: female.minMatches,
                          color: PlayerStatMvpBadge.femaleMvp,
                        ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: _genderBadge(l10n, palette, players[index].gender),
                ),
              ),
              DataCell(
                Center(child: _levelBadge(palette, players[index].level)),
              ),
              DataCell(Center(child: Text('${players[index].totalMatches}'))),
              DataCell(Center(child: Text('${players[index].wins}'))),
              DataCell(Center(child: Text('${players[index].losses}'))),
              DataCell(Center(child: _winRateBadge(players[index].winRate))),
              DataCell(
                Center(
                  child: Tooltip(
                    message: l10n.hostPlayerStatsPointDiffHelp,
                    child: Text(
                      players[index].averagePointDifferential?.toStringAsFixed(
                            1,
                          ) ??
                          '—',
                    ),
                  ),
                ),
              ),
              if (showShuttlecocks)
                DataCell(
                  Center(
                    child: Text(
                      players[index].totalShuttlecocks?.toStringAsFixed(1) ??
                          '—',
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

Widget _genderBadge(AppLocalizations l10n, AppPalette palette, Gender? gender) {
  final (label, color) = switch (gender) {
    Gender.male => (l10n.hostPlayerGenderMale, palette.info),
    Gender.female => (l10n.hostPlayerGenderFemale, PlayerStatBadge.pink),
    Gender.other => (l10n.hostPlayerGenderOther, palette.mutedForeground),
    null => (null, null),
  };
  if (label == null) return const Text('—');
  return PlayerStatBadge(label: label, color: color!);
}

Widget _levelBadge(AppPalette palette, int? level) {
  if (level == null) return const Text('—');
  return PlayerStatBadge(
    label: levelShortLabel(level) ?? '—',
    color: palette.mutedForeground,
  );
}

Widget _winRateBadge(double winRate) {
  final color = switch (winRate) {
    >= 60 => AppColors.success,
    >= 40 => AppColors.warning,
    _ => AppColors.destructive,
  };
  return PlayerStatBadge(label: '${winRate.toStringAsFixed(0)}%', color: color);
}
