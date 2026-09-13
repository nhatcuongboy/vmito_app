import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_teams_controller.dart';

/// Categories, registrations and formats are embedded in the tournament detail
/// that the shell tabs and the manage screen read. Structure edits are not
/// broadcast over the socket, so every successful one must refresh those.
void refreshTournamentStructure(WidgetRef ref, String idOrSlug) {
  ref
    ..invalidate(tournamentDetailControllerProvider(idOrSlug))
    ..invalidate(tournamentTeamsControllerProvider(idOrSlug));
  unawaited(
    ref
        .read(tournamentManagementControllerProvider(idOrSlug).notifier)
        .load(force: true),
  );
}
