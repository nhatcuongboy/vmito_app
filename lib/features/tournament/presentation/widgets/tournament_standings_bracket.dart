import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_standings.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentPlayoffsView extends StatelessWidget {
  const TournamentPlayoffsView({
    required this.categories,
    required this.matches,
    required this.showPlayerNames,
    super.key,
  });

  final List<TournamentCategory> categories;
  final List<TournamentMatch> matches;
  final bool showPlayerNames;

  @override
  Widget build(BuildContext context) {
    final visible = categories
        .where(
          (category) => category.format != TournamentCategoryFormat.roundRobin,
        )
        .toList(growable: false);
    if (visible.isEmpty) {
      return const _EmptyPlayoffs(
        key: Key('tournament-standings-playoffs-empty'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xl),
          _CategoryHeading(category: visible[index]),
          const SizedBox(height: AppSpacing.sm),
          if (visible[index].format ==
              TournamentCategoryFormat.doubleElimination)
            _DoubleEliminationBracket(
              category: visible[index],
              matches: _playoffMatches(visible[index].id),
              showPlayerNames: showPlayerNames,
            )
          else
            _SingleEliminationBracket(
              category: visible[index],
              matches: _playoffMatches(visible[index].id),
              groupStageMatchCount: matches
                  .where(
                    (match) =>
                        match.categoryId == visible[index].id &&
                        (match.groupId != null ||
                            match.round.toUpperCase() == 'GROUP'),
                  )
                  .length,
              showPlayerNames: showPlayerNames,
            ),
        ],
      ],
    );
  }

  List<TournamentMatch> _playoffMatches(String categoryId) =>
      matches
          .where(
            (match) =>
                match.categoryId == categoryId &&
                match.groupId == null &&
                match.round.toUpperCase() != 'GROUP',
          )
          .toList(growable: false)
        ..sort(
          (first, second) => first.matchNumber.compareTo(second.matchNumber),
        );
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({required this.category});

  final TournamentCategory category;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: Icon(Icons.sell_outlined, size: 16),
        ),
      ),
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

class _SingleEliminationBracket extends StatelessWidget {
  const _SingleEliminationBracket({
    required this.category,
    required this.matches,
    required this.groupStageMatchCount,
    required this.showPlayerNames,
  });

  final TournamentCategory category;
  final List<TournamentMatch> matches;
  final int groupStageMatchCount;
  final bool showPlayerNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMatches = buildTournamentEliminationMatches(
      category: category,
      matches: matches,
      groupStageMatchCount: groupStageMatchCount,
      labels: _labels(l10n),
      showPlayerNames: showPlayerNames,
    );
    final columns = buildTournamentBracketColumns(displayMatches);
    if (columns.isEmpty) return const _EmptyPlayoffs();
    return _HorizontalBracket(
      key: const Key('tournament-standings-single-bracket'),
      children: [
        for (final column in columns)
          _BracketColumn(
            title: _roundLabel(l10n, column.round),
            matches: column.matches,
          ),
      ],
    );
  }
}

class _DoubleEliminationBracket extends StatelessWidget {
  const _DoubleEliminationBracket({
    required this.category,
    required this.matches,
    required this.showPlayerNames,
  });

  final TournamentCategory category;
  final List<TournamentMatch> matches;
  final bool showPlayerNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (matches.isEmpty) return const _EmptyPlayoffs();
    final display = buildTournamentEliminationMatches(
      category: category,
      matches: matches,
      labels: _labels(l10n),
      showPlayerNames: showPlayerNames,
    );
    final byId = {for (final match in display) match.id: match};
    final upper = _doubleColumns(
      matches.where((match) => match.bracketType == 'UPPER'),
      byId,
      upper: true,
      l10n: l10n,
    );
    final lower = _doubleColumns(
      matches.where((match) => match.bracketType == 'LOWER'),
      byId,
      upper: false,
      l10n: l10n,
    );
    final finals =
        matches
            .where((match) => match.bracketType == 'GF')
            .toList(growable: false)
          ..sort(
            (first, second) => first.matchNumber.compareTo(second.matchNumber),
          );
    if (finals.isNotEmpty) {
      upper.add(
        _BracketColumn(
          title: l10n.tournamentStandingsGrandFinal,
          matches: [
            for (var index = 0; index < finals.length; index++)
              _withReset(byId[finals[index].id]!, index > 0),
          ],
        ),
      );
    }
    return Column(
      key: const Key('tournament-standings-double-bracket'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tournamentStandingsUpperBracket,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _HorizontalBracket(children: upper),
        if (lower.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.tournamentStandingsLowerBracket,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _HorizontalBracket(children: lower),
        ],
      ],
    );
  }
}

