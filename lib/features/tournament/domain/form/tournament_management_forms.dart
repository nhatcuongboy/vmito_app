import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';

abstract final class TournamentSettingsControl {
  static const name = 'name';
  static const description = 'description';
  static const startDate = 'startDate';
  static const endDate = 'endDate';
  static const visibility = 'visibility';
  static const coverPhoto = 'coverPhoto';
  static const coverPhotoPublicId = 'coverPhotoPublicId';
  static const videos = 'videos';
  static const contactName = 'contactName';
  static const contactEmail = 'contactEmail';
  static const contactPhone = 'contactPhone';
  static const confirmName = 'confirmName';
}

abstract final class TournamentDuplicateControl {
  static const name = 'name';
  static const startDate = 'startDate';
  static const endDate = 'endDate';
  static const venueId = 'venueId';
  static const venueQuery = 'venueQuery';
  static const copyFormat = 'copyFormat';
  static const copySchedule = 'copySchedule';
  static const copyTeams = 'copyTeams';
  static const copyResults = 'copyResults';
  static const copyVenues = 'copyVenues';
  static const copyHome = 'copyHome';
}

abstract final class TournamentManagementValidation {
  static const endBeforeStart = 'endBeforeStart';
  static const resultRequiresSchedule = 'resultRequiresSchedule';
  static const invalidYoutubeUrl = 'invalidYoutubeUrl';
  static const invalidHttpUrl = 'invalidHttpUrl';
  static const tournamentNameMismatch = 'tournamentNameMismatch';
  static const permissionsRequired = 'permissionsRequired';
}

abstract final class TournamentManagerControl {
  static const query = 'query';
  static const userId = 'userId';
  static String permission(TournamentPermission value) =>
      'permission_${value.wireValue}';
}

FormGroup tournamentManagerForm({
  String? userId,
  Set<TournamentPermission> permissions = const {},
}) => FormGroup(
  {
    TournamentManagerControl.query: FormControl<String>(),
    TournamentManagerControl.userId: FormControl<String>(
      value: userId,
      validators: [Validators.required],
    ),
    for (final permission in TournamentPermission.values)
      TournamentManagerControl.permission(permission): FormControl<bool>(
        value: permissions.contains(permission),
      ),
  },
  validators: [Validators.delegate(_validateManagerPermissions)],
);

Set<TournamentPermission> tournamentManagerPermissions(FormGroup form) => {
  for (final permission in TournamentPermission.values)
    if (_value<bool>(form, TournamentManagerControl.permission(permission)) ==
        true)
      permission,
};

FormGroup tournamentNameForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.name: FormControl<String>(
    value: tournament.name,
    validators: [Validators.required, Validators.maxLength(100)],
  ),
  TournamentSettingsControl.description: FormControl<String>(
    value: tournament.description ?? '',
    validators: [Validators.maxLength(2000)],
  ),
});

FormGroup tournamentDatesForm(TournamentDetail tournament) => FormGroup(
  {
    TournamentSettingsControl.startDate: FormControl<DateTime>(
      value: _day(tournament.startDate.toLocal()),
      validators: [Validators.required],
    ),
    TournamentSettingsControl.endDate: FormControl<DateTime>(
      value: _day(tournament.endDate.toLocal()),
      validators: [Validators.required],
    ),
  },
  validators: [Validators.delegate(_validateDateRange)],
);

FormGroup tournamentVisibilityForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.visibility: FormControl<bool>(
    value: tournament.isPublished,
  ),
});

FormGroup tournamentBannerForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.coverPhoto: FormControl<String>(
    value: tournament.coverPhoto ?? '',
    validators: [Validators.delegate(_httpUrlValidator)],
  ),
  TournamentSettingsControl.coverPhotoPublicId: FormControl<String>(
    value: tournament.coverPhotoPublicId ?? '',
  ),
});

FormGroup tournamentVideosForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.videos: FormArray<String>([
    for (final url in tournament.youtubeVideoUrls)
      FormControl<String>(
        value: url,
        validators: [Validators.delegate(_youtubeValidator)],
      ),
    if (tournament.youtubeVideoUrls.isEmpty)
      FormControl<String>(
        validators: [Validators.delegate(_youtubeValidator)],
      ),
  ]),
});

FormGroup tournamentContactForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.contactName: FormControl<String>(
    value: tournament.contactName ?? '',
    validators: [Validators.maxLength(100)],
  ),
  TournamentSettingsControl.contactEmail: FormControl<String>(
    value: tournament.contactEmail ?? '',
    validators: [Validators.email, Validators.maxLength(150)],
  ),
  TournamentSettingsControl.contactPhone: FormControl<String>(
    value: tournament.contactPhone ?? '',
    validators: [Validators.maxLength(30)],
  ),
});

