import 'package:vmito_app/core/location/address_display.dart';

class Venue {
  const Venue({
    required this.id,
    required this.name,
    this.slug,
    this.address,
    this.streetAddress,
    this.district,
    this.city,
    this.newAddress,
    this.newDistrict,
    this.newCity,
    this.description,
    this.coverPhoto,
    this.logo,
    this.images = const [],
    this.courtLayoutImage,
    this.phone,
    this.website,
    this.openingHours,
    this.numberOfCourts,
    this.hourlyRateFixed,
    this.lat,
    this.lng,
    this.distance,
    this.isVerified = false,
    this.isFavorite = false,
    this.closureStatus = 'OPERATING',
    this.amenities = const [],
    this.sportType,
    this.sportTypes = const [],
    this.hasCarParking,
    this.hasCanteen,
    this.wifiName,
    this.wifiPassword,
    this.bookingPolicy,
    this.locatedWithin,
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String?,
    address: json['address'] as String?,
    streetAddress: json['streetAddress'] as String?,
    district: json['district'] as String?,
    city: json['city'] as String?,
    newAddress: json['newAddress'] as String?,
    newDistrict: json['newDistrict'] as String?,
    newCity: json['newCity'] as String?,
    description: json['description'] as String?,
    coverPhoto: json['coverPhoto'] as String?,
    logo: json['logo'] as String?,
    images: (json['images'] as List<dynamic>? ?? const [])
        .map(
          (item) => item is String
              ? item
              : item is Map
              ? item['url'] as String?
              : null,
        )
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false),
    courtLayoutImage: json['courtLayoutImage'] as String?,
    phone: json['phone'] as String?,
    website: json['website'] as String?,
    openingHours: json['openingHours'] as String?,
    numberOfCourts: (json['numberOfCourts'] as num?)?.toInt(),
    hourlyRateFixed: (json['hourlyRateFixed'] as num?)?.toInt(),
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    distance: (json['distance'] as num?)?.toDouble(),
    isVerified: json['isVerified'] as bool? ?? false,
    isFavorite: json['isFavorite'] as bool? ?? false,
    closureStatus: json['closureStatus'] as String? ?? 'OPERATING',
    amenities: (json['amenities'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    sportType: json['sportType'] as String?,
    sportTypes: (json['sportTypes'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    hasCarParking: json['hasCarParking'] as bool?,
    hasCanteen: json['hasCanteen'] as bool?,
    wifiName: json['wifiName'] as String?,
    wifiPassword: json['wifiPassword'] as String?,
    bookingPolicy: json['bookingPolicy'] as String?,
    locatedWithin: json['locatedWithin'] as String?,
  );

  final String id;
  final String name;
  final String? slug;
  final String? address;
  final String? streetAddress;
  final String? district;
  final String? city;
  final String? newAddress;
  final String? newDistrict;
  final String? newCity;
  final String? description;
  final String? coverPhoto;
  final String? logo;
  final List<String> images;
  final String? courtLayoutImage;
  final String? phone;
  final String? website;
  final String? openingHours;
  final int? numberOfCourts;
  final int? hourlyRateFixed;
  final double? lat;
  final double? lng;
  final double? distance;
  final bool isVerified;
  final bool isFavorite;
  final String closureStatus;
  final List<String> amenities;
  final String? sportType;
  final List<String> sportTypes;
  final bool? hasCarParking;
  final bool? hasCanteen;
  final String? wifiName;
  final String? wifiPassword;
  final String? bookingPolicy;
  final String? locatedWithin;

  String displayName({
    required String generic,
    required Map<String, String> bySport,
    required String localeName,
  }) {
    // Vietnamese always shows the "Sân" prefix; a Vietnamese affix already
    // in the raw name (e.g. "Sân ABC") is the only case that skips it.
    if (localeName == 'vi') {
      return _hasVietnameseVenueNameAffix(name) ? name : generic;
    }
    if (_hasVenueNameAffix(name)) return name;
    final sports = sportTypes.isNotEmpty
        ? sportTypes
        : [sportType ?? 'BADMINTON'];
    if (sports.length > 1) return generic;
    return bySport[sports.first] ?? bySport['BADMINTON'] ?? generic;
  }

  bool get hasAddressData => [
    address,
    district,
    city,
    newAddress,
    newDistrict,
    newCity,
  ].any((value) => value?.trim().isNotEmpty ?? false);

  String addressLabel({required bool showNewAddress}) => resolveAppAddress(
    showNewAddress: showNewAddress,
    address: address,
    district: district,
    city: city,
    newAddress: newAddress,
    newDistrict: newDistrict,
    newCity: newCity,
  ).text;

  List<String> get gallery => [
    if (coverPhoto?.isNotEmpty ?? false) coverPhoto!,
    ...images.where((image) => image != coverPhoto),
  ];
}

const _sportNameKeywords = [
  'cầu lông',
  'badminton',
  'pickleball',
  'pickle ball',
  '羽毛球',
  '匹克球',
];

bool _hasVenueNameAffix(String name) {
  final lowerName = name.toLowerCase();
  return _hasVietnameseVenueNameAffix(name) ||
      lowerName.endsWith(' court') ||
      lowerName.endsWith(' club') ||
      lowerName.endsWith('场') ||
      lowerName.endsWith('俱乐部') ||
      _sportNameKeywords.any(lowerName.contains);
}

bool _hasVietnameseVenueNameAffix(String name) {
  final lowerName = name.toLowerCase();
  return lowerName.startsWith('sân ') ||
      lowerName.startsWith('sân.') ||
      lowerName.startsWith('clb ') ||
      lowerName.startsWith('câu lạc bộ ') ||
      lowerName.startsWith('câu lạc bộ\n');
}

class VenuePage {
  const VenuePage({
    required this.venues,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory VenuePage.fromJson(dynamic payload) {
    final json = payload as Map<String, dynamic>;
    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    final raw = json['data'] as List<dynamic>? ?? const [];
    return VenuePage(
      venues: raw
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList(growable: false),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
      total: (pagination['total'] as num?)?.toInt() ?? raw.length,
    );
  }
  final List<Venue> venues;
  final int page;
  final int totalPages;
  final int total;
}

class VenuePriceBook {
  const VenuePriceBook({
    required this.id,
    required this.isActive,
    required this.effectiveFrom,
    required this.rules,
    this.priority = 0,
    this.notes,
  });
  factory VenuePriceBook.fromJson(Map<String, dynamic> json) => VenuePriceBook(
    id: json['id'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
    effectiveFrom:
        DateTime.tryParse(json['effectiveFrom'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    priority: (json['priority'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String?,
    rules: (json['rules'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VenuePriceRule.fromJson)
        .toList(growable: false),
  );
  final String id;
  final bool isActive;
  final DateTime effectiveFrom;
  final int priority;
  final String? notes;
  final List<VenuePriceRule> rules;
}

class VenuePriceRule {
  const VenuePriceRule({
    required this.dayType,
    required this.customerType,
    required this.startMinute,
    required this.endMinute,
    required this.pricePerHour,
    this.daysOfWeek = const [],
    this.specificDate,
  });
  factory VenuePriceRule.fromJson(Map<String, dynamic> json) => VenuePriceRule(
    dayType: json['dayType'] as String? ?? 'EVERYDAY',
    customerType: json['customerType'] as String? ?? 'FIXED',
    startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
    endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
    pricePerHour: (json['pricePerHour'] as num?)?.toInt() ?? 0,
    daysOfWeek: (json['daysOfWeek'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((day) => day.toInt())
        .toList(growable: false),
    specificDate: json['specificDate'] as String?,
  );
  final String dayType;
  final String customerType;
  final int startMinute;
  final int endMinute;
  final int pricePerHour;
  final List<int> daysOfWeek;
  final String? specificDate;
}

enum VenueSport {
  badminton('BADMINTON'),
  pickleball('PICKLEBALL');

  const VenueSport(this.wireValue);
  final String wireValue;

  static VenueSport? fromWireValue(String? wireValue) {
    if (wireValue == null) return null;
    final upper = wireValue.toUpperCase();
    for (final sport in values) {
      if (sport.wireValue == upper) return sport;
    }
    return null;
  }
}

enum VenueCourtCountFilter {
  one(1, 1),
  two(2, 2),
  three(3, 3),
  fourPlus(4, null);

  const VenueCourtCountFilter(this.minCourts, this.maxCourts);
  final int minCourts;
  final int? maxCourts;
}

class VenueFilter {
  const VenueFilter({
    this.keyword = '',
    this.city,
    this.cityIsDefault = true,
    this.district,
    this.districts = const {},
    this.sortBy = 'distance',
    this.favoriteOnly = false,
    this.latitude,
    this.longitude,
    this.sportType,
    this.sports = const {},
    this.courtCount,
  });

  final String keyword;
  final String? city;
  final bool cityIsDefault;
  final String? district;
  final Set<String> districts;
  final String sortBy;
  final bool favoriteOnly;
  final double? latitude;
  final double? longitude;
  final String? sportType;
  final Set<VenueSport> sports;
  final VenueCourtCountFilter? courtCount;

  int get activeCount =>
      sports.length + (courtCount != null ? 1 : 0) + (favoriteOnly ? 1 : 0);

  VenueFilter copyWith({
    String? keyword,
    String? city,
    bool? cityIsDefault,
    String? district,
    Set<String>? districts,
    String? sortBy,
    bool? favoriteOnly,
    double? latitude,
    double? longitude,
    String? sportType,
    Set<VenueSport>? sports,
    VenueCourtCountFilter? courtCount,
    bool clearLocation = false,
    bool clearCity = false,
    bool clearDistrict = false,
    bool clearDistricts = false,
    bool clearSports = false,
    bool clearCourtCount = false,
  }) => VenueFilter(
    keyword: keyword ?? this.keyword,
    city: clearCity ? null : city ?? this.city,
    cityIsDefault: cityIsDefault ?? this.cityIsDefault,
    district: clearDistrict ? null : district ?? this.district,
    districts: (clearDistricts || clearDistrict)
        ? const {}
        : districts ?? this.districts,
    sortBy: sortBy ?? this.sortBy,
    favoriteOnly: favoriteOnly ?? this.favoriteOnly,
    latitude: clearLocation ? null : latitude ?? this.latitude,
    longitude: clearLocation ? null : longitude ?? this.longitude,
    sportType: sportType ?? this.sportType,
    sports: clearSports ? const {} : sports ?? this.sports,
    courtCount: clearCourtCount ? null : courtCount ?? this.courtCount,
  );
}
