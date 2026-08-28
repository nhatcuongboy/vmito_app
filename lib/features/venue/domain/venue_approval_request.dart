class VenueApprovalUser {
  const VenueApprovalUser({
    required this.id,
    required this.name,
    this.image,
  });

  factory VenueApprovalUser.fromJson(Map<String, dynamic> json) =>
      VenueApprovalUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        image: json['image']?.toString(),
      );

  final String id;
  final String name;
  final String? image;
}

class VenueApprovalRequest {
  const VenueApprovalRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.payload,
    required this.createdAt,
    this.venueName,
    this.submittedBy,
  });

  factory VenueApprovalRequest.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const <String, dynamic>{};
    final submittedBy = json['submittedBy'] is Map
        ? VenueApprovalUser.fromJson(
            Map<String, dynamic>.from(json['submittedBy'] as Map),
          )
        : null;
    final venue = json['venue'] is Map
        ? Map<String, dynamic>.from(json['venue'] as Map)
        : const <String, dynamic>{};
    return VenueApprovalRequest(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'UPDATE',
      status: json['status']?.toString() ?? 'PENDING',
      payload: payload,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      venueName: venue['name']?.toString(),
      submittedBy: submittedBy,
    );
  }

  final String id;
  final String type;
  final String status;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? venueName;
  final VenueApprovalUser? submittedBy;

  String get displayName {
    final name = payload['name']?.toString().trim();
    return name?.isNotEmpty ?? false ? name! : venueName ?? '';
  }
}
