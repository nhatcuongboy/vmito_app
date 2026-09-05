import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/domain/match_result_summary.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_match_actions_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_match_edit_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

export 'package:vmito_app/features/session/domain/match_result_summary.dart'
    show MatchResultSummary, matchResult;

/// Mobile port of the web host's `SessionMatchesTab`.
class HostResultsTab extends ConsumerStatefulWidget {
  const HostResultsTab({required this.session, super.key});
  final Session session;

  @override
  ConsumerState<HostResultsTab> createState() => _HostResultsTabState();
}

class _HostResultsTabState extends ConsumerState<HostResultsTab> {
  String? _courtId;
  Set<String> _playerIds = {};
  _ResultFilter _filter = _ResultFilter.all;
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    ref.watch(liveSessionRealtimeProvider(widget.session.id));
    final history = ref.watch(matchHistoryProvider(widget.session.id));
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error, size: 42),
              const SizedBox(height: 10),
              const Text('Không thể tải kết quả trận đấu.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(matchHistoryProvider(widget.session.id)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (matches) {
        final filtered =
            matches.where((match) {
              final court = widget.session.courts
                  .where((court) => court.id == match.courtId)
                  .firstOrNull;
              final result = matchResult(
                match,
                direction: court?.direction ?? CourtDirection.horizontal,
              );
              return (_courtId == null || match.courtId == _courtId) &&
                  (_playerIds.isEmpty ||
                      match.orderedPlayerIds.any(_playerIds.contains)) &&
                  switch (_filter) {
                    _ResultFilter.all => true,
                    _ResultFilter.withScore => result.hasScore,
                    _ResultFilter.withoutScore => !result.hasScore,
                  };
            }).toList()..sort((a, b) {
              final left = a.startTime?.millisecondsSinceEpoch ?? 0;
              final right = b.startTime?.millisecondsSinceEpoch ?? 0;
              return _newestFirst
                  ? right.compareTo(left)
                  : left.compareTo(right);
            });
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(matchHistoryProvider(widget.session.id)),
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _ResultsControls(
                      courtId: _courtId,
                      hasPlayerFilter: _playerIds.isNotEmpty,
                      filter: _filter,
                      newestFirst: _newestFirst,
                      onShowFilters: () => _showFilters(context),
                      onSortChanged: () =>
                          setState(() => _newestFirst = !_newestFirst),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (filtered.isEmpty)
                      _EmptyResults(
                        isFiltered:
                            _courtId != null ||
                            _playerIds.isNotEmpty ||
                            _filter != _ResultFilter.all,
                      )
                    else
                      _MatchesGrid(
                        matches: filtered,
                        session: widget.session,
                        maxWidth: constraints.maxWidth,
                        onEdit: _editMatch,
                        onDelete: _deleteMatch,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<_ResultsFilterDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ResultsFilterSheet(
        courts: widget.session.orderedCourts,
        players: widget.session.players,
        initial: _ResultsFilterDraft(
          courtId: _courtId,
          playerIds: _playerIds,
          filter: _filter,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _courtId = selected.courtId;
        _playerIds = selected.playerIds;
        _filter = selected.filter;
      });
    }
  }

  Future<void> _editMatch(Match match) async {
    final court = widget.session.courts
        .where((court) => court.id == match.courtId)
        .firstOrNull;
    await showHostMatchEditSheet(
      context,
      session: widget.session,
      match: match,
      direction: court?.direction ?? CourtDirection.horizontal,
    );
  }

  Future<void> _deleteMatch(Match match) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteMatchDialog(
        sessionId: widget.session.id,
        match: match,
      ),
    );
  }
}

