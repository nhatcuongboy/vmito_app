import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
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
              final result = matchResult(match);
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
          onPressed: onShowFilters,
          icon: Badge(
            isLabelVisible: activeFilterCount > 0,
            label: Text('$activeFilterCount'),
            child: const Icon(AppIcons.filter),
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
    final result = matchResult(match);
    final court = session.courts
        .where((court) => court.id == match.courtId)
        .firstOrNull;
    final playerById = {
      for (final player in session.players) player.id: player,
    };
    final ids = match.orderedPlayerIds;
    final midpoint = (ids.length / 2).ceil();
    final first = ids
        .take(midpoint)
        .map(
          (id) =>
              match.players
                  .where((entry) => entry.playerId == id)
                  .firstOrNull
                  ?.player
                  ?.name ??
              playerById[id]?.displayName ??
              'Người chơi',
        )
        .toList();
    final second = ids
        .skip(midpoint)
        .map(
          (id) =>
              match.players
                  .where((entry) => entry.playerId == id)
                  .firstOrNull
                  ?.player
                  ?.name ??
              playerById[id]?.displayName ??
              'Người chơi',
        )
        .toList();
    final title = court == null
        ? 'Sân'
        : (court.customName ?? 'Sân ${court.courtNumber}');
    return Card(
      key: Key('host-result-card-${match.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.sessions,
                  color: Theme.of(context).colorScheme.primary,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (match.isExtra) const Chip(label: Text('Thêm')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _TeamLine(
              names: first,
              score: result.first,
              winner: result.winner == 1,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Center(
                child: Text(
                  'VS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            _TeamLine(
              names: second,
              score: result.second,
              winner: result.winner == 2,
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Icon(
                  AppIcons.clock,
                  size: 15,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _timeLabel(match),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (match.isDraw)
                  Text(
                    'Hòa',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (result.hasScore)
                  Icon(
                    result.winner == null
                        ? AppIcons.help
                        : AppIcons.checkCircle,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(Match match) {
    final time = match.endTime ?? match.startTime;
    if (time == null) return 'Không rõ thời gian';
    final local = time.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.names,
    required this.score,
    required this.winner,
  });
  final List<String> names;
  final int? score;
  final bool winner;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: winner ? colors.primaryContainer : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                names.isEmpty ? '—' : names.join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: winner ? FontWeight.w700 : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: winner ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                score?.toString() ?? '–',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: winner ? colors.onPrimary : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
MatchResultSummary matchResult(Match match) {
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
    final ids = match.orderedPlayerIds;
    final split = (ids.length / 2).ceil();
    return MatchResultSummary(
      first: ids
          .take(split)
          .map((id) => scores[id])
          .whereType<int>()
          .firstOrNull,
      second: ids
          .skip(split)
          .map((id) => scores[id])
          .whereType<int>()
          .firstOrNull,
      winner: match.isDraw ? null : _winner(match, ids),
    );
  } on Object {
    return const MatchResultSummary();
  }
}

int? _winner(Match match, List<String> ids) {
  if (match.winnerIds == null) return null;
  try {
    final raw = jsonDecode(match.winnerIds!);
    if (raw is! List || raw.isEmpty) return null;
    final split = (ids.length / 2).ceil();
    return raw.whereType<String>().any(ids.take(split).contains)
        ? 1
        : raw.whereType<String>().any(ids.skip(split).contains)
        ? 2
        : null;
  } on Object {
    return null;
  }
}
