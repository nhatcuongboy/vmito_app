import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/reference_video.dart';

void main() {
  group('ReferenceVideo.parse', () {
    test('recognises every YouTube URL shape the web parser accepts', () {
      const cases = {
        'https://www.youtube.com/watch?v=abc123': 'abc123',
        'https://youtube.com/watch?v=abc123&t=30': 'abc123',
        'https://youtu.be/abc123': 'abc123',
        'https://www.youtube.com/embed/abc123': 'abc123',
        'https://www.youtube.com/shorts/abc123': 'abc123',
      };

      for (final entry in cases.entries) {
        final video = ReferenceVideo.parse(entry.key);
        expect(video, isA<YouTubeVideo>(), reason: entry.key);
        expect((video! as YouTubeVideo).videoId, entry.value);
      }
    });

    test('builds a thumbnail from the video id', () {
      final video =
          ReferenceVideo.parse('https://youtu.be/abc123')! as YouTubeVideo;

      expect(
        video.thumbnailUrl,
        'https://img.youtube.com/vi/abc123/hqdefault.jpg',
      );
    });

    test('classifies direct media by extension', () {
      expect(
        ReferenceVideo.parse('https://cdn.example.com/clip.mp4'),
        isA<DirectMediaVideo>(),
      );
      expect(
        ReferenceVideo.parse('https://cdn.example.com/clip.WEBM'),
        isA<DirectMediaVideo>(),
      );
    });

    test('falls back to a plain link', () {
      expect(
        ReferenceVideo.parse('https://vimeo.com/12345'),
        isA<VideoLink>(),
      );
    });

    test('returns null rather than a broken card', () {
      // Empty, blank, non-http and unparseable input must all render nothing.
      expect(ReferenceVideo.parse(null), isNull);
      expect(ReferenceVideo.parse(''), isNull);
      expect(ReferenceVideo.parse('   '), isNull);
      expect(ReferenceVideo.parse('javascript:alert(1)'), isNull);
      expect(ReferenceVideo.parse('not a url'), isNull);
    });

    test('a youtube.com URL with no video id is a link, not a video', () {
      expect(
        ReferenceVideo.parse('https://www.youtube.com/'),
        isA<VideoLink>(),
      );
    });
  });
}