class _ResultsControls extends StatelessWidget {
  const _ResultsControls({
    required this.courtId,
    required this.hasPlayerFilter,
    required this.filter,
    required this.newestFirst,
    required this.onShowFilters,
    required this.onSortChanged,
  });
  final String? courtId;
  final bool hasPlayerFilter;
  final _ResultFilter filter;
  final bool newestFirst;
  final VoidCallback onShowFilters;
  final VoidCallback onSortChanged;
  @override
  Widget build(BuildContext context) {
    final activeFilterCount =
        (courtId == null ? 0 : 1) +
        (hasPlayerFilter ? 1 : 0) +
        (filter == _ResultFilter.all ? 0 : 1);
    // Mirrors the "Quản lý kèo" toolbar (_MySessionsToolbar): sort label
    // button, then a compact outlined icon button for filters.
    return Row(
      children: [
        const Spacer(),
        OutlinedButton.icon(
          key: const Key('host-results-sort'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: onSortChanged,
          icon: const Icon(AppIcons.sortAlpha, size: 18),
          label: Text(newestFirst ? 'Mới nhất' : 'Cũ nhất'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Badge(
          isLabelVisible: activeFilterCount > 0,
          label: Text('$activeFilterCount'),
          child: IconButton.outlined(
            key: const Key('host-results-filter'),
            tooltip: 'Bộ lọc',
            visualDensity: VisualDensity.compact,
            onPressed: onShowFilters,
            icon: const Icon(AppIcons.tune, size: 20),
          ),
        ),
      ],
    );
  }
}

class _MatchesGrid extends StatelessWidget {
  const _MatchesGrid({
    required this.matches,
    required this.session,
    required this.maxWidth,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Match> matches;
  final Session session;
  final double maxWidth;
  final ValueChanged<Match> onEdit;
  final ValueChanged<Match> onDelete;
  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 680 ? 2 : 1;
    final cardWidth =
        (maxWidth - AppSpacing.md * 2 - AppSpacing.sm * (columns - 1)) /
        columns;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final match in matches)
          SizedBox(
            width: cardWidth,
            child: _MatchResultCard(
              match: match,
              session: session,
              onEdit: () => onEdit(match),
              onDelete: () => onDelete(match),
            ),
          ),
      ],
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({
    required this.match,
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });
  final Match match;
  final Session session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final court = session.courts
        .where((court) => court.id == match.courtId)
        .firstOrNull;
    final direction = court?.direction ?? CourtDirection.horizontal;
    final teams = matchTeamIds(match, direction);
    final result = matchResult(match, direction: direction);
    final playerById = {
      for (final player in session.players) player.id: player,
    };
    String playerLabel(String id) {
      final matchPlayer = match.players
          .where((entry) => entry.playerId == id)
          .firstOrNull;
      final sessionPlayer = playerById[id];
      final name =
          matchPlayer?.player?.name ??
          sessionPlayer?.displayName ??
          'Người chơi';
      final number =
          matchPlayer?.player?.playerNumber ?? sessionPlayer?.playerNumber;
      return number == null ? name : '#$number $name';
    }

    final first = teams.first.map(playerLabel).toList(growable: false);
    final second = teams.second.map(playerLabel).toList(growable: false);
    final isSingles = match.players.length <= 2;
    final title = court == null
        ? 'Sân'
        : (court.customName ?? 'Sân ${court.courtNumber}');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = theme.extension<AppPalette>() ?? AppPalette.light();
    return Card(
      key: Key('host-result-card-${match.id}'),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Header: court name + badge + time --------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.mapPin,
                  color: palette.mutedForeground,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _timeLabel(match),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (match.isExtra) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _ExtraMatchBadge(),
                ],
                IconButton(
                  key: Key('host-result-edit-${match.id}'),
                  tooltip: AppLocalizations.of(context).hostResultsEditAction,
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit, size: 19),
                ),
                IconButton(
                  key: Key('host-result-delete-${match.id}'),
                  tooltip: AppLocalizations.of(context).hostResultsDeleteAction,
                  onPressed: onDelete,
                  icon: const Icon(AppIcons.delete, size: 19),
                ),
              ],
            ),

