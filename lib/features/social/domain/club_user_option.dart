class ClubHostUserOption {
  const ClubHostUserOption({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory ClubHostUserOption.fromJson(Map<String, dynamic> json) =>
      ClubHostUserOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        image: json['image'] as String?,
      );

  final String id;
  final String name;
  final String email;
  final String? image;
}

class ClubImageAsset {
  const ClubImageAsset({
    required this.id,
    required this.url,
    required this.publicId,
  });

  factory ClubImageAsset.fromJson(Map<String, dynamic> json) => ClubImageAsset(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    publicId: json['publicId'] as String? ?? '',
  );

  final String id;
  final String url;
  final String publicId;
}
