import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/session.dart';

void main() {
  group('Session.galleryImages', () {
    test('keeps the cover first and removes blank and duplicate URLs', () {
      const session = Session(
        id: 'gallery-1',
        name: 'Gallery',
        status: SessionStatus.preparing,
        coverPhoto: ' https://example.com/cover.jpg ',
        images: [
          'https://example.com/one.jpg',
          'https://example.com/cover.jpg',
          ' ',
          'https://example.com/two.jpg',
          'https://example.com/one.jpg',
        ],
      );

      expect(session.galleryImages, const [
        'https://example.com/cover.jpg',
        'https://example.com/one.jpg',
        'https://example.com/two.jpg',
      ]);
    });
  });
}