FormGroup tournamentDeleteForm(TournamentDetail tournament) => FormGroup({
  TournamentSettingsControl.confirmName: FormControl<String>(
    validators: [
      Validators.required,
      Validators.delegate((control) {
        return control.value?.toString().trim() == tournament.name.trim()
            ? null
            : {TournamentManagementValidation.tournamentNameMismatch: true};
      }),
    ],
  ),
});

FormGroup tournamentDuplicateForm(TournamentDetail tournament) => FormGroup(
  {
    TournamentDuplicateControl.name: FormControl<String>(
      value: '${tournament.name} (Bản sao)',
      validators: [Validators.required, Validators.maxLength(100)],
    ),
    TournamentDuplicateControl.startDate: FormControl<DateTime>(
      value: _day(tournament.startDate.toLocal()),
      validators: [Validators.required],
    ),
    TournamentDuplicateControl.endDate: FormControl<DateTime>(
      value: _day(tournament.endDate.toLocal()),
      validators: [Validators.required],
    ),
    TournamentDuplicateControl.venueId: FormControl<String>(),
    TournamentDuplicateControl.venueQuery: FormControl<String>(),
    TournamentDuplicateControl.copyFormat: FormControl<bool>(
      value: true,
      disabled: true,
    ),
    TournamentDuplicateControl.copySchedule: FormControl<bool>(value: true),
    TournamentDuplicateControl.copyTeams: FormControl<bool>(value: true),
    TournamentDuplicateControl.copyResults: FormControl<bool>(value: true),
    TournamentDuplicateControl.copyVenues: FormControl<bool>(value: true),
    TournamentDuplicateControl.copyHome: FormControl<bool>(value: true),
  },
  validators: [
    Validators.delegate(_validateDateRange),
    Validators.delegate(_validateDuplicateOptions),
  ],
);

DuplicateTournamentDraft duplicateDraftFromForm(FormGroup form) =>
    DuplicateTournamentDraft(
      name: _value<String>(form, TournamentDuplicateControl.name) ?? '',
      startDate: _value<DateTime>(form, TournamentDuplicateControl.startDate)!,
      endDate: _value<DateTime>(form, TournamentDuplicateControl.endDate)!,
      venueId: _emptyToNull(
        _value<String>(form, TournamentDuplicateControl.venueId),
      ),
      copySchedule:
          _value<bool>(form, TournamentDuplicateControl.copySchedule) ?? false,
      copyTeams:
          _value<bool>(form, TournamentDuplicateControl.copyTeams) ?? false,
      copyMatchResults:
          _value<bool>(form, TournamentDuplicateControl.copyResults) ?? false,
      copyVenues:
          _value<bool>(form, TournamentDuplicateControl.copyVenues) ?? false,
      copyCustomHomePage:
          _value<bool>(form, TournamentDuplicateControl.copyHome) ?? false,
    );

Map<String, dynamic>? _validateDateRange(AbstractControl<dynamic> control) {
  if (control is! FormGroup) return null;
  final start =
      _value<DateTime>(control, TournamentSettingsControl.startDate) ??
      _value<DateTime>(control, TournamentDuplicateControl.startDate);
  final end =
      _value<DateTime>(control, TournamentSettingsControl.endDate) ??
      _value<DateTime>(control, TournamentDuplicateControl.endDate);
  if (start != null && end != null && end.isBefore(start)) {
    return {TournamentManagementValidation.endBeforeStart: true};
  }
  return null;
}

Map<String, dynamic>? _validateDuplicateOptions(
  AbstractControl<dynamic> control,
) {
  if (control is! FormGroup) return null;
  final results =
      _value<bool>(control, TournamentDuplicateControl.copyResults) ?? false;
  final schedule =
      _value<bool>(control, TournamentDuplicateControl.copySchedule) ?? false;
  return results && !schedule
      ? {TournamentManagementValidation.resultRequiresSchedule: true}
      : null;
}

Map<String, dynamic>? _youtubeValidator(AbstractControl<dynamic> control) {
  final value = control.value?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase() ?? '';
  final valid =
      (uri?.scheme == 'http' || uri?.scheme == 'https') &&
      (host == 'youtu.be' ||
          host == 'youtube.com' ||
          host.endsWith('.youtube.com'));
  return valid
      ? null
      : {TournamentManagementValidation.invalidYoutubeUrl: true};
}

Map<String, dynamic>? _httpUrlValidator(AbstractControl<dynamic> control) {
  final value = control.value?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return (uri?.scheme == 'http' || uri?.scheme == 'https') &&
          (uri?.host.isNotEmpty ?? false)
      ? null
      : {TournamentManagementValidation.invalidHttpUrl: true};
}

Map<String, dynamic>? _validateManagerPermissions(
  AbstractControl<dynamic> control,
) {
  if (control is! FormGroup) return null;
  return tournamentManagerPermissions(control).isEmpty
      ? {TournamentManagementValidation.permissionsRequired: true}
      : null;
}

T? _value<T>(FormGroup form, String name) => form.control(name).value as T?;
String? _emptyToNull(String? value) =>
    value?.trim().isEmpty ?? true ? null : value!.trim();
DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
