import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/utils/search_text.dart';

void main() {
  test('folds Vietnamese accents and case', () {
    expect(foldSearchText('Quang Hưng ĐẠI Phát'), 'quang hung dai phat');
  });

  test('maps a match back to original offsets', () {
    const text = 'Kèo Quang Hưng';
    final range = searchMatchRange(text, 'quang hung');

    expect(range, isNotNull);
    expect(text.substring(range!.start, range.end), 'Quang Hưng');
  });

  test('matches decomposed input and keeps trailing marks', () {
    // "Hư" stored as NFD: plain u followed by a combining horn (U+031B).
    const text = 'Sân Hư';
    final range = searchMatchRange(text, 'hu');

    expect(range, isNotNull);
    expect(range!.end, text.length);
    expect(text.substring(range.start, range.end), 'Hư');
  });

  test('returns null for blank or missing queries', () {
    expect(searchMatchRange('Sân BMC', '  '), isNull);
    expect(searchMatchRange('Sân BMC', 'the b'), isNull);
  });

  test('containsSearchText ignores accents', () {
    expect(containsSearchText('Sân Đại Phát', 'Đại Phát'), isTrue);
    expect(containsSearchText('Sân Đại Phát', 'dai phat'), isTrue);
    expect(containsSearchText('Sân BMC', 'Đại Phát'), isFalse);
  });
}