List<Widget> _doubleColumns(
  Iterable<TournamentMatch> source,
  Map<String, TournamentBracketMatch> byId, {
  required bool upper,
  required AppLocalizations l10n,
}) {
  final grouped = <String, List<TournamentMatch>>{};
  for (final match in source) {
    grouped.putIfAbsent(match.round.toUpperCase(), () => []).add(match);
  }
  final rounds = grouped.keys.toList()
    ..sort((first, second) {
      if (upper) {
        final firstCode = first.replaceFirst('UB-', '');
        final secondCode = second.replaceFirst('UB-', '');
        return tournamentBracketRoundOrder
            .indexOf(firstCode)
            .compareTo(tournamentBracketRoundOrder.indexOf(secondCode));
      }
      final firstNumber = grouped[first]!
          .map((match) => match.matchNumber)
          .reduce((a, b) => a < b ? a : b);
      final secondNumber = grouped[second]!
          .map((match) => match.matchNumber)
          .reduce((a, b) => a < b ? a : b);
      return firstNumber.compareTo(secondNumber);
    });
  return [
    for (var index = 0; index < rounds.length; index++)
      _BracketColumn(
        title: upper
            ? _upperRoundLabel(l10n, rounds[index])
            : rounds[index] == 'LB-F'
            ? l10n.tournamentStandingsLowerFinal
            : l10n.tournamentStandingsLowerRound(index + 1),
        matches: [
          for (final match
              in (grouped[rounds[index]]!..sort(
                (first, second) =>
                    first.matchNumber.compareTo(second.matchNumber),
              )))
            byId[match.id]!,
        ],
      ),
  ];
}

TournamentBracketMatch _withReset(TournamentBracketMatch match, bool reset) =>
    TournamentBracketMatch(
      id: match.id,
      round: match.round,
      matchNumber: match.matchNumber,
      status: match.status,
      side1Label: match.side1Label,
      side2Label: match.side2Label,
      isFinished: match.isFinished,
      score: match.score,
      winnerPosition: match.winnerPosition,
      isReset: reset,
    );

class _HorizontalBracket extends StatelessWidget {
  const _HorizontalBracket({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.md),
          SizedBox(width: 210, child: children[index]),
        ],
      ],
    ),
  );
}

class _BracketColumn extends StatelessWidget {
  const _BracketColumn({required this.title, required this.matches});

  final String title;
  final List<TournamentBracketMatch> matches;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (var index = 0; index < matches.length; index++) ...[
        if (index > 0) const SizedBox(height: AppSpacing.sm),
        _BracketMatchCard(match: matches[index]),
      ],
    ],
  );
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({required this.match});

  final TournamentBracketMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    match.isReset
                        ? l10n.tournamentStandingsIfNecessary
                        : l10n.tournamentStandingsMatchNumber(
                            match.matchNumber,
                          ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  match.score ?? _statusLabel(l10n, match.status),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          _BracketSide(
            label: match.side1Label,
            winner: match.isFinished && match.winnerPosition == 1,
            decided: match.isFinished,
          ),
          const Divider(height: 1),
          _BracketSide(
            label: match.side2Label,
            winner: match.isFinished && match.winnerPosition == 2,
            decided: match.isFinished,
          ),
        ],
      ),
    );
  }
}

class _BracketSide extends StatelessWidget {
  const _BracketSide({
    required this.label,
    required this.winner,
    required this.decided,
  });

  final String label;
  final bool winner;
  final bool decided;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: winner ? colors.primaryContainer : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
                  color: winner
                      ? colors.onPrimaryContainer
                      : decided
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
            if (winner)
              Icon(Icons.emoji_events, size: 16, color: colors.tertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlayoffs extends StatelessWidget {
  const _EmptyPlayoffs({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Text(
      AppLocalizations.of(context).tournamentStandingsEmptyPlayoffs,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

TournamentBracketLabels _labels(AppLocalizations l10n) =>
    TournamentBracketLabels(
      winnerOf: l10n.tournamentStandingsWinnerOf,
      loserOf: l10n.tournamentStandingsLoserOf,
      poolSeed: l10n.tournamentStandingsPoolSeed,
      ordinal: (rank) => '${rank + 1}',
      bye: l10n.tournamentStandingsBye,
      tbd: l10n.tournamentStandingsTbd,
    );

String _roundLabel(AppLocalizations l10n, String round) => switch (round) {
  'QF' => l10n.tournamentStandingsQuarterFinals,
  'SF' => l10n.tournamentStandingsSemiFinals,
  'F' => l10n.tournamentStandingsFinal,
  tournamentThirdPlaceRound => l10n.tournamentStandingsThirdPlace,
  _ => round,
};

String _upperRoundLabel(AppLocalizations l10n, String round) {
  final code = round.replaceFirst('UB-', '');
  return switch (code) {
    'F' => l10n.tournamentStandingsSemiFinals,
    'SF' => l10n.tournamentStandingsQuarterFinals,
    'QF' => l10n.tournamentStandingsPreQuarterFinals,
    _ when code.startsWith('R') => l10n.tournamentStandingsRoundOf(
      int.tryParse(code.substring(1)) ?? 0,
    ),
    _ => round,
  };
}

String _statusLabel(
  AppLocalizations l10n,
  TournamentMatchStatus status,
) => switch (status) {
  TournamentMatchStatus.scheduled => l10n.tournamentStandingsStatusScheduled,
  TournamentMatchStatus.inProgress => l10n.tournamentStandingsStatusInProgress,
  TournamentMatchStatus.finished => l10n.tournamentStandingsStatusFinished,
  TournamentMatchStatus.cancelled => l10n.tournamentStandingsStatusCancelled,
};
