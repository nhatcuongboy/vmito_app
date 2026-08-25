import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';

/// Read-only mobile port of the web host's `SessionMatchesTab`.
///
/// Results are created when a host ends a match on the Courts tab; this tab is
/// deliberately a history and filter surface, not a second result editor.
class HostResultsTab extends ConsumerStatefulWidget {
  const HostResultsTab({required this.session, super.key});
  final Session session;

  @override
  ConsumerState<HostResultsTab> createState() => _HostResultsTabState();
}

class _HostResultsTabState extends ConsumerState<HostResultsTab> {
  String? _courtId;
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
                            _courtId != null || _filter != _ResultFilter.all,
                      )
                    else
                      _MatchesGrid(
                        matches: filtered,
                        session: widget.session,
                        maxWidth: constraints.maxWidth,
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
        initial: _ResultsFilterDraft(courtId: _courtId, filter: _filter),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _courtId = selected.courtId;
        _filter = selected.filter;
      });
    }
  }
}

class _ResultsControls extends StatelessWidget {
  const _ResultsControls({
    required this.courtId,
    required this.filter,
    required this.newestFirst,
    required this.onShowFilters,
    required this.onSortChanged,
  });
  final String? courtId;
  final _ResultFilter filter;
  final bool newestFirst;
  final VoidCallback onShowFilters;
  final VoidCallback onSortChanged;
  @override
  Widget build(BuildContext context) {
    final activeFilterCount =
        (courtId == null ? 0 : 1) + (filter == _ResultFilter.all ? 0 : 1);
    return Row(
      children: [
        OutlinedButton.icon(
          key: const Key('host-results-filter'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
            ),
          ),
          onPressed: onShowFilters,
          icon: Badge(
            isLabelVisible: activeFilterCount > 0,
            label: Text('$activeFilterCount'),
            child: const Icon(AppIcons.filter, size: 16),
          ),
          label: Text(activeFilterCount == 0 ? 'Bộ lọc' : 'Đã lọc'),
        ),
        const Spacer(),
        PopupMenuButton<bool>(
          key: const Key('host-results-sort'),
          tooltip: 'Sắp xếp kết quả',
          onSelected: (value) {
            if (value != newestFirst) onSortChanged();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: true, child: Text('Mới nhất')),
            PopupMenuItem(value: false, child: Text('Cũ nhất')),
          ],
          child: Container(
            height: AppSizes.minTapTarget,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  newestFirst ? AppIcons.arrowDownward : AppIcons.arrowUpward,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(newestFirst ? 'Mới nhất' : 'Cũ nhất'),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
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
  });
  final List<Match> matches;
  final Session session;
  final double maxWidth;
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
            child: _MatchResultCard(match: match, session: session),
          ),
      ],
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({required this.match, required this.session});
  final Match match;
  final Session session;
  @override
  Widget build(BuildContext context) {
    final court = session.courts
        .where((court) => court.id == match.courtId)
        .firstOrNull;
    final direction = court?.direction ?? CourtDirection.horizontal;
    final teams = _matchTeamIds(match, direction);
    final result = matchResult(match, direction: direction);
    final playerById = {
      for (final player in session.players) player.id: player,
    };
    String playerLabel(String id) {
      final matchPlayer = match.players
          .where((entry) => entry.playerId == id)
          .firstOrNull;
      final sessionPlayer = playerById[id];
      return matchPlayer?.player?.name ??
          sessionPlayer?.displayName ??
          'Người chơi';
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
      color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
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
        'Thêm',
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultsFilterSheet extends StatefulWidget {
  const _ResultsFilterSheet({required this.courts, required this.initial});

  final List<Court> courts;
  final _ResultsFilterDraft initial;

  @override
  State<_ResultsFilterSheet> createState() => _ResultsFilterSheetState();
}

abstract final class _ResultsFilterControl {
  static const court = 'court';
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
      child: ReactiveForm(
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
    this.filter = _ResultFilter.all,
  });

  final String? courtId;
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

enum _ResultFilter { all, withScore, withoutScore }

class MatchResultSummary {
  const MatchResultSummary({this.first, this.second, this.winner});
  final int? first;
  final int? second;
  final int? winner;
  bool get hasScore => first != null || second != null;
}

/// Decodes the backend's JSON-string `score`: one line per player, but each
/// pair shares the same score. Corrupt or older payloads simply render no score.
MatchResultSummary matchResult(
  Match match, {
  CourtDirection direction = CourtDirection.horizontal,
}) {
  final raw = match.score;
  if (raw == null || raw.isEmpty) return const MatchResultSummary();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const MatchResultSummary();
    final scores = <String, int>{
      for (final row in decoded.whereType<Map<String, dynamic>>())
        if (row['playerId'] is String && row['score'] is num)
          row['playerId'] as String: (row['score'] as num).toInt(),
    };
    final teams = _matchTeamIds(match, direction);
    return MatchResultSummary(
      first: teams.first.map((id) => scores[id]).whereType<int>().firstOrNull,
      second: teams.second.map((id) => scores[id]).whereType<int>().firstOrNull,
      winner: match.isDraw ? null : _winner(match, teams),
    );
  } on Object {
    return const MatchResultSummary();
  }
}

({List<String> first, List<String> second}) _matchTeamIds(
  Match match,
  CourtDirection direction,
) {
  final ids = match.orderedPlayerIds;
  if (ids.length <= 2) {
    return (
      first: ids.take(1).toList(growable: false),
      second: ids.skip(1).toList(growable: false),
    );
  }
  if (direction == CourtDirection.vertical) {
    return (
      first: [for (var index = 0; index < ids.length; index += 2) ids[index]],
      second: [for (var index = 1; index < ids.length; index += 2) ids[index]],
    );
  }
  final split = (ids.length / 2).ceil();
  return (
    first: ids.take(split).toList(growable: false),
    second: ids.skip(split).toList(growable: false),
  );
}

int? _winner(
  Match match,
  ({List<String> first, List<String> second}) teams,
) {
  if (match.winnerIds == null) return null;
  try {
    final raw = jsonDecode(match.winnerIds!);
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<String>().any(teams.first.contains)
        ? 1
        : raw.whereType<String>().any(teams.second.contains)
        ? 2
        : null;
  } on Object {
    return null;
  }
}
