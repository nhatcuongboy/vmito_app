/// A host-supplied video link, classified for display.
///
/// Ports the parser in `vmito-fe/src/components/session/SessionReferenceVideo.tsx`.
/// Mobile cannot embed a player without pulling in a webview, so every kind
/// opens externally — but a YouTube link still gets its real thumbnail, which
/// is what makes the card read as a video rather than as a bare URL.
sealed class ReferenceVideo {
  const ReferenceVideo();

  /// Returns null for empty input, a non-http scheme, or an unparseable URL —
  /// all of which mean "render nothing", never "render a broken card".
  static ReferenceVideo? parse(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final url = Uri.tryParse(trimmed);
    if (url == null) return null;
    if (url.scheme != 'http' && url.scheme != 'https') return null;

    final youtubeId = _youTubeId(url);
    if (youtubeId != null) {
      return YouTubeVideo(url: trimmed, videoId: youtubeId);
    }

    final path = url.path.toLowerCase();
    if (_directMediaExtensions.any(path.endsWith)) {
      return DirectMediaVideo(url: trimmed);
    }
    return VideoLink(url: trimmed);
  }

  /// The URL to hand to the browser or the YouTube app.
  String get url;

  static const _directMediaExtensions = {'.mp4', '.webm', '.ogg'};

  static String? _youTubeId(Uri url) {
    final host = url.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host == 'youtu.be') return segments.isEmpty ? null : segments.first;
    if (!host.endsWith('youtube.com')) return null;

    if (url.path == '/watch') return url.queryParameters['v'];
    if (segments.length >= 2 &&
        (segments.first == 'embed' || segments.first == 'shorts')) {
      return segments[1];
    }
    return null;
  }
}

class YouTubeVideo extends ReferenceVideo {
  const YouTubeVideo({required this.url, required this.videoId});

  @override
  final String url;
  final String videoId;

  /// `hqdefault` exists for every video; the higher-res names 404 on older
  /// uploads and would leave a hole in the card.
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

class DirectMediaVideo extends ReferenceVideo {
  const DirectMediaVideo({required this.url});

  @override
  final String url;
}

class VideoLink extends ReferenceVideo {
  const VideoLink({required this.url});

  @override
  final String url;
}
