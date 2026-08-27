import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/utils/avatar_url.dart';

void main() {
  test('expands Google avatar thumbnails for the lightbox', () {
    expect(
      fullSizeAvatarUrl('https://lh3.googleusercontent.com/a/=s96-c'),
      'https://lh3.googleusercontent.com/a/=s512-c',
    );
  });

  test('expands Zalo avatar thumbnails for the lightbox', () {
    expect(
      fullSizeAvatarUrl('https://s120-ava.zadn.vn/abc'),
      'https://s240-ava.zadn.vn/abc',
    );
  });

  test('keeps application-hosted avatar URLs unchanged', () {
    const url = 'https://res.cloudinary.com/example/image/upload/avatar.jpg';
    expect(fullSizeAvatarUrl(url), url);
  });
}