            // -- Scoreboard -------------------------------------------------
            const SizedBox(height: AppSpacing.md),
            _TeamLine(
              label: isSingles ? 'Người chơi 1' : 'Cặp 1',
              names: first,
              score: result.first,
              winner: result.winner == 1,
              palette: palette,
            ),
            _VsDivider(palette: palette),
            _TeamLine(
              label: isSingles ? 'Người chơi 2' : 'Cặp 2',
              names: second,
              score: result.second,
              winner: result.winner == 2,
              palette: palette,
            ),
            if (match.isDraw && result.hasScore) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  'Hòa',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLabel(Match match) {
    final start = match.startTime?.toLocal();
    final end = match.endTime?.toLocal();
    final time = start ?? end;
    if (time == null) return 'Không rõ thời gian';

    if (start == null || end == null) return _clock(time);

    final duration = end.difference(start);
    final range = '${_clock(start)}–${_clock(end)}';
    if (duration.isNegative) return range;
    return '$range · ${_durationLabel(duration)}';
  }

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '< 1 phút';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '$minutes phút';
    if (remainingMinutes == 0) return '$hours giờ';
    return '$hours giờ $remainingMinutes phút';
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.label,
    required this.names,
    required this.score,
    required this.winner,
    required this.palette,
  });
  final String label;
  final List<String> names;
  final int? score;
  final bool winner;
  final AppPalette palette;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scoreColor = winner
        ? palette.success
        : (score == null ? palette.mutedForeground : colors.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  names.isEmpty ? '—' : names.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: winner ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (winner)
                  Text(
                    AppLocalizations.of(context).hostResultsWinner,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            score?.toString() ?? '–',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _VsDivider extends StatelessWidget {
  const _VsDivider({required this.palette});
  final AppPalette palette;
  @override
  Widget build(BuildContext context) {
    final color = palette.mutedForeground.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Divider(color: color, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'VS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Divider(color: color, height: 1)),
        ],
      ),
    );
  }
}

