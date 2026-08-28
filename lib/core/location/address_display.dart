/// The presentation value used for venue and session addresses.
///
/// The web app treats `newAddress` as a server-composed, complete address.
/// Therefore it must not be combined with the legacy district/city fields.
class AppAddressDisplayValue {
  const AppAddressDisplayValue({required this.text, required this.isNew});

  final String text;
  final bool isNew;

  bool get isEmpty => text.isEmpty;
}

/// Resolves the full address shown to a user.
///
/// This mirrors web `AppAddressDisplay` and `getVenueSearchSublabel`:
/// new-format text wins only when the preference is enabled and a complete
/// `newAddress` exists; otherwise the legacy fields are joined in order.
AppAddressDisplayValue resolveAppAddress({
  required bool showNewAddress,
  String? address,
  String? district,
  String? city,
  String? newAddress,
}) {
  final newText = _clean(newAddress);
  if (showNewAddress && newText != null) {
    return AppAddressDisplayValue(text: newText, isNew: true);
  }

  return AppAddressDisplayValue(
    text: _join(address, district, city),
    isNew: false,
  );
}

/// Resolves the compact area shown beside a venue name on a session card.
///
/// The web card shows the selected district/ward first and falls back to the
/// city. The administrative prefix is omitted for readable compact cards.
String? resolveCompactAddressArea({
  required bool showNewAddress,
  String? district,
  String? city,
  String? newDistrict,
  String? newCity,
}) {
  final selectedDistrict = showNewAddress
      ? _clean(newDistrict) ?? _clean(district)
      : _clean(district);
  final selectedCity = showNewAddress
      ? _clean(newCity) ?? _clean(city)
      : _clean(city);
  final area = selectedDistrict ?? selectedCity;
  if (area == null) return null;

  return area.replaceFirst(
    RegExp(
      '^(Ph\\u01b0\\u1eddng|X\\u00e3|Th\\u1ecb tr\\u1ea5n)\\s+(?=\\D)',
      caseSensitive: false,
    ),
    '',
  );
}

String _join(String? first, String? second, String? third) => [
  first,
  second,
  third,
].map(_clean).whereType<String>().join(', ');

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
