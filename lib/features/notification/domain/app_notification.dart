enum AppNotificationType {
  system,
  session,
  registration,
  payment,
  club,
  tournament,
  post,
  venueRental,
  venueRequest,
  unknown,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: _type(json['type']),
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : const {},
        isRead: json['isRead'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  String? get sessionId => _string(data['sessionId']);
  String? get sessionSlug =>
      _string(data['slug']) ?? _string(data['sessionSlug']);
  String? get clubId => _string(data['clubSlug']) ?? _string(data['clubId']);
  String? get tournamentId =>
      _string(data['tournamentSlug']) ?? _string(data['tournamentId']);
  String? get postId => _string(data['postId']);
  String? get venueId =>
      _string(data['venueSlug']) ??
      _string(data['venueId']) ??
      _string(data['id']);
  String? get rentalRequestId => _string(data['rentalRequestId']);
  String? get action => _string(data['action']);
  String? get actorName => _string(data['actorName']);
  String? get actorAvatar => _string(data['actorAvatar']);

  bool get hasRelatedUser =>
      const {
        'post_liked',
        'post_commented',
        'session_favorited',
        'club_favorited',
        'tournament_favorited',
      }.contains(action) &&
      actorName != null;

  AppNotification markRead() => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    message: message,
    data: data,
    isRead: true,
    createdAt: createdAt,
  );

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static AppNotificationType _type(Object? value) => switch (value) {
    'SYSTEM' => AppNotificationType.system,
    'SESSION' => AppNotificationType.session,
    'REGISTRATION' => AppNotificationType.registration,
    'PAYMENT' => AppNotificationType.payment,
    'CLUB' => AppNotificationType.club,
    'TOURNAMENT' => AppNotificationType.tournament,
    'POST' => AppNotificationType.post,
    'VENUE_RENTAL' => AppNotificationType.venueRental,
    'VENUE_REQUEST' => AppNotificationType.venueRequest,
    _ => AppNotificationType.unknown,
  };
}
