import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_create_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';

void main() {
  group('validateTournamentDates', () {
    final today = DateTime(2026, 8, 25);

    test('rejects a start date in the past', () {
      final errors = validateTournamentDates(
        startDate: DateTime(2026, 8, 24),
        endDate: DateTime(2026, 8, 25),
        today: today,
      );

      expect(
        errors[TournamentCreateField.startDate],
        TournamentCreateError.startDatePast,
      );
    });

    test('rejects an end date before the start date', () {
      final errors = validateTournamentDates(
        startDate: DateTime(2026, 8, 26),
        endDate: DateTime(2026, 8, 25),
        today: today,
      );

      expect(
        errors[TournamentCreateField.endDate],
        TournamentCreateError.endBeforeStart,
      );
    });

    test('accepts a same-day tournament', () {
      final errors = validateTournamentDates(
        startDate: today,
        endDate: today,
        today: today,
      );

      expect(errors, isEmpty);
    });
  });

  group('TournamentCreateRequest', () {
    test('serializes selected Places data and UTC calendar dates', () {
      final request = TournamentCreateRequest(
        name: '  Vmito Open  ',
        sportType: TournamentSportType.pickleball,
        startDate: DateTime(2026, 9, 2, 18),
        endDate: DateTime(2026, 9, 3, 22),
        location: const TournamentLocationDraft(
          name: 'Vmito Arena',
          placeId: 'place-1',
          address: '123 Nguyễn Huệ',
          latitude: 10.77,
          longitude: 106.7,
          district: 'Quận 1',
          city: 'Hồ Chí Minh',
        ),
      );

      expect(request.toJson(), {
        'name': 'Vmito Open',
        'sportType': 'PICKLEBALL',
        'startDate': '2026-09-02T00:00:00.000Z',
        'endDate': '2026-09-03T00:00:00.000Z',
        'location': {
          'name': 'Vmito Arena',
          'placeId': 'place-1',
          'address': '123 Nguyễn Huệ',
          'lat': 10.77,
          'lng': 106.7,
          'district': 'Quận 1',
          'city': 'Hồ Chí Minh',
        },
      });
    });

    test('maps a manually entered location from the reactive form', () {
      final form = createTournamentReactiveForm();
      addTearDown(form.dispose);
      form
        ..control(TournamentCreateControl.name).value = 'Giải cuối tuần'
        ..control(TournamentCreateControl.startDate).value = DateTime(
          2026,
          9,
          5,
        )
        ..control(TournamentCreateControl.endDate).value = DateTime(2026, 9, 5)
        ..control(TournamentCreateControl.locationQuery).value =
            'Nhà thi đấu Phú Thọ';

      final location = form.toTournamentCreateRequest().location;

      expect(location?.name, 'Nhà thi đấu Phú Thọ');
      expect(location?.address, 'Nhà thi đấu Phú Thọ');
      expect(location?.placeId, isNull);
    });
  });
}
