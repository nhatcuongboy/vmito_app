class FeedbackAttachment {
  const FeedbackAttachment({
    required this.imageUrl,
    required this.imagePublicId,
  });

  factory FeedbackAttachment.fromJson(Map<String, dynamic> json) =>
      FeedbackAttachment(
        imageUrl: json['imageUrl'] as String,
        imagePublicId: json['imagePublicId'] as String,
      );

  final String imageUrl;
  final String imagePublicId;

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'imagePublicId': imagePublicId,
  };
}

enum FeedbackType {
  contact,
  bugReport,
  unknown;

  factory FeedbackType.fromWire(Object? value) => switch (value) {
    'CONTACT' => FeedbackType.contact,
    'BUG_REPORT' => FeedbackType.bugReport,
    _ => FeedbackType.unknown,
  };

  String get wireValue => switch (this) {
    FeedbackType.contact => 'CONTACT',
    FeedbackType.bugReport => 'BUG_REPORT',
    FeedbackType.unknown => 'UNKNOWN',
  };
}

enum FeedbackStatus {
  pending,
  inProgress,
  resolved,
  closed,
  unknown;

  factory FeedbackStatus.fromWire(Object? value) => switch (value) {
    'PENDING' => FeedbackStatus.pending,
    'IN_PROGRESS' => FeedbackStatus.inProgress,
    'RESOLVED' => FeedbackStatus.resolved,
    'CLOSED' => FeedbackStatus.closed,
    _ => FeedbackStatus.unknown,
  };

  String get wireValue => switch (this) {
    FeedbackStatus.pending => 'PENDING',
    FeedbackStatus.inProgress => 'IN_PROGRESS',
    FeedbackStatus.resolved => 'RESOLVED',
    FeedbackStatus.closed => 'CLOSED',
    FeedbackStatus.unknown => 'UNKNOWN',
  };
}

class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
    this.imageUrl,
    this.imagePublicId,
    this.adminNote,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
    id: json['id'] as String,
    type: FeedbackType.fromWire(json['type']),
    status: FeedbackStatus.fromWire(json['status']),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    imagePublicId: json['imagePublicId'] as String?,
    adminNote: json['adminNote'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final String id;
  final FeedbackType type;
  final FeedbackStatus status;
  final String title;
  final String description;
  final String? imageUrl;
  final String? imagePublicId;
  final String? adminNote;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.wireValue,
    'status': status.wireValue,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'imagePublicId': imagePublicId,
    'adminNote': adminNote,
    'createdAt': createdAt.toIso8601String(),
  };
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.type,
    required this.title,
    required this.description,
    this.attachment,
  });

  final FeedbackType type;
  final String title;
  final String description;
  final FeedbackAttachment? attachment;

  Map<String, dynamic> toJson() => {
    'type': type.wireValue,
    'title': title,
    'description': description,
    if (attachment case final attachment?) ...attachment.toJson(),
  };
}
