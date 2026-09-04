import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/domain/venue_edit_request.dart';

abstract final class VenueEditRequestControl {
  static const name = 'name';
  static const sportTypes = 'sportTypes';
  static const street = 'street';
  static const newCity = 'newCity';
  static const newDistrict = 'newDistrict';
  static const numberOfCourts = 'numberOfCourts';
  static const openTime = 'openTime';
  static const closeTime = 'closeTime';
  static const phone = 'phone';
  static const website = 'website';
  static const locatedWithin = 'locatedWithin';
  static const wifiName = 'wifiName';
  static const wifiPassword = 'wifiPassword';
  static const description = 'description';
  static const note = 'note';
}

Map<String, dynamic>? validateTrimmedLength(
  AbstractControl<dynamic> control,
  int minimum,
) {
  final value = (control.value as String? ?? '').trim();
  if (value.isEmpty) {
    return <String, dynamic>{ValidationMessage.required: true};
  }
  return value.length < minimum
      ? <String, dynamic>{ValidationMessage.minLength: minimum}
      : null;
}

FormGroup createVenueEditRequestForm(Venue venue) {
  final times = parseVenueOpeningHours(venue.openingHours);
  const supportedSports = {'BADMINTON', 'PICKLEBALL'};
  final venueSports = venue.sportTypes.isNotEmpty
      ? venue.sportTypes
      : <String>[venue.sportType ?? 'BADMINTON'];
  final sports = venueSports.where(supportedSports.contains).toSet();
  if (sports.isEmpty) sports.add('BADMINTON');
  return FormGroup({
    VenueEditRequestControl.name: FormControl<String>(
      value: venue.name,
      validators: [
        Validators.delegate((control) => validateTrimmedLength(control, 2)),
        Validators.maxLength(200),
      ],
    ),
    VenueEditRequestControl.sportTypes: FormControl<Set<String>>(
      value: sports,
      validators: [Validators.required],
    ),
    VenueEditRequestControl.street: FormControl<String>(
      value: venue.streetAddress ?? venue.address ?? '',
      validators: [
        Validators.delegate((control) => validateTrimmedLength(control, 3)),
        Validators.maxLength(500),
      ],
    ),
    VenueEditRequestControl.newCity: FormControl<String>(
      value: venue.newCity ?? venue.city ?? '',
      validators: [
        Validators.delegate((control) => validateTrimmedLength(control, 1)),
        Validators.maxLength(120),
      ],
    ),
    VenueEditRequestControl.newDistrict: FormControl<String>(
      value: venue.newDistrict ?? venue.district ?? '',
      validators: [
        Validators.delegate((control) => validateTrimmedLength(control, 1)),
        Validators.maxLength(120),
      ],
    ),
    VenueEditRequestControl.numberOfCourts: FormControl<int>(
      value: venue.numberOfCourts,
      validators: [Validators.min(1)],
    ),
    VenueEditRequestControl.openTime: FormControl<Duration>(value: times.open),
    VenueEditRequestControl.closeTime: FormControl<Duration>(
      value: times.close,
    ),
    VenueEditRequestControl.phone: FormControl<String>(
      value: venue.phone ?? '',
      validators: [Validators.maxLength(40)],
    ),
    VenueEditRequestControl.website: FormControl<String>(
      value: venue.website ?? '',
      validators: [Validators.maxLength(500)],
    ),
    VenueEditRequestControl.locatedWithin: FormControl<String>(
      value: venue.locatedWithin ?? '',
      validators: [Validators.maxLength(200)],
    ),
    VenueEditRequestControl.wifiName: FormControl<String>(
      value: venue.wifiName ?? '',
      validators: [Validators.maxLength(200)],
    ),
    VenueEditRequestControl.wifiPassword: FormControl<String>(
      value: venue.wifiPassword ?? '',
      validators: [Validators.maxLength(200)],
    ),
    VenueEditRequestControl.description: FormControl<String>(
      validators: [Validators.maxLength(5000)],
    ),
    VenueEditRequestControl.note: FormControl<String>(
      validators: [Validators.maxLength(2000)],
    ),
  });
}

VenueEditRequestDraft venueEditRequestDraftFromForm(FormGroup form) {
  T? value<T>(String name) => form.control(name).value as T?;
  return VenueEditRequestDraft(
    name: value<String>(VenueEditRequestControl.name) ?? '',
    sportTypes:
        value<Set<String>>(VenueEditRequestControl.sportTypes)?.toList() ??
        const [],
    street: value<String>(VenueEditRequestControl.street) ?? '',
    newCity: value<String>(VenueEditRequestControl.newCity) ?? '',
    newDistrict: value<String>(VenueEditRequestControl.newDistrict) ?? '',
    numberOfCourts: value<int>(VenueEditRequestControl.numberOfCourts),
    openingHours: formatVenueOpeningHours(
      value<Duration>(VenueEditRequestControl.openTime),
      value<Duration>(VenueEditRequestControl.closeTime),
    ),
    phone: value<String>(VenueEditRequestControl.phone),
    website: value<String>(VenueEditRequestControl.website),
    locatedWithin: value<String>(VenueEditRequestControl.locatedWithin),
    wifiName: value<String>(VenueEditRequestControl.wifiName),
    wifiPassword: value<String>(VenueEditRequestControl.wifiPassword),
    description: value<String>(VenueEditRequestControl.description),
    note: value<String>(VenueEditRequestControl.note),
  );
}

({Duration? open, Duration? close}) parseVenueOpeningHours(String? value) {
  if (value == null || value.trim().isEmpty) return (open: null, close: null);
  final parts = value.split(RegExp(r'\s*[-–—]\s*'));
  if (parts.length != 2) return (open: null, close: null);
  Duration? parse(String part) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(part.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return Duration(hours: hour, minutes: minute);
  }

  return (open: parse(parts[0]), close: parse(parts[1]));
}

String? formatVenueOpeningHours(Duration? open, Duration? close) {
  if (open == null && close == null) return null;
  String format(Duration value) =>
      '${value.inHours.toString().padLeft(2, '0')}:'
      '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}';
  return '${format(open ?? Duration.zero)} - '
      '${format(close ?? const Duration(hours: 23, minutes: 59))}';
}

final _adminKeywordPattern = RegExp(
  r'(?:^|[,\s])(phường|xã|thị\s+trấn|thị\s*xã|quận|huyện|thành\s+phố|tỉnh|p\.|q\.|h\.|tx\.|tt\.|tp\.)(?:\s+|\.|\d|$)',
  caseSensitive: false,
);

bool hasAdminUnitsInStreet(String value) =>
    value.trim().isNotEmpty && _adminKeywordPattern.hasMatch(value.trim());

String extractCleanStreetAddress(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.contains(',')) {
    final streetParts = <String>[];
    for (final part in trimmed.split(',').map((part) => part.trim())) {
      if (_adminKeywordPattern.hasMatch(part) ||
          RegExp(
            r'^(tp|tphcm|hcm|hn|hà nội|hồ chí minh)$',
            caseSensitive: false,
          ).hasMatch(part)) {
        break;
      }
      streetParts.add(part);
    }
    if (streetParts.isNotEmpty) return streetParts.join(', ').trim();
  }
  final match = _adminKeywordPattern.firstMatch(trimmed);
  if (match != null && match.start > 0) {
    return trimmed
        .substring(0, match.start)
        .replaceFirst(RegExp(r',\s*$'), '')
        .trim();
  }
  return trimmed;
}
