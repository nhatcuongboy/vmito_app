import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

abstract final class VenueFilterControl {
  static const sports = 'sports';
  static const city = 'city';
  static const district = 'district';
  static const districts = 'districts';
  static const courtCount = 'courtCount';
  static const sortBy = 'sortBy';
  static const favoriteOnly = 'favoriteOnly';
}

FormGroup createVenueFilterForm(VenueFilter initial) {
  final initialDistricts = initial.districts.isNotEmpty
      ? {...initial.districts}
      : (initial.district != null && initial.district!.trim().isNotEmpty
          ? {initial.district!.trim()}
          : <String>{});
  final initialSports = initial.sports.isNotEmpty
      ? {...initial.sports}
      : (initial.sportType != null
          ? {?VenueSport.fromWireValue(initial.sportType)}
          : <VenueSport>{});

  return FormGroup({
    VenueFilterControl.sports: FormControl<Set<VenueSport>>(
      value: initialSports,
    ),
    VenueFilterControl.city: FormControl<String>(value: initial.city),
    VenueFilterControl.district: FormControl<String>(value: initial.district),
    VenueFilterControl.districts: FormControl<Set<String>>(
      value: initialDistricts,
    ),
    VenueFilterControl.courtCount: FormControl<VenueCourtCountFilter>(
      value: initial.courtCount,
    ),
    VenueFilterControl.favoriteOnly: FormControl<bool>(
      value: initial.favoriteOnly,
    ),
  });
}

VenueFilter venueFilterFromForm({
  required FormGroup form,
  required VenueFilter initial,
  String? preferredCity,
  double? latitude,
  double? longitude,
}) {
  String? normalizedText(String controlName) {
    if (!form.contains(controlName)) return null;
    final value = (form.control(controlName).value as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  T? controlValue<T>(String controlName) {
    if (!form.contains(controlName)) return null;
    return form.control(controlName).value as T?;
  }

  final city = normalizedText(VenueFilterControl.city);
  final districts =
      controlValue<Set<String>>(VenueFilterControl.districts) ??
      const <String>{};
  final sports =
      controlValue<Set<VenueSport>>(VenueFilterControl.sports) ??
      const <VenueSport>{};
  final courtCount = controlValue<VenueCourtCountFilter>(
    VenueFilterControl.courtCount,
  );
  final favoriteOnly =
      controlValue<bool>(VenueFilterControl.favoriteOnly) ?? false;
  final district = districts.isNotEmpty
      ? districts.join(',')
      : normalizedText(VenueFilterControl.district);

  return VenueFilter(
    keyword: initial.keyword,
    city: city,
    cityIsDefault: city == preferredCity,
    district: district,
    districts: districts,
    sortBy: initial.sortBy,
    favoriteOnly: favoriteOnly,
    latitude: initial.sortBy == 'distance'
        ? (latitude ?? initial.latitude)
        : null,
    longitude: initial.sortBy == 'distance'
        ? (longitude ?? initial.longitude)
        : null,
    sportType: sports.isNotEmpty
        ? sports.map((s) => s.wireValue).join(',')
        : null,
    sports: sports,
    courtCount: courtCount,
  );
}
