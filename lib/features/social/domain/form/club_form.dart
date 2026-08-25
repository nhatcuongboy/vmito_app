import 'package:reactive_forms/reactive_forms.dart';

/// Stable names shared by the club form and its tests.
abstract final class ClubFormControl {
  static const name = 'name';
  static const hostName = 'hostName';
  static const hostUserId = 'hostUserId';
  static const description = 'description';
  static const location = 'location';
  static const maxMembers = 'maxMembers';
  static const joinPolicy = 'joinPolicy';
  static const isPublic = 'isPublic';
  static const requiredLevels = 'requiredLevels';
  static const images = 'images';
  static const imagePublicIds = 'imagePublicIds';
  static const bannerIndex = 'bannerIndex';
  static const logo = 'logo';
  static const logoPublicId = 'logoPublicId';
  static const socialFacebook = 'socialFacebook';
  static const socialZalo = 'socialZalo';
  static const socialTiktok = 'socialTiktok';
  static const socialYoutube = 'socialYoutube';
  static const socialWebsite = 'socialWebsite';
  static const socialOther = 'socialOther';
}

class ClubScheduleDraft {
  const ClubScheduleDraft({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;
}

class ClubVenueGroupDraft {
  const ClubVenueGroupDraft({
    required this.id,
    this.venueId = '',
    this.schedules = const [],
  });

  final String id;
  final String venueId;
  final List<ClubScheduleDraft> schedules;

  ClubVenueGroupDraft copyWith({
    String? venueId,
    List<ClubScheduleDraft>? schedules,
  }) => ClubVenueGroupDraft(
    id: id,
    venueId: venueId ?? this.venueId,
    schedules: schedules ?? this.schedules,
  );
}

enum ClubVenueErrorKey { venueRequired, duplicateVenue }

enum ClubScheduleErrorKey { invalidTime, endBeforeStart, overlap }

class ClubVenueScheduleValidation {
  const ClubVenueScheduleValidation({
    required this.isValid,
    this.venueErrors = const {},
    this.scheduleErrors = const {},
  });

  final bool isValid;
  final Map<String, ClubVenueErrorKey> venueErrors;
  final Map<String, ClubScheduleErrorKey> scheduleErrors;
}

FormGroup createClubForm({
  required String hostName,
  String? name,
  String? description,
  String? location,
  int? maxMembers,
  String joinPolicy = 'APPROVAL_REQUIRED',
  bool isPublic = true,
  String? selectedHostUserId,
  List<int> requiredLevels = const [],
  List<String> images = const [],
  List<String> imagePublicIds = const [],
  int bannerIndex = 0,
  String? logo,
  String? logoPublicId,
  Map<String, String> socialLinks = const {},
}) => FormGroup({
  ClubFormControl.name: FormControl<String>(
    value: name ?? '',
    validators: [Validators.required, Validators.maxLength(50)],
  ),
  ClubFormControl.hostName: FormControl<String>(
    value: hostName,
    validators: [Validators.required, Validators.maxLength(100)],
  ),
  ClubFormControl.hostUserId: FormControl<String>(
    value: selectedHostUserId ?? '',
  ),
  ClubFormControl.description: FormControl<String>(
    value: description ?? '',
    validators: [Validators.maxLength(5000)],
  ),
  ClubFormControl.location: FormControl<String>(
    value: location ?? '',
    validators: [Validators.maxLength(200)],
  ),
  ClubFormControl.maxMembers: FormControl<String>(
    value: maxMembers?.toString() ?? '',
    validators: [
      Validators.delegate((control) {
        final value = (control.value as String?)?.trim() ?? '';
        if (value.isEmpty) return null;
        final parsed = int.tryParse(value);
        return parsed == null || parsed < 1 || parsed > 500
            ? {'clubMaxMembers': true}
            : null;
      }),
    ],
  ),
  ClubFormControl.joinPolicy: FormControl<String>(value: joinPolicy),
  ClubFormControl.isPublic: FormControl<bool>(value: isPublic),
  ClubFormControl.requiredLevels: FormControl<List<int>>(
    value: [...requiredLevels],
  ),
  ClubFormControl.images: FormControl<List<String>>(value: [...images]),
  ClubFormControl.imagePublicIds: FormControl<List<String>>(
    value: [...imagePublicIds],
  ),
  ClubFormControl.bannerIndex: FormControl<int>(value: bannerIndex),
  ClubFormControl.logo: FormControl<String>(value: logo ?? ''),
  ClubFormControl.logoPublicId: FormControl<String>(value: logoPublicId ?? ''),
  ClubFormControl.socialFacebook: FormControl<String>(
    value: socialLinks['facebook'] ?? '',
  ),
  ClubFormControl.socialZalo: FormControl<String>(
    value: socialLinks['zalo'] ?? '',
  ),
  ClubFormControl.socialTiktok: FormControl<String>(
    value: socialLinks['tiktok'] ?? '',
  ),
  ClubFormControl.socialYoutube: FormControl<String>(
    value: socialLinks['youtube'] ?? '',
  ),
  ClubFormControl.socialWebsite: FormControl<String>(
    value: socialLinks['website'] ?? '',
  ),
  ClubFormControl.socialOther: FormControl<String>(
    value: socialLinks['other'] ?? '',
  ),
});

ClubVenueScheduleValidation validateClubVenueSchedule(
  List<ClubVenueGroupDraft> groups,
) {
  final venueErrors = <String, ClubVenueErrorKey>{};
  final scheduleErrors = <String, ClubScheduleErrorKey>{};
  final venueCounts = <String, int>{};

  for (final group in groups) {
    if (group.venueId.isNotEmpty) {
      venueCounts[group.venueId] = (venueCounts[group.venueId] ?? 0) + 1;
    }
  }

  for (final group in groups) {
    if (group.venueId.isEmpty) {
      venueErrors[group.id] = ClubVenueErrorKey.venueRequired;
    } else if ((venueCounts[group.venueId] ?? 0) > 1) {
      venueErrors[group.id] = ClubVenueErrorKey.duplicateVenue;
    }
  }

  final schedulesByVenueAndDay =
      <String, List<({ClubScheduleDraft schedule, int start, int end})>>{};

  for (final group in groups) {
    for (final schedule in group.schedules) {
      final start = _timeToMinutes(schedule.startTime);
      final end = _timeToMinutes(schedule.endTime);
      if (start == null || end == null) {
        scheduleErrors[schedule.id] = ClubScheduleErrorKey.invalidTime;
        continue;
      }
      if (end <= start) {
        scheduleErrors[schedule.id] = ClubScheduleErrorKey.endBeforeStart;
        continue;
      }
      if (group.venueId.isEmpty) continue;
      final key = '${group.venueId}:${schedule.dayOfWeek}';
      schedulesByVenueAndDay.putIfAbsent(key, () => []).add(
        (schedule: schedule, start: start, end: end),
      );
    }
  }

  for (final schedules in schedulesByVenueAndDay.values) {
    final sorted = [...schedules]..sort((a, b) => a.start - b.start);
    for (var index = 0; index < sorted.length; index++) {
      final current = sorted[index];
      for (final candidate in sorted.skip(index + 1)) {
        if (candidate.start >= current.end) continue;
        scheduleErrors[current.schedule.id] = ClubScheduleErrorKey.overlap;
        scheduleErrors[candidate.schedule.id] = ClubScheduleErrorKey.overlap;
      }
    }
  }

  return ClubVenueScheduleValidation(
    isValid: venueErrors.isEmpty && scheduleErrors.isEmpty,
    venueErrors: venueErrors,
    scheduleErrors: scheduleErrors,
  );
}

int? _timeToMinutes(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hours = int.tryParse(match.group(1)!);
  final minutes = int.tryParse(match.group(2)!);
  if (hours == null || minutes == null || hours > 23 || minutes > 59) {
    return null;
  }
  return hours * 60 + minutes;
}
