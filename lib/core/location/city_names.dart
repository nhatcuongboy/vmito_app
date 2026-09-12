import 'package:vmito_app/core/location/vietnam_locations.dart';

const _legacyCityCodes = <String, String>{
  'HCM': 'Hồ Chí Minh',
  'HN': 'Hà Nội',
  'HUE': 'Huế',
  'DNG': 'Đà Nẵng',
  'CT': 'Cần Thơ',
  'HP': 'Hải Phòng',
  'NT': 'Nha Trang',
  'VT': 'Vũng Tàu',
  'BD': 'Bình Dương',
  'DNI': 'Đồng Nai',
};

const _popularCities = ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Huế'];

bool isPopularCity(String value) =>
    _popularCities.contains(normalizeCityName(value));

/// The API accepts province names without Vietnamese administrative prefixes.
String normalizeCityName(String value) {
  final trimmed = value.trim();
  final migrated = _legacyCityCodes[trimmed.toUpperCase()] ?? trimmed;
  return migrated
      .replaceFirst(
        RegExp(r'^(TP\.|Thành phố|Tỉnh)\s+', caseSensitive: false),
        '',
      )
      .trim();
}

String removeVietnameseTones(String value) {
  const source =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
      'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const target =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooo'
      'uuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOO'
      'UUUUUUUUUUUYYYYYD';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final index = source.indexOf(character);
    buffer.write(index < 0 ? character : target[index]);
  }
  return buffer.toString();
}

String citySearchKey(String value) =>
    removeVietnameseTones(normalizeCityName(value)).toLowerCase();

List<String> sortCitiesWithPopularFirst(Iterable<String> values) {
  final unique = <String, String>{};
  for (final value in values) {
    final normalized = normalizeCityName(value);
    if (normalized.isNotEmpty) {
      unique.putIfAbsent(citySearchKey(normalized), () => normalized);
    }
  }
  final result = unique.values.toList(growable: false)
    ..sort((left, right) {
      final leftIndex = _popularCities.indexOf(normalizeCityName(left));
      final rightIndex = _popularCities.indexOf(normalizeCityName(right));
      if (leftIndex >= 0 || rightIndex >= 0) {
        if (leftIndex < 0) return 1;
        if (rightIndex < 0) return -1;
        return leftIndex.compareTo(rightIndex);
      }
      return left.compareTo(right);
    });
  return result;
}

List<String> legacyCities() => sortCitiesWithPopularFirst(vietnamCities);

String? matchCityFromAddress({
  required Iterable<String> cities,
  required Iterable<String?> addressParts,
}) => _matchFromAddress(candidates: cities, addressParts: addressParts);

/// Same address-matching heuristic as [matchCityFromAddress], applied to a
/// single city's ward/commune list instead of the province catalogue.
String? matchWardFromAddress({
  required Iterable<String> wards,
  required Iterable<String?> addressParts,
}) => _matchFromAddress(candidates: wards, addressParts: addressParts);

String? _matchFromAddress({
  required Iterable<String> candidates,
  required Iterable<String?> addressParts,
}) {
  final haystacks = addressParts
      .whereType<String>()
      .map(removeVietnameseTones)
      .map((value) => value.toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (haystacks.isEmpty) return null;

  final ordered = candidates.map(normalizeCityName).toList(growable: false)
    ..sort((left, right) => right.length.compareTo(left.length));
  for (final candidate in ordered) {
    final key = citySearchKey(candidate);
    if (haystacks.any((part) => part.contains(key))) return candidate;
  }
  return null;
}

/// The three post-2025 administrative unit types Vietnam uses below the
/// province level.
enum WardKind { ward, commune, specialZone, other }

WardKind classifyWard(String name) {
  final trimmed = name.trim();
  if (trimmed.startsWith('Phường')) return WardKind.ward;
  if (trimmed.startsWith('Xã')) return WardKind.commune;
  if (trimmed.startsWith('Đặc khu')) return WardKind.specialZone;
  return WardKind.other;
}

Map<WardKind, int> countWardsByKind(Iterable<String> wards) {
  final counts = {for (final kind in WardKind.values) kind: 0};
  for (final ward in wards) {
    final kind = classifyWard(ward);
    counts[kind] = counts[kind]! + 1;
  }
  return counts;
}
