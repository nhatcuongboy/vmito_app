import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_state.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/shared/models/match.dart';

abstract final class SessionFormControl {
  static const name = 'name';
  static const sportType = 'sportType';
  static const description = 'description';
  static const locationKind = 'locationKind';
  static const venueId = 'venueId';
  static const venueLabel = 'venueLabel';
  static const venueSublabel = 'venueSublabel';
  static const customLocationName = 'customLocationName';
  static const customLocationAddress = 'customLocationAddress';
  static const customLocationPlaceId = 'customLocationPlaceId';
  static const customLocationLat = 'customLocationLat';
  static const customLocationLng = 'customLocationLng';
  static const customLocationDistrict = 'customLocationDistrict';
  static const customLocationCity = 'customLocationCity';
  static const customLocationFromAi = 'customLocationFromAi';
  static const hostName = 'hostName';
  static const hostPhone = 'hostPhone';
  static const allowZaloContact = 'allowZaloContact';
  static const isMultiDay = 'isMultiDay';
  static const sessionDate = 'sessionDate';
  static const startTimeOfDay = 'startTimeOfDay';
  static const endTimeOfDay = 'endTimeOfDay';
  static const multiDayStart = 'multiDayStart';
  static const multiDayEnd = 'multiDayEnd';
  static const courts = 'courts';
  static const allLevels = 'allLevels';
  static const requiredLevels = 'requiredLevels';
  static const feeEnabled = 'feeEnabled';
  static const feeType = 'feeType';
  static const maleFee = 'maleFee';
  static const femaleFee = 'femaleFee';
  static const feeNotes = 'feeNotes';
  static const bulkEnabled = 'bulkEnabled';
  static const bulkMode = 'bulkMode';
  static const bulkDates = 'bulkDates';
  static const bulkWeekdays = 'bulkWeekdays';
  static const bulkWeeks = 'bulkWeeks';
  static const images = 'images';
  static const bannerPublicId = 'bannerPublicId';
  static const courtColor = 'courtColor';
  static const matchType = 'matchType';
  static const shuttlecock = 'shuttlecock';
  static const maxPlayers = 'maxPlayers';
  static const referenceVideo = 'referenceVideo';
  static const clubId = 'clubId';
  static const clubLabel = 'clubLabel';

  static const courtId = 'id';
  static const courtKey = 'key';
  static const courtNumber = 'number';
  static const courtName = 'courtName';
}

