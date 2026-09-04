class VenueEditRequestDraft {
  const VenueEditRequestDraft({
    required this.name,
    required this.sportTypes,
    required this.street,
    required this.newCity,
    required this.newDistrict,
    this.numberOfCourts,
    this.openingHours,
    this.phone,
    this.website,
    this.locatedWithin,
    this.wifiName,
    this.wifiPassword,
    this.description,
    this.note,
  });

  final String name;
  final List<String> sportTypes;
  final String street;
  final String newCity;
  final String newDistrict;
  final int? numberOfCourts;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? locatedWithin;
  final String? wifiName;
  final String? wifiPassword;
  final String? description;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'sportTypes': sportTypes,
    'street': street.trim(),
    'newCity': newCity.trim(),
    'newDistrict': newDistrict.trim(),
    if (numberOfCourts != null) 'numberOfCourts': numberOfCourts,
    'openingHours': ?_optional(openingHours),
    'phone': ?_phone(phone),
    'website': ?_optional(website),
    'locatedWithin': ?_optional(locatedWithin),
    'wifiName': ?_optional(wifiName),
    'wifiPassword': ?_optional(wifiPassword),
    'description': ?_optional(description),
    'note': ?_optional(note),
  };
}

String? _optional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _phone(String? value) {
  final compact = value?.replaceAll(RegExp(r'\s+'), '').trim();
  return compact == null || compact.isEmpty ? null : compact;
}
