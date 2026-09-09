import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// The authenticated player's projection of a live session.
class PlayerLiveSession {
  const PlayerLiveSession({required this.session, required this.player});

  final Session session;
  final SessionPlayer player;

  Court? get currentCourt => session.courts
      .where((court) => court.id == player.currentCourtId)
      .firstOrNull;

  Match? get currentMatch => currentCourt?.currentMatch;

  List<SessionPlayer> get courtPlayers {
    final court = currentCourt;
    if (court == null) return const [];
    return court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : session.preSelectedPlayersFor(court);
  }

  int? get waitingPosition {
    if (player.status != PlayerStatus.waiting) return null;
    final index = session.waitingQueue.indexWhere(
      (item) => item.id == player.id,
    );
    return index < 0 ? null : index + 1;
  }

  List<SessionPlayer> get partners => _sameSide(false);
  List<SessionPlayer> get opponents => _sameSide(true);

  List<SessionPlayer> _sameSide(bool opposite) {
    final players = courtPlayers;
    final myIndex = players.indexWhere((item) => item.id == player.id);
    if (myIndex < 0) return const [];
    final mySide = myIndex < 2 ? 0 : 1;
    return [
      for (var index = 0; index < players.length; index++)
        if (players[index].id != player.id &&
            ((index < 2 ? 0 : 1) == mySide) != opposite)
          players[index],
    ];
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
