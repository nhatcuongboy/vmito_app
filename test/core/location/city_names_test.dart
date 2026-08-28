import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/city_names.dart';

void main() {
  group('city names', () {
    test('normalizes administrative prefixes and legacy codes', () {
      expect(normalizeCityName('Thành phố Hồ Chí Minh'), 'Hồ Chí Minh');
      expect(normalizeCityName('Tỉnh Đồng Nai'), 'Đồng Nai');
      expect(normalizeCityName('HCM'), 'Hồ Chí Minh');
    });

    test('search key removes Vietnamese tones including d stroke', () {
      expect(citySearchKey('Đà Nẵng'), 'da nang');
      expect(citySearchKey('Thành phố Hồ Chí Minh'), 'ho chi minh');
    });

    test('pins popular cities and removes canonical duplicates', () {
      expect(
        sortCitiesWithPopularFirst([
          'Cần Thơ',
          'Tỉnh Hà Nội',
          'Hồ Chí Minh',
          'Thành phố Hà Nội',
          'Huế',
          'Đà Nẵng',
        ]),
        ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Huế', 'Cần Thơ'],
      );
    });

    test('matches the longest city name across placemark components', () {
      expect(
        matchCityFromAddress(
          cities: ['Thủ Đức', 'Thành phố Hồ Chí Minh', 'Hà Nội'],
          addressParts: ['Thành phố Thủ Đức', 'TP. Hồ Chí Minh, Việt Nam'],
        ),
        'Hồ Chí Minh',
      );
    });
  });
}
