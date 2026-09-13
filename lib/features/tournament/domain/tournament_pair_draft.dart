/// Body of `POST /tournaments/:id/pairs`, `PUT /tournament-pairs/:id` and
/// `convert-to-pair`. Member order is the array order (position = index + 1).
class TournamentPairDraft {
  const TournamentPairDraft({
    required this.name,
    required this.playerIds,
    required this.type,
  });

  final String name;
  final List<String> playerIds;
  final String type;

  // `name` is always sent: the pair update writes it even when omitted.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'playerIds': playerIds,
    'type': type,
  };
}
