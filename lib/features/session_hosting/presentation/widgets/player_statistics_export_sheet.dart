import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_share_service.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_domain/vmito_domain.dart';

enum StatisticsExportColumn {
  number,
  name,
  gender,
  level,
  matches,
  wins,
  losses,
  winRate,
  pointDifference,
  shuttlecocks,
}

Future<void> showPlayerStatisticsExportSheet(
  BuildContext context, {
  required Session session,
  required List<PlayerStatistics> players,
  required bool showShuttlecocks,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _StatisticsExportSheet(
    session: session,
    players: players,
    showShuttlecocks: showShuttlecocks,
  ),
);

class _StatisticsExportSheet extends ConsumerStatefulWidget {
  const _StatisticsExportSheet({
    required this.session,
    required this.players,
    required this.showShuttlecocks,
  });
  final Session session;
  final List<PlayerStatistics> players;
  final bool showShuttlecocks;

  @override
  ConsumerState<_StatisticsExportSheet> createState() =>
      _StatisticsExportSheetState();
}

class _StatisticsExportSheetState
    extends ConsumerState<_StatisticsExportSheet> {
  final GlobalKey _captureKey = GlobalKey();
  var _sharing = false;
  late final Set<StatisticsExportColumn> _columns = <StatisticsExportColumn>{
    StatisticsExportColumn.number,
    StatisticsExportColumn.name,
    StatisticsExportColumn.gender,
    StatisticsExportColumn.matches,
    StatisticsExportColumn.wins,
    StatisticsExportColumn.losses,
    StatisticsExportColumn.winRate,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    final available = StatisticsExportColumn.values.where(
      (column) =>
          column != StatisticsExportColumn.shuttlecocks ||
          widget.showShuttlecocks,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.hostPlayerStatsExportColumns,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                children: [
                  for (final column in available)
                    FilterChip(
                      key: ValueKey('stats-export-${column.name}'),
                      selected: _columns.contains(column),
                      label: Text(_columnLabel(l10n, column)),
                      onSelected: (selected) {
                        if (!selected && _columns.length == 1) return;
                        setState(() {
                          if (selected) {
                            _columns.add(column);
                          } else {
                            _columns.remove(column);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  child: FittedBox(
                    alignment: Alignment.topLeft,
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: _StatisticsExportCard(
                        session: widget.session,
                        players: widget.players,
                        columns: StatisticsExportColumn.values
                            .where(_columns.contains)
                            .toList(growable: false),
                        showNewAddress: showNewAddress,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('share-player-statistics-image'),
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.share),
                label: Text(l10n.hostPlayerStatsShare),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final data = await ref
          .read(playerStatisticsCaptureServiceProvider)
          .capture(boundary);
      if (data == null || !mounted) return;
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final safeName = widget.session.name
          .replaceAll(RegExp('[^a-zA-Z0-9_-]+'), '-')
          .replaceAll(RegExp('-+'), '-');
      await ref
          .read(playerStatisticsShareServiceProvider)
          .sharePng(
            data,
            fileName: 'vmito-$safeName-statistics.png',
            origin: origin,
          );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _StatisticsExportCard extends StatelessWidget {
  const _StatisticsExportCard({
    required this.session,
    required this.players,
    required this.columns,
    required this.showNewAddress,
  });
  final Session session;
  final List<PlayerStatistics> players;
  final List<StatisticsExportColumn> columns;
  final bool showNewAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Material(
      color: Colors.white,
      child: Container(
        key: const Key('player-statistics-export-card'),
        width: 700,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (session.displayStartTime != null)
                    Dates.dayWithRange(
                      session.displayStartTime!,
                      session.plannedEndTime,
                      locale: locale,
                    ),
                  if (session.hasLocation)
                    session.displayPlace(showNewAddress: showNewAddress),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 24),
              Text(
                l10n.hostPlayerStatsTitle.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 10),
              Table(
                border: TableBorder.all(color: const Color(0xFFE5E7EB)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
                    children: [
                      for (final column in columns)
                        _ExportCell(
                          text: _columnLabel(l10n, column),
                          bold: true,
                        ),
                    ],
                  ),
                  for (var index = 0; index < players.length; index++)
                    TableRow(
                      children: [
                        for (final column in columns)
                          _ExportCell(
                            text: _columnValue(
                              l10n,
                              players[index],
                              column,
                              index,
                            ),
                            alignLeft: column == StatisticsExportColumn.name,
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Vmito App · vmito.com',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCell extends StatelessWidget {
  const _ExportCell({
    required this.text,
    this.bold = false,
    this.alignLeft = false,
  });
  final String text;
  final bool bold;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
    child: Text(
      text,
      textAlign: alignLeft ? TextAlign.left : TextAlign.center,
      style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
    ),
  );
}

String _columnLabel(
  AppLocalizations l10n,
  StatisticsExportColumn column,
) => switch (column) {
  StatisticsExportColumn.number => l10n.hostPlayerStatsNo,
  StatisticsExportColumn.name => l10n.hostPlayerStatsName,
  StatisticsExportColumn.gender => l10n.hostPlayerStatsGender,
  StatisticsExportColumn.level => l10n.hostPlayerStatsLevel,
  StatisticsExportColumn.matches => l10n.hostPlayerStatsMatches,
  StatisticsExportColumn.wins => l10n.hostPlayerStatsWins,
  StatisticsExportColumn.losses => l10n.hostPlayerStatsLosses,
  StatisticsExportColumn.winRate => l10n.hostPlayerStatsWinRate,
  StatisticsExportColumn.pointDifference => l10n.hostPlayerStatsPointDiff,
  StatisticsExportColumn.shuttlecocks => l10n.hostPlayerStatsShuttlecocks,
};

String _columnValue(
  AppLocalizations l10n,
  PlayerStatistics player,
  StatisticsExportColumn column,
  int index,
) => switch (column) {
  StatisticsExportColumn.number => '${index + 1}',
  StatisticsExportColumn.name => player.name ?? '#${player.playerNumber}',
  StatisticsExportColumn.gender => switch (player.gender) {
    null => '—',
    final gender when gender.name == 'male' => l10n.hostPlayerGenderMale,
    final gender when gender.name == 'female' => l10n.hostPlayerGenderFemale,
    _ => l10n.hostPlayerGenderOther,
  },
  StatisticsExportColumn.level =>
    player.level == null ? '—' : levelShortLabel(player.level!) ?? '—',
  StatisticsExportColumn.matches => '${player.totalMatches}',
  StatisticsExportColumn.wins => '${player.wins}',
  StatisticsExportColumn.losses => '${player.losses}',
  StatisticsExportColumn.winRate => '${player.winRate.toStringAsFixed(0)}%',
  StatisticsExportColumn.pointDifference =>
    player.averagePointDifferential?.toStringAsFixed(1) ?? '—',
  StatisticsExportColumn.shuttlecocks =>
    player.totalShuttlecocks?.toStringAsFixed(1) ?? '—',
};
