import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

/// Port of vmito-fe `guide/useTournamentSetupSteps.ts`. Order and completion
/// predicates must match the web so both dashboards agree on progress.
enum TournamentSetupStep {
  venue('venues'),
  categories('categories'),
  format('format'),
  teams('teams'),
  rounds('rounds'),
  schedule('schedule'),

  /// No manage option: the web opens the manage screen root.
  publish(null);

  const TournamentSetupStep(this.manageOption);

  final String? manageOption;

  bool isComplete(TournamentDetail tournament) {
    final categories = tournament.categories;
    return switch (this) {
      venue => tournament.venues.isNotEmpty,
      TournamentSetupStep.categories => categories.isNotEmpty,
      format =>
        categories.isNotEmpty &&
            categories.every((c) => c.formatConfig.isNotEmpty),
      teams => tournament.playerCount + tournament.pairCount >= 2,
      rounds =>
        categories.isNotEmpty && categories.every((c) => c.matchCount > 0),
      schedule => tournament.scheduledMatchesCount > 0,
      publish => tournament.isPublished,
    };
  }
}