class _ExtraMatchBadge extends StatelessWidget {
  const _ExtraMatchBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>() ?? AppPalette.light();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Phụ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultsFilterSheet extends StatefulWidget {
  const _ResultsFilterSheet({
    required this.courts,
    required this.players,
    required this.initial,
  });

  final List<Court> courts;
  final List<SessionPlayer> players;
  final _ResultsFilterDraft initial;

  @override
  State<_ResultsFilterSheet> createState() => _ResultsFilterSheetState();
}

abstract final class _ResultsFilterControl {
  static const court = 'court';
  static const players = 'players';
  static const result = 'result';
}

class _ResultsFilterSheetState extends State<_ResultsFilterSheet> {
  late final FormGroup _form;

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      _ResultsFilterControl.court: FormControl<String>(
        value: widget.initial.courtId,
      ),
      _ResultsFilterControl.players: FormControl<Set<String>>(
        value: {...widget.initial.playerIds},
      ),
      _ResultsFilterControl.result: FormControl<_ResultFilter>(
        value: widget.initial.filter,
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _apply() {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    Navigator.of(context).pop(
      _ResultsFilterDraft(
        courtId: _form.control(_ResultsFilterControl.court).value as String?,
        playerIds:
            _form.control(_ResultsFilterControl.players).value
                as Set<String>? ??
            const {},
        filter:
            _form.control(_ResultsFilterControl.result).value as _ResultFilter,
      ),
    );
  }

  void _reset() => Navigator.of(context).pop(const _ResultsFilterDraft());

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: AppReactiveForm(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bộ lọc kết quả',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sân', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ReactiveValueListenableBuilder<String>(
              formControlName: _ResultsFilterControl.court,
              builder: (context, control, _) => Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('host-results-filter-court-all'),
                    label: const Text('Tất cả sân'),
                    selected: control.value == null,
                    onSelected: (_) => control.value = null,
                  ),
                  for (final court in widget.courts)
                    ChoiceChip(
                      key: Key('host-results-filter-court-${court.id}'),
                      label: Text(
                        court.customName ?? 'Sân ${court.courtNumber}',
                      ),
                      selected: control.value == court.id,
                      onSelected: (_) => control.value = court.id,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppLocalizations.of(context).hostResultsFilterPlayers,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveValueListenableBuilder<Set<String>>(
              formControlName: _ResultsFilterControl.players,
              builder: (context, control, _) {
                final selected = control.value ?? const <String>{};
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      key: const Key('host-results-filter-player-all'),
                      label: Text(
                        AppLocalizations.of(context).hostResultsAllPlayers,
                      ),
                      selected: selected.isEmpty,
                      onSelected: (_) => control.value = <String>{},
                    ),
                    for (final player in widget.players)
                      FilterChip(
                        key: Key('host-results-filter-player-${player.id}'),
                        label: Text(
                          player.playerNumber == null
                              ? (player.displayName ??
                                    AppLocalizations.of(
                                      context,
                                    ).hostResultsSelectPlayer)
                              : '#${player.playerNumber} ${player.displayName ?? ''}',
                        ),
                        selected: selected.contains(player.id),
                        onSelected: (isSelected) {
                          final next = {...selected};
                          if (isSelected) {
                            next.add(player.id);
                          } else {
                            next.remove(player.id);
                          }
                          control.value = next;
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Kết quả', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ReactiveValueListenableBuilder<_ResultFilter>(
              formControlName: _ResultsFilterControl.result,
              builder: (context, control, _) => Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final filter in _ResultFilter.values)
                    ChoiceChip(
                      key: Key('host-results-filter-result-${filter.name}'),
                      label: Text(_resultFilterLabel(filter)),
                      selected: control.value == filter,
                      onSelected: (_) => control.value = filter,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('host-results-filter-apply'),
                    onPressed: _apply,
                    child: const Text('Áp dụng'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.tonal(
                    key: const Key('host-results-filter-reset'),
                    onPressed: _reset,
                    child: const Text('Xóa lọc'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResultsFilterDraft {
  const _ResultsFilterDraft({
    this.courtId,
    this.playerIds = const {},
    this.filter = _ResultFilter.all,
  });

  final String? courtId;
  final Set<String> playerIds;
  final _ResultFilter filter;
}

String _resultFilterLabel(_ResultFilter filter) => switch (filter) {
  _ResultFilter.all => 'Tất cả',
  _ResultFilter.withScore => 'Có điểm',
  _ResultFilter.withoutScore => 'Chưa có điểm',
};

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.isFiltered});
  final bool isFiltered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 72),
    child: Column(
      children: [
        const Icon(AppIcons.trophy, size: 46),
        const SizedBox(height: 10),
        Text(
          isFiltered
              ? 'Không có trận phù hợp bộ lọc.'
              : 'Chưa có trận nào hoàn tất.',
        ),
        if (!isFiltered)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Kết quả sẽ xuất hiện sau khi kết thúc trận trên tab Sân.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

class _DeleteMatchDialog extends ConsumerWidget {
  const _DeleteMatchDialog({required this.sessionId, required this.match});

  final String sessionId;
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(hostMatchActionsControllerProvider(sessionId));
    final busy = state.isBusy(match.id);
    return AlertDialog(
      title: Text(l10n.hostResultsDeleteTitle),
      content: Text(l10n.hostResultsDeleteMessage),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('host-result-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: busy
              ? null
              : () async {
                  final succeeded = await ref
                      .read(
                        hostMatchActionsControllerProvider(sessionId).notifier,
                      )
                      .delete(match.id);
                  if (!context.mounted) return;
                  if (succeeded) {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.hostResultsDeleteSuccess)),
                    );
                    return;
                  }
                  final error = ref
                      .read(hostMatchActionsControllerProvider(sessionId))
                      .error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error is ApiException
                            ? l10n.apiError(error)
                            : l10n.hostResultsDeleteError,
                      ),
                    ),
                  );
                },
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonDelete),
        ),
      ],
    );
  }
}

enum _ResultFilter { all, withScore, withoutScore }
