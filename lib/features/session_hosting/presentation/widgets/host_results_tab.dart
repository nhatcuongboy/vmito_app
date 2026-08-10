import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      matchCount: filtered.length,
                      courts: widget.session.orderedCourts,
                      courtId: _courtId,
                      filter: _filter,
                      newestFirst: _newestFirst,
                      onCourtChanged: (value) =>
                          setState(() => _courtId = value),
                      onFilterChanged: (value) =>
                          setState(() => _filter = value),
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
}

class _ResultsControls extends StatelessWidget {
  const _ResultsControls({
    required this.matchCount,
    required this.courts,
    required this.courtId,
    required this.filter,
    required this.newestFirst,
    required this.onCourtChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });
  final int matchCount;
  final List<Court> courts;
  final String? courtId;
  final _ResultFilter filter;
  final bool newestFirst;
  final ValueChanged<String?> onCourtChanged;
  final ValueChanged<_ResultFilter> onFilterChanged;
  final VoidCallback onSortChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Kết quả ($matchCount)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            key: const Key('host-results-sort'),
            tooltip: newestFirst ? 'Mới nhất trước' : 'Cũ nhất trước',
            onPressed: onSortChanged,
            icon: Icon(
              newestFirst
                  ? AppIcons.arrowDownward
                  : AppIcons.arrowUpward,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              key: const Key('host-results-court'),
              initialValue: courtId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sân',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(child: Text('Tất cả sân')),
                for (final court in courts)
                  DropdownMenuItem(
                    value: court.id,
                    child: Text(court.customName ?? 'Sân ${court.courtNumber}'),
                  ),
              ],
              onChanged: onCourtChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonFormField<_ResultFilter>(
              initialValue: filter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kết quả',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: _ResultFilter.all,
                  child: Text('Tất cả'),
                ),
                DropdownMenuItem(
                  value: _ResultFilter.withScore,
                  child: Text('Có điểm'),
                ),
                DropdownMenuItem(
                  value: _ResultFilter.withoutScore,
                  child: Text('Chưa có điểm'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
          ),
        ],
      ),
    ],
  );
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: matches.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 225,
      ),
      itemBuilder: (context, index) =>
          _MatchResultCard(match: matches[index], session: session),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
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
            const SizedBox(height: 10),
            _TeamLine(
              names: first,
              score: result.first,
              winner: result.winner == 1,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Center(child: Text('VS')),
            ),
            _TeamLine(
              names: second,
              score: result.second,
              winner: result.winner == 2,
            ),
            const Spacer(),
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
                  const Text(
                    'Hòa',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          names.isEmpty ? '—' : names.join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: winner ? FontWeight.w700 : null,
          ),
        ),
      ),
      Container(
        width: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: winner
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          score?.toString() ?? '–',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

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
