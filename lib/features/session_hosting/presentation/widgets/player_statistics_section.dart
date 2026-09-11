import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/player_statistics_ranking.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_detail_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_export_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_ranking_info_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_table.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

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
    final palette = Theme.of(context).extension<AppPalette>()!;
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
            _TonalIconButton(
              icon: AppIcons.info,
              tooltip: l10n.hostPlayerStatsInfo,
              palette: palette,
              onPressed: () => showPlayerStatisticsRankingInfoSheet(context),
              buttonKey: const Key('host-player-statistics-info'),
            ),
            if (statistics.asData?.value.isNotEmpty ?? false) ...[
              const SizedBox(width: AppSpacing.xs),
              _TonalIconButton(
                icon: AppIcons.download,
                tooltip: l10n.hostPlayerStatsExport,
                palette: palette,
                buttonKey: const Key('host-player-statistics-export'),
                onPressed: () => showPlayerStatisticsExportSheet(
                  context,
                  session: widget.session,
                  players: sortPlayerStatistics(
                    statistics.requireValue,
                    _sort,
                  ),
                  showShuttlecocks: showShuttlecocks,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // The host screen tints its body, which would otherwise hide
                  // this row's ink splashes painted on the Scaffold's Material.
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('host-player-statistics-gender-mvp'),
                      onTap: () =>
                          setState(() => _showGenderMvp = !_showGenderMvp),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l10n.hostPlayerStatsGenderMvp),
                            ),
                            Switch.adaptive(
                              value: _showGenderMvp,
                              onChanged: (value) =>
                                  setState(() => _showGenderMvp = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: palette.border),
                  SingleChildScrollView(
                    key: const Key('host-player-statistics-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: PlayerStatisticsTable(
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
                  Container(
                    color: palette.muted.withValues(alpha: .5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.hostPlayerStatsCount(players.length),
                            style: TextStyle(color: palette.mutedForeground),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(color: AppColors.brand),
                          ),
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
              ),
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
}

/// Header icon button with a brand-tinted circular background, matching the
/// web app's `variant="ghost" colorPalette="green"` icon buttons.
class _TonalIconButton extends StatelessWidget {
  const _TonalIconButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onPressed,
    required this.buttonKey,
  });
  final IconData icon;
  final String tooltip;
  final AppPalette palette;
  final VoidCallback onPressed;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: palette.brandSurface,
      foregroundColor: AppColors.brand,
      shape: const CircleBorder(),
    ),
  );
}
