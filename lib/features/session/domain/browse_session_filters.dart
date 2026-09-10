enum SessionSource { all, regular, facebook }

enum SessionBrowseSort {
  dateAsc('date', 'asc'),
  dateDesc('date', 'desc'),
  newest('created', 'desc'),
  priceAsc('price', 'asc'),
  priceDesc('price', 'desc');

  const SessionBrowseSort(this.sortBy, this.sortOrder);

  final String sortBy;
  final String sortOrder;
}

enum SessionTimeRange {
  morning('morning'),
  afternoon('afternoon'),
  evening('evening'),
  night('night');

  const SessionTimeRange(this.wireValue);
  final String wireValue;
}

enum SessionSport {
  badminton('BADMINTON'),
  pickleball('PICKLEBALL');

  const SessionSport(this.wireValue);
  final String wireValue;
}

enum SessionCourtCountFilter {
  one(1, 1),
  two(2, 2),
  three(3, 3),
  fourPlus(4, null);

  const SessionCourtCountFilter(this.minCourts, this.maxCourts);

  final int minCourts;
  final int? maxCourts;
}

class BrowseSessionFilters {
  const BrowseSessionFilters({
    this.search = '',
    this.date,
    this.timeRanges = const {},
    this.levels = const {},
    this.sports = const {},
    this.courtCount,
    this.hasSlots = false,
    this.nearMe = false,
    this.source = SessionSource.all,
    this.city,
    this.cityIsDefault = true,
    this.districts = const {},
    this.minFee = defaultMinFee,
    this.maxFee = defaultMaxFee,
    this.splitEvenly = false,
    this.latitude,
    this.longitude,
    this.venueId,
    this.venueName,
    this.sort = SessionBrowseSort.dateAsc,
  });

  static const defaultMinFee = 0;
  static const defaultMaxFee = 200000;

  final String search;
  final DateTime? date;
  final Set<SessionTimeRange> timeRanges;
  final Set<int> levels;
  final Set<SessionSport> sports;
  final SessionCourtCountFilter? courtCount;
  final bool hasSlots;
  final bool nearMe;
  final SessionSource source;
  final String? city;
  final bool cityIsDefault;
  final Set<String> districts;
  final int minFee;
  final int maxFee;
  final bool splitEvenly;
  final double? latitude;
  final double? longitude;
  final String? venueId;
  final String? venueName;
  final SessionBrowseSort sort;

  bool get hasCustomFeeRange =>
      minFee != defaultMinFee || maxFee != defaultMaxFee;

  int get activeCount =>
      (date == null ? 0 : 1) +
      (timeRanges.isEmpty ? 0 : 1) +
      (levels.isEmpty ? 0 : 1) +
      (sports.isEmpty ? 0 : 1) +
      (courtCount == null ? 0 : 1) +
      (hasSlots ? 1 : 0) +
      (nearMe ? 1 : 0) +
      (source == SessionSource.all ? 0 : 1) +
      (city == null || cityIsDefault ? 0 : 1) +
      (districts.isEmpty ? 0 : 1) +
      (hasCustomFeeRange ? 1 : 0) +
      (splitEvenly ? 1 : 0) +
      (venueId == null ? 0 : 1);

  BrowseSessionFilters copyWith({
    String? search,
    DateTime? date,
    bool clearDate = false,
    Set<SessionTimeRange>? timeRanges,
    Set<int>? levels,
    Set<SessionSport>? sports,
    SessionCourtCountFilter? courtCount,
    bool clearCourtCount = false,
    bool? hasSlots,
    bool? nearMe,
    SessionSource? source,
    String? city,
    bool clearCity = false,
    bool? cityIsDefault,
    Set<String>? districts,
    int? minFee,
    int? maxFee,
    bool? splitEvenly,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    String? venueId,
    String? venueName,
    bool clearVenue = false,
    SessionBrowseSort? sort,
  }) => BrowseSessionFilters(
    search: search ?? this.search,
    date: clearDate ? null : date ?? this.date,
    timeRanges: timeRanges ?? this.timeRanges,
    levels: levels ?? this.levels,
    sports: sports ?? this.sports,
    courtCount: clearCourtCount ? null : courtCount ?? this.courtCount,
    hasSlots: hasSlots ?? this.hasSlots,
    nearMe: nearMe ?? this.nearMe,
    source: source ?? this.source,
    city: clearCity ? null : city ?? this.city,
    cityIsDefault: cityIsDefault ?? this.cityIsDefault,
    districts: districts ?? this.districts,
    minFee: minFee ?? this.minFee,
    maxFee: maxFee ?? this.maxFee,
    splitEvenly: splitEvenly ?? this.splitEvenly,
    latitude: clearCoordinates ? null : latitude ?? this.latitude,
    longitude: clearCoordinates ? null : longitude ?? this.longitude,
    venueId: clearVenue ? null : venueId ?? this.venueId,
    venueName: clearVenue ? null : venueName ?? this.venueName,
    sort: sort ?? this.sort,
  );

  BrowseSessionFilters reset({String? preferredCity}) => BrowseSessionFilters(
    search: search,
    city: preferredCity,
    venueId: venueId,
    venueName: venueName,
    sort: sort,
  );
}
