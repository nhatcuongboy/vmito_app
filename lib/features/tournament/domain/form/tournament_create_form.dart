import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';

abstract final class TournamentCreateControl {
  static const name = 'name';
  static const sportType = 'sportType';
  static const startDate = 'startDate';
  static const endDate = 'endDate';
  static const locationQuery = 'locationQuery';
  static const locationName = 'locationName';
  static const locationAddress = 'locationAddress';
  static const locationPlaceId = 'locationPlaceId';
  static const locationLatitude = 'locationLatitude';
  static const locationLongitude = 'locationLongitude';
  static const locationDistrict = 'locationDistrict';
  static const locationCity = 'locationCity';
}

abstract final class TournamentCreateValidation {
  static const startDatePast = 'startDatePast';
  static const endBeforeStart = 'endBeforeStart';
}

enum TournamentCreateField { startDate, endDate }

enum TournamentCreateError { startDatePast, endBeforeStart }

Map<TournamentCreateField, TournamentCreateError> validateTournamentDates({
  required DateTime? startDate,
  required DateTime? endDate,
  required DateTime today,
}) {
  final errors = <TournamentCreateField, TournamentCreateError>{};
  final localToday = DateTime(today.year, today.month, today.day);
  if (startDate != null && startDate.isBefore(localToday)) {
    errors[TournamentCreateField.startDate] =
        TournamentCreateError.startDatePast;
  }
  if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
    errors[TournamentCreateField.endDate] =
        TournamentCreateError.endBeforeStart;
  }
  return errors;
}

FormGroup createTournamentReactiveForm() => FormGroup({
  TournamentCreateControl.name: FormControl<String>(
    validators: [Validators.required],
  ),
  TournamentCreateControl.sportType: FormControl<TournamentSportType>(
    value: TournamentSportType.badminton,
    validators: [Validators.required],
  ),
  TournamentCreateControl.startDate: FormControl<DateTime>(
    validators: [Validators.required],
  ),
  TournamentCreateControl.endDate: FormControl<DateTime>(
    validators: [Validators.required],
  ),
  TournamentCreateControl.locationQuery: FormControl<String>(),
  TournamentCreateControl.locationName: FormControl<String>(),
  TournamentCreateControl.locationAddress: FormControl<String>(),
  TournamentCreateControl.locationPlaceId: FormControl<String>(),
  TournamentCreateControl.locationLatitude: FormControl<double>(),
  TournamentCreateControl.locationLongitude: FormControl<double>(),
  TournamentCreateControl.locationDistrict: FormControl<String>(),
  TournamentCreateControl.locationCity: FormControl<String>(),
});

extension TournamentCreateFormValue on FormGroup {
  T? tournamentValue<T>(String name) => control(name).value as T?;

  TournamentCreateRequest toTournamentCreateRequest() {
    final query = tournamentValue<String>(
      TournamentCreateControl.locationQuery,
    )?.trim();
    final selectedName = tournamentValue<String>(
      TournamentCreateControl.locationName,
    )?.trim();
    final locationName = selectedName?.isNotEmpty == true
        ? selectedName!
        : query;
    return TournamentCreateRequest(
      name: tournamentValue<String>(TournamentCreateControl.name) ?? '',
      sportType:
          tournamentValue<TournamentSportType>(
            TournamentCreateControl.sportType,
          ) ??
          TournamentSportType.badminton,
      startDate: tournamentValue<DateTime>(
        TournamentCreateControl.startDate,
      )!,
      endDate: tournamentValue<DateTime>(TournamentCreateControl.endDate)!,
      location: locationName?.isNotEmpty == true
          ? TournamentLocationDraft(
              name: locationName!,
              placeId: tournamentValue<String>(
                TournamentCreateControl.locationPlaceId,
              ),
              address:
                  tournamentValue<String>(
                    TournamentCreateControl.locationAddress,
                  ) ??
                  query,
              latitude: tournamentValue<double>(
                TournamentCreateControl.locationLatitude,
              ),
              longitude: tournamentValue<double>(
                TournamentCreateControl.locationLongitude,
              ),
              district: tournamentValue<String>(
                TournamentCreateControl.locationDistrict,
              ),
              city: tournamentValue<String>(
                TournamentCreateControl.locationCity,
              ),
            )
          : null,
    );
  }
}
