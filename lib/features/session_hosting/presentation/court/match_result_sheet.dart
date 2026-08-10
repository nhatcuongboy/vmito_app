import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_result_team_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Collects the result as a match ends.
///
/// Returns the draft to submit, or null when the host backed out. Every field
/// is optional on the backend, so a host in a hurry can submit an empty result
/// and still end the match.
Future<MatchResultDraft?> showMatchResultSheet(
  BuildContext context, {
  required Session session,
  required Court court,
}) {
  return showModalBottomSheet<MatchResultDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MatchResultSheet(session: session, court: court),
  );
}

/// Ports `MatchResultModal.tsx`.
class MatchResultSheet extends StatefulWidget {
  const MatchResultSheet({
    required this.session,
    required this.court,
    super.key,
  });

  final Session session;
  final Court court;

  @override
  State<MatchResultSheet> createState() => _MatchResultSheetState();
}

class _MatchResultSheetState extends State<MatchResultSheet> {
  final _pair1Score = TextEditingController();
  final _pair2Score = TextEditingController();
  final _notes = TextEditingController();
  final _shuttlecocks = TextEditingController();

  /// 1, 2, or null. Set from the scores as they are typed, and overridden by
  /// tapping a team — a host who enters no score can still name a winner.
  int? _winningPair;
  bool _isDraw = false;

  @override
  void initState() {
    super.initState();
    _pair1Score.addListener(_deriveWinnerFromScores);
    _pair2Score.addListener(_deriveWinnerFromScores);
  }

  @override
  void dispose() {
    _pair1Score.dispose();
    _pair2Score.dispose();
    _notes.dispose();
    _shuttlecocks.dispose();
    super.dispose();
  }

  /// Keeps the winner in step with the scores, so the common case needs no
  /// extra tap. A manual pick survives until the scores change again.
  void _deriveWinnerFromScores() {
    final first = int.tryParse(_pair1Score.text.trim());
    final second = int.tryParse(_pair2Score.text.trim());
    if (first == null || second == null || first == second) return;
    setState(() {
      _winningPair = first > second ? 1 : 2;
      _isDraw = false;
    });
  }

  /// The two sides, by the same column rule the court is drawn with.
  (List<SessionPlayer>, List<SessionPlayer>) get _pairs {
    final byId = {for (final p in widget.session.players) p.id: p};
    final onCourt = widget.court.currentPlayers.isNotEmpty
        ? widget.court.currentPlayers
        : [for (final id in widget.court.orderedPlayerIds) ?byId[id]];

    final groups = groupPairs(
      [
        for (final player in onCourt)
          PositionedPlayer(id: player.id, position: player.slotPosition),
      ],
      widget.court.direction == CourtDirection.vertical
          ? PairDirection.vertical
          : PairDirection.horizontal,
    );

    if (groups == null) {
      // A court whose seats do not resolve still has to be endable; split it
      // down the middle rather than blocking the host.
      final half = (onCourt.length / 2).ceil();
      return (onCourt.take(half).toList(), onCourt.skip(half).toList());
    }
    return (
      [for (final p in groups.pair1) ?byId[p.id]],
      [for (final p in groups.pair2) ?byId[p.id]],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (pair1, pair2) = _pairs;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) => SafeArea(
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.matchResultTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.matchResultSelectWinnerHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MatchResultTeamCard(
                    key: const ValueKey('match-result-pair-1'),
                    label: l10n.courtPair1,
                    players: pair1,
                    controller: _pair1Score,
                    isWinner: !_isDraw && _winningPair == 1,
                    onTap: () => _pickWinner(1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MatchResultTeamCard(
                    key: const ValueKey('match-result-pair-2'),
                    label: l10n.courtPair2,
                    players: pair2,
                    controller: _pair2Score,
                    isWinner: !_isDraw && _winningPair == 2,
                    onTap: () => _pickWinner(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const ValueKey('match-result-draw'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.matchResultIsDraw),
              value: _isDraw,
              onChanged: (value) => setState(() {
                _isDraw = value;
                // A draw has no winner; keeping one would send both.
                if (value) _winningPair = null;
              }),
            ),
            TextField(
              key: const ValueKey('match-result-shuttlecocks'),
              controller: _shuttlecocks,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.matchResultShuttlecockCount,
                hintText: l10n.matchResultShuttlecockPlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('match-result-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.matchResultNotes,
                hintText: l10n.matchResultNotesPlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('submit-match-result'),
              onPressed: () => Navigator.pop(context, _draft(pair1, pair2)),
              child: Text(l10n.matchResultSubmit),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Ending without a result is a legitimate choice, not a mistake:
            // most sessions never score their matches.
            TextButton(
              key: const ValueKey('skip-match-result'),
              onPressed: () => Navigator.pop(context, const MatchResultDraft()),
              child: Text(l10n.matchResultSkip),
            ),
          ],
        ),
      ),
    );
  }

  void _pickWinner(int pair) => setState(() {
    // Tapping the current winner again clears it, so a mis-tap is undoable
    // without a third state to explain.
    _winningPair = _winningPair == pair ? null : pair;
    if (_winningPair != null) _isDraw = false;
  });

  MatchResultDraft _draft(
    List<SessionPlayer> pair1,
    List<SessionPlayer> pair2,
  ) => MatchResultDraft.fromPairs(
    pair1PlayerIds: [for (final p in pair1) p.id],
    pair2PlayerIds: [for (final p in pair2) p.id],
    pair1Score: int.tryParse(_pair1Score.text.trim()),
    pair2Score: int.tryParse(_pair2Score.text.trim()),
    winningPair: _winningPair,
    isDraw: _isDraw,
    notes: _notes.text,
    shuttlecockCount: double.tryParse(_shuttlecocks.text.trim()),
  );
}
