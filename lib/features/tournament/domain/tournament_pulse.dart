import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

enum TournamentPulseKind { live, next, finished, preparing, cancelled }

class TournamentPulseSelection {
  const TournamentPulseSelection(this.kind, [this.match]);

  final TournamentPulseKind kind;
  final TournamentMatch? match;
}

TournamentPulseSelection selectTournamentPulse(
  List<TournamentMatch> matches,
  TournamentStatus status,
) {
  final live =
      matches
          .where((match) => match.status == TournamentMatchStatus.inProgress)
          .toList()
        ..sort(_compareMatchTime);
  if (live.isNotEmpty) {
    return TournamentPulseSelection(TournamentPulseKind.live, live.first);
  }

  final upcoming =
      matches
          .where(
            (match) =>
                match.status == TournamentMatchStatus.scheduled &&
                match.startTime != null,
          )
          .toList()
        ..sort(_compareMatchTime);
  if (upcoming.isNotEmpty) {
    return TournamentPulseSelection(TournamentPulseKind.next, upcoming.first);
  }

  return TournamentPulseSelection(switch (status) {
    TournamentStatus.finished => TournamentPulseKind.finished,
    TournamentStatus.cancelled => TournamentPulseKind.cancelled,
    TournamentStatus.preparing ||
    TournamentStatus.inProgress => TournamentPulseKind.preparing,
  });
}

int _compareMatchTime(TournamentMatch first, TournamentMatch second) {
  final firstTime = first.startTime;
  final secondTime = second.startTime;
  if (firstTime == null && secondTime == null) {
    return first.matchNumber.compareTo(second.matchNumber);
  }
  if (firstTime == null) return 1;
  if (secondTime == null) return -1;
  return firstTime.compareTo(secondTime);
}