FormGroup createSessionReactiveForm(SessionFormState state) => FormGroup({
  SessionFormControl.name: FormControl<String>(
    value: state.name,
    validators: [Validators.required],
  ),
  SessionFormControl.sportType: FormControl<SessionSportType>(
    value: state.sportType,
    validators: [Validators.required],
  ),
  SessionFormControl.description: FormControl<String>(value: state.description),
  SessionFormControl.locationKind: FormControl<SessionLocationKind>(
    value: state.locationKind,
  ),
  SessionFormControl.venueId: FormControl<String>(value: state.selectedVenueId),
  SessionFormControl.venueLabel: FormControl<String>(
    value: state.selectedVenueLabel,
  ),
  SessionFormControl.venueSublabel: FormControl<String>(
    value: state.selectedVenueSublabel,
  ),
  SessionFormControl.customLocationName: FormControl<String>(
    value: state.customLocationName,
  ),
  SessionFormControl.customLocationAddress: FormControl<String>(
    value: state.customLocationAddress,
  ),
  SessionFormControl.customLocationPlaceId: FormControl<String>(
    value: state.customLocationPlaceId,
  ),
  SessionFormControl.customLocationLat: FormControl<double>(
    value: state.customLocationLat,
  ),
  SessionFormControl.customLocationLng: FormControl<double>(
    value: state.customLocationLng,
  ),
  SessionFormControl.customLocationDistrict: FormControl<String>(
    value: state.customLocationDistrict,
  ),
  SessionFormControl.customLocationCity: FormControl<String>(
    value: state.customLocationCity,
  ),
  SessionFormControl.customLocationFromAi: FormControl<bool>(
    value: state.customLocationFromAi,
  ),
  SessionFormControl.hostName: FormControl<String>(
    value: state.hostName,
    validators: [Validators.required],
  ),
  SessionFormControl.hostPhone: FormControl<String>(value: state.hostPhone),
  SessionFormControl.allowZaloContact: FormControl<bool>(
    value: state.allowZaloContact,
  ),
  SessionFormControl.isMultiDay: FormControl<bool>(value: state.isMultiDay),
  SessionFormControl.sessionDate: FormControl<DateTime>(
    value: state.sessionDate,
  ),
  SessionFormControl.startTimeOfDay: FormControl<Duration>(
    value: state.startTimeOfDay,
  ),
  SessionFormControl.endTimeOfDay: FormControl<Duration>(
    value: state.endTimeOfDay,
  ),
  SessionFormControl.multiDayStart: FormControl<DateTime>(
    value: state.multiDayStart,
  ),
  SessionFormControl.multiDayEnd: FormControl<DateTime>(
    value: state.multiDayEnd,
  ),
  SessionFormControl.courts: FormArray<Map<String, Object?>>([
    for (final court in state.courts) sessionCourtForm(court),
  ]),
  SessionFormControl.allLevels: FormControl<bool>(
    value: state.allLevelsSelected,
  ),
  SessionFormControl.requiredLevels: FormControl<List<int>>(
    value: state.requiredLevels,
  ),
  SessionFormControl.feeEnabled: FormControl<bool>(value: state.feeEnabled),
  SessionFormControl.feeType: FormControl<FeeType>(value: state.feeType),
  SessionFormControl.maleFee: FormControl<int>(value: state.maleFee),
  SessionFormControl.femaleFee: FormControl<int>(value: state.femaleFee),
  SessionFormControl.feeNotes: FormControl<String>(value: state.feeNotes),
  SessionFormControl.bulkEnabled: FormControl<bool>(value: state.bulkEnabled),
  SessionFormControl.bulkMode: FormControl<BulkCreationMode>(
    value: state.bulkMode,
  ),
  SessionFormControl.bulkDates: FormControl<List<DateTime>>(
    value: state.bulkDates,
  ),
  SessionFormControl.bulkWeekdays: FormControl<List<int>>(
    value: state.bulkWeekdays,
  ),
  SessionFormControl.bulkWeeks: FormControl<int>(
    value: state.bulkNumberOfWeeks,
  ),
  SessionFormControl.images: FormControl<List<SessionImageDraft>>(
    value: state.images,
  ),
  SessionFormControl.bannerPublicId: FormControl<String>(
    value: state.bannerPublicId,
  ),
  SessionFormControl.courtColor: FormControl<String>(value: state.courtColor),
  SessionFormControl.matchType: FormControl<MatchType>(
    value: state.defaultMatchType,
  ),
  SessionFormControl.shuttlecock: FormControl<String>(value: state.shuttlecock),
  SessionFormControl.maxPlayers: FormControl<int>(
    value: state.maxPlayersPerCourt,
    validators: [Validators.min(2), Validators.max(12)],
  ),
  SessionFormControl.referenceVideo: FormControl<String>(
    value: state.referenceVideoUrl,
  ),
  SessionFormControl.clubId: FormControl<String>(value: state.clubId),
  SessionFormControl.clubLabel: FormControl<String>(value: state.clubLabel),
});

FormGroup sessionCourtForm(SessionCourtDraft court) => FormGroup({
  SessionFormControl.courtKey: FormControl<String>(value: court.key),
  SessionFormControl.courtId: FormControl<String>(value: court.courtId),
  SessionFormControl.courtNumber: FormControl<int>(
    value: court.courtNumber,
    validators: [Validators.min(1)],
  ),
  SessionFormControl.courtName: FormControl<String>(value: court.courtName),
});

extension SessionReactiveFormValue on FormGroup {
  T? sessionValue<T>(String name) => control(name).value as T?;

