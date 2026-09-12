import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Buổi (time-of-day bucket) a club's recurring schedule can fall into.
///
/// Coarser than the session `SessionTimeRange` on purpose — clubs are
/// filtered by recurring weekly activity, not a single session's start time,
/// so a three-bucket "buổi" reads more naturally than a four-bucket range.
enum ClubActivityPeriod {
  morning('morning'),
  afternoon('afternoon'),
  evening('evening');

  const ClubActivityPeriod(this.wireValue);
  final String wireValue;
}

/// Reactive-forms control-name constants for `ClubFilterSheet`.
abstract final class ClubBrowseFilterControl {
  static const city = 'city';
  static const districts = 'districts';
  static const activeDays = 'activeDays';
  static const activePeriods = 'activePeriods';
  static const levels = 'levels';
}

const _setEquality = SetEquality<Object?>();

/// Filter selection for club/CLB browsing ("Tìm nhóm").
///
/// Mirrors the shape of `BrowseSessionFilters` (city + wards via the shared
/// area picker, `cityIsDefault` so the ambient preferred city never counts as
/// an active filter) trimmed to what clubs support: area, recurring activity
/// time, and required skill level. Equality is set-aware because
/// `ClubsController.load` compares filter values to short-circuit reloads.
@immutable
class ClubBrowseFilters {
  const ClubBrowseFilters({
    this.city,
    this.cityIsDefault = true,
    this.districts = const {},
    this.activeDays = const {},
    this.activePeriods = const {},
    this.levels = const {},
  });

  final String? city;
  final bool cityIsDefault;

  /// Ward/commune names, as picked via `AppAreaFilterSection`.
  final Set<String> districts;

  /// Backend weekday numbering: 0 = Sunday … 6 = Saturday.
  final Set<int> activeDays;
  final Set<ClubActivityPeriod> activePeriods;

  /// Player level ids (see `PlayerLevel` — 1–8, 9 = beginner-, 10 = beginner+).
  final Set<int> levels;

  bool get isEmpty =>
      (city == null || cityIsDefault) &&
      districts.isEmpty &&
      activeDays.isEmpty &&
      activePeriods.isEmpty &&
      levels.isEmpty;

  int get activeCount =>
      (activeDays.isEmpty ? 0 : 1) +
      (activePeriods.isEmpty ? 0 : 1) +
      (levels.isEmpty ? 0 : 1);

  ClubBrowseFilters copyWith({
    String? city,
    bool clearCity = false,
    bool? cityIsDefault,
    Set<String>? districts,
    Set<int>? activeDays,
    Set<ClubActivityPeriod>? activePeriods,
    Set<int>? levels,
  }) => ClubBrowseFilters(
    city: clearCity ? null : city ?? this.city,
    cityIsDefault: cityIsDefault ?? this.cityIsDefault,
    districts: districts ?? this.districts,
    activeDays: activeDays ?? this.activeDays,
    activePeriods: activePeriods ?? this.activePeriods,
    levels: levels ?? this.levels,
  );

  /// Clears every filter except the ambient preferred city/wards.
  ClubBrowseFilters reset({
    String? preferredCity,
    Set<String> preferredDistricts = const {},
  }) => ClubBrowseFilters(city: preferredCity, districts: preferredDistricts);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClubBrowseFilters &&
          city == other.city &&
          cityIsDefault == other.cityIsDefault &&
          _setEquality.equals(districts, other.districts) &&
          _setEquality.equals(activeDays, other.activeDays) &&
          _setEquality.equals(activePeriods, other.activePeriods) &&
          _setEquality.equals(levels, other.levels));

  @override
  int get hashCode => Object.hash(
    city,
    cityIsDefault,
    _setEquality.hash(districts),
    _setEquality.hash(activeDays),
    _setEquality.hash(activePeriods),
    _setEquality.hash(levels),
  );
}
