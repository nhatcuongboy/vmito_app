class PostLocationDraft {
  const PostLocationDraft({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;

  Map<String, Object> toJson() => {
    'name': name,
    'address': address,
    'lat': latitude,
    'lng': longitude,
  };
}

class PostImageDraft {
  const PostImageDraft({required this.url, required this.publicId});

  factory PostImageDraft.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? json['secureUrl'] ?? '') as String;
    final publicId =
        (json['publicId'] ?? json['cloudinaryPublicId'] ?? '') as String;
    return PostImageDraft(url: url, publicId: publicId);
  }

  final String url;
  final String publicId;
}

class PostComposerDraft {
  const PostComposerDraft({
    required this.content,
    this.images = const [],
    this.location,
  });

  final String content;
  final List<PostImageDraft> images;
  final PostLocationDraft? location;

  Map<String, Object?> toJson() => {
    'content': content.trim(),
    if (location != null) 'location': location!.toJson(),
    if (images.isNotEmpty)
      'images': [
        for (var index = 0; index < images.length; index++)
          {
            'url': images[index].url,
            'publicId': images[index].publicId,
            'order': index,
          },
      ],
  };
}