  SessionFormState toSessionFormState({
    required SessionFormState base,
  }) {
    final courtArray =
        control(SessionFormControl.courts) as FormArray<Map<String, Object?>>;
    return base.copyWith(
      name: sessionValue<String>(SessionFormControl.name) ?? '',
      sportType:
          sessionValue<SessionSportType>(SessionFormControl.sportType) ??
          SessionSportType.badminton,
      description: sessionValue<String>(SessionFormControl.description) ?? '',
      locationKind:
          sessionValue<SessionLocationKind>(SessionFormControl.locationKind) ??
          SessionLocationKind.venue,
      selectedVenueId: sessionValue<String>(SessionFormControl.venueId) ?? '',
      selectedVenueLabel:
          sessionValue<String>(SessionFormControl.venueLabel) ?? '',
      selectedVenueSublabel:
          sessionValue<String>(SessionFormControl.venueSublabel) ?? '',
      customLocationName:
          sessionValue<String>(SessionFormControl.customLocationName) ?? '',
      customLocationAddress:
          sessionValue<String>(SessionFormControl.customLocationAddress) ?? '',
      customLocationPlaceId:
          sessionValue<String>(SessionFormControl.customLocationPlaceId) ?? '',
      customLocationLat: sessionValue<double>(
        SessionFormControl.customLocationLat,
      ),
      customLocationLng: sessionValue<double>(
        SessionFormControl.customLocationLng,
      ),
      customLocationDistrict:
          sessionValue<String>(SessionFormControl.customLocationDistrict) ?? '',
      customLocationCity:
          sessionValue<String>(SessionFormControl.customLocationCity) ?? '',
      customLocationFromAi:
          sessionValue<bool>(SessionFormControl.customLocationFromAi) ?? false,
      hostName: sessionValue<String>(SessionFormControl.hostName) ?? '',
      hostPhone: sessionValue<String>(SessionFormControl.hostPhone) ?? '',
      allowZaloContact:
          sessionValue<bool>(SessionFormControl.allowZaloContact) ?? false,
      isMultiDay: sessionValue<bool>(SessionFormControl.isMultiDay) ?? false,
      sessionDate: sessionValue<DateTime>(SessionFormControl.sessionDate),
      startTimeOfDay: sessionValue<Duration>(SessionFormControl.startTimeOfDay),
      endTimeOfDay: sessionValue<Duration>(SessionFormControl.endTimeOfDay),
      multiDayStart: sessionValue<DateTime>(SessionFormControl.multiDayStart),
      multiDayEnd: sessionValue<DateTime>(SessionFormControl.multiDayEnd),
      courts: [
        for (final item in courtArray.controls)
          SessionCourtDraft(
            key:
                (item as FormGroup).control(SessionFormControl.courtKey).value
                    as String,
            courtId: item.control(SessionFormControl.courtId).value as String?,
            courtNumber:
                item.control(SessionFormControl.courtNumber).value as int? ?? 0,
            courtName:
                item.control(SessionFormControl.courtName).value as String? ??
                '',
          ),
      ],
      allLevelsSelected:
          sessionValue<bool>(SessionFormControl.allLevels) ?? true,
      requiredLevels:
          sessionValue<List<int>>(SessionFormControl.requiredLevels) ??
          const [],
      feeEnabled: sessionValue<bool>(SessionFormControl.feeEnabled) ?? false,
      feeType:
          sessionValue<FeeType>(SessionFormControl.feeType) ?? FeeType.fixed,
      maleFee: sessionValue<int>(SessionFormControl.maleFee),
      femaleFee: sessionValue<int>(SessionFormControl.femaleFee),
      feeNotes: sessionValue<String>(SessionFormControl.feeNotes) ?? '',
      bulkEnabled: sessionValue<bool>(SessionFormControl.bulkEnabled) ?? false,
      bulkMode:
          sessionValue<BulkCreationMode>(SessionFormControl.bulkMode) ??
          BulkCreationMode.specificDates,
      bulkDates:
          sessionValue<List<DateTime>>(SessionFormControl.bulkDates) ??
          const [],
      bulkWeekdays:
          sessionValue<List<int>>(SessionFormControl.bulkWeekdays) ?? const [],
      bulkNumberOfWeeks: sessionValue<int>(SessionFormControl.bulkWeeks) ?? 4,
      images:
          sessionValue<List<SessionImageDraft>>(SessionFormControl.images) ??
          const [],
      bannerPublicId: sessionValue<String>(SessionFormControl.bannerPublicId),
      courtColor:
          sessionValue<String>(SessionFormControl.courtColor) ?? '#179a3b',
      defaultMatchType:
          sessionValue<MatchType>(SessionFormControl.matchType) ??
          MatchType.doubles,
      shuttlecock: sessionValue<String>(SessionFormControl.shuttlecock) ?? '',
      maxPlayersPerCourt: sessionValue<int>(SessionFormControl.maxPlayers) ?? 8,
      referenceVideoUrl:
          sessionValue<String>(SessionFormControl.referenceVideo) ?? '',
      clubId: sessionValue<String>(SessionFormControl.clubId) ?? '',
      clubLabel: sessionValue<String>(SessionFormControl.clubLabel) ?? '',
    );
  }
}
