import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// A grouped view of the current user's registration rows for one session.
///
/// The backend groups rows by session so the submitted-requests drawer can
/// show one card per session, including registrations made for guests.
class MyJoinRequest {
  const MyJoinRequest({
    required this.session,
    required this.players,
    this.requestedAt,
  });

  factory MyJoinRequest.fromJson(Map<String, dynamic> json) {
    final session = _map(json['session']);
    final venue = _map(session['venue']);
    final rawPlayers = session['players'] ?? json['players'];
    final players = rawPlayers is List
        ? rawPlayers
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => MyJoinRequestPlayer.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <MyJoinRequestPlayer>[];

    return MyJoinRequest(
      session: MyJoinRequestSession.fromJson(
        session,
        venue: venue,
      ),
      players: players,
      requestedAt: _date(json['requestedAt']),
    );
  }

  final MyJoinRequestSession session;
  final List<MyJoinRequestPlayer> players;
  final DateTime? requestedAt;

  bool get hasPending => players.any(
    (player) => player.registrationStatus == RegistrationStatus.pending,
  );
}

class MyJoinRequestSession {
  const MyJoinRequestSession({
    required this.id,
    required this.name,
    this.slug,
    this.startTime,
    this.endTime,
    this.status,
    this.location,
    this.venueName,
  });

  factory MyJoinRequestSession.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? venue,
  }) => MyJoinRequestSession(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString(),
    startTime: _date(json['startTime']),
    endTime: _date(json['endTime']),
    status: _sessionStatus(json['status']),
    location: json['location']?.toString(),
    venueName: venue?['name']?.toString(),
  );

  final String id;
  final String name;
  final String? slug;
  final DateTime? startTime;
  final DateTime? endTime;
  final SessionStatus? status;
  final String? location;
  final String? venueName;

  String? get locationLabel {
    final venue = venueName?.trim();
    if (venue != null && venue.isNotEmpty) return venue;
    final fallback = location?.trim();
    return fallback == null || fallback.isEmpty ? null : fallback;
  }
}

class MyJoinRequestPlayer {
  const MyJoinRequestPlayer({
    required this.id,
    required this.playerNumber,
    required this.registrationStatus,
    this.name,
    this.level,
    this.createdAt,
  });

  factory MyJoinRequestPlayer.fromJson(Map<String, dynamic> json) =>
      MyJoinRequestPlayer(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString(),
        level: (json['level'] as num?)?.toInt(),
        playerNumber: (json['playerNumber'] as num?)?.toInt(),
        registrationStatus: _registrationStatus(json['registrationStatus']),
        createdAt: _date(json['createdAt']),
      );

  final String id;
  final String? name;
  final int? level;
  final int? playerNumber;
  final RegistrationStatus registrationStatus;
  final DateTime? createdAt;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

RegistrationStatus _registrationStatus(dynamic value) =>
    switch (value?.toString().toUpperCase()) {
      'APPROVED' => RegistrationStatus.approved,
      'REJECTED' => RegistrationStatus.rejected,
      _ => RegistrationStatus.pending,
    };

SessionStatus? _sessionStatus(dynamic value) =>
    switch (value?.toString().toUpperCase()) {
      'PREPARING' => SessionStatus.preparing,
      'IN_PROGRESS' => SessionStatus.inProgress,
      'FINISHED' => SessionStatus.finished,
      'CANCELLED' => SessionStatus.cancelled,
      _ => null,
    };
