import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

abstract final class VenueFilterControl {
  static const city = 'city';
  static const district = 'district';
  static const sortBy = 'sortBy';
  static const favoriteOnly = 'favoriteOnly';
}

FormGroup createVenueFilterForm(VenueFilter initial) => FormGroup({
  VenueFilterControl.city: FormControl<String>(value: initial.city),
  VenueFilterControl.district: FormControl<String>(value: initial.district),
  VenueFilterControl.sortBy: FormControl<String>(
    value: initial.sortBy,
    validators: [Validators.required],
  ),
  VenueFilterControl.favoriteOnly: FormControl<bool>(
    value: initial.favoriteOnly,
  ),
});

VenueFilter venueFilterFromForm({
  required FormGroup form,
  required VenueFilter initial,
  String? preferredCity,
  double? latitude,
  double? longitude,
}) {
  String? normalizedText(String controlName) {
    final value = (form.control(controlName).value as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  final sortBy =
      form.control(VenueFilterControl.sortBy).value as String? ?? 'relevance';
  final city = normalizedText(VenueFilterControl.city);
  return VenueFilter(
    keyword: initial.keyword,
    city: city,
    cityIsDefault: city == preferredCity,
    district: normalizedText(VenueFilterControl.district),
    sortBy: sortBy,
    favoriteOnly:
        form.control(VenueFilterControl.favoriteOnly).value as bool? ?? false,
    latitude: sortBy == 'distance' ? latitude : null,
    longitude: sortBy == 'distance' ? longitude : null,
    sportType: initial.sportType,
  );
}
