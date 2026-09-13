import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/form/club_form.dart';

ClubVenueGroupDraft _group({
  String id = 'g1',
  String venueId = 'v1',
  List<ClubScheduleDraft> schedules = const [],
}) => ClubVenueGroupDraft(id: id, venueId: venueId, schedules: schedules);

ClubScheduleDraft _schedule({
  String id = 's1',
  int day = 1,
  String start = '19:00',
  String end = '21:00',
}) => ClubScheduleDraft(
  id: id,
  dayOfWeek: day,
  startTime: start,
  endTime: end,
);

void main() {
  group('club venue schedule validation', () {
    test('requires a venue when a venue group exists', () {
      final result = validateClubVenueSchedule([_group(venueId: '')]);

      expect(result.isValid, isFalse);
      expect(result.venueErrors['g1'], ClubVenueErrorKey.venueRequired);
    });

    test('rejects duplicate venues', () {
      final result = validateClubVenueSchedule([
        _group(),
        _group(id: 'g2'),
      ]);

      expect(result.isValid, isFalse);
      expect(
        result.venueErrors.values,
        everyElement(ClubVenueErrorKey.duplicateVenue),
      );
    });

    test('rejects invalid and backwards times', () {
      final result = validateClubVenueSchedule([
        _group(
          schedules: [
            _schedule(id: 'invalid', start: 'bad'),
            _schedule(id: 'backwards', start: '21:00', end: '19:00'),
          ],
        ),
      ]);

      expect(
        result.scheduleErrors['invalid'],
        ClubScheduleErrorKey.invalidTime,
      );
      expect(
        result.scheduleErrors['backwards'],
        ClubScheduleErrorKey.endBeforeStart,
      );
    });

    test('rejects overlapping schedules at the same venue and day', () {
      final result = validateClubVenueSchedule([
        _group(
          schedules: [
            _schedule(id: 'first', end: '20:30'),
            _schedule(id: 'second', start: '20:00'),
          ],
        ),
      ]);

      expect(result.scheduleErrors['first'], ClubScheduleErrorKey.overlap);
      expect(result.scheduleErrors['second'], ClubScheduleErrorKey.overlap);
    });

    test('allows separate venues and non-overlapping schedules', () {
      final result = validateClubVenueSchedule([
        _group(
          schedules: [_schedule(id: 'a')],
        ),
        _group(
          id: 'g2',
          venueId: 'v2',
          schedules: [_schedule(id: 'b', start: '20:00', end: '22:00')],
        ),
      ]);

      expect(result.isValid, isTrue);
    });
  });

  group('club form and payload', () {
    test('marks all levels as an empty required-level list', () {
      final form = createClubForm(hostName: 'Host');
      addTearDown(form.dispose);

      expect(form.control(ClubFormControl.requiredLevels).value, isEmpty);
      form.control(ClubFormControl.requiredLevels).value = [1, 2, 3];
      expect(form.control(ClubFormControl.requiredLevels).value, [1, 2, 3]);
      form.control(ClubFormControl.requiredLevels).value = <int>[];
      expect(form.control(ClubFormControl.requiredLevels).value, isEmpty);
    });

    test('serializes media, schedules, links and host fields', () {
      const draft = ClubDraft(
        name: '  Vmito  ',
        hostName: 'Host',
        hostUserId: 'u1',
        joinPolicy: 'OPEN',
        isPublic: true,
        images: ['cover.jpg'],
        imagePublicIds: ['cover-id'],
        image: 'cover.jpg',
        imagePublicId: 'cover-id',
        defaultVenueId: 'venue-1',
        logo: 'logo.jpg',
        logoPublicId: 'logo-id',
        requiredLevels: [1, 2],
        schedules: [
          {
            'dayOfWeek': 1,
            'startTime': '19:00',
            'endTime': '21:00',
            'isActive': true,
          },
        ],
        socialLinks: {'facebook': 'https://facebook.com/vmito'},
      );

      expect(draft.toJson(), {
        'name': 'Vmito',
        'hostName': 'Host',
        'hostUserId': 'u1',
        'joinPolicy': 'OPEN',
        'isPublic': true,
        'maxMembers': null,
        'defaultVenueId': 'venue-1',
        'image': 'cover.jpg',
        'imagePublicId': 'cover-id',
        'images': ['cover.jpg'],
        'imagePublicIds': ['cover-id'],
        'logo': 'logo.jpg',
        'logoPublicId': 'logo-id',
        'requiredLevels': [1, 2],
        'schedules': [
          {
            'dayOfWeek': 1,
            'startTime': '19:00',
            'endTime': '21:00',
            'isActive': true,
          },
        ],
        'socialLinks': {'facebook': 'https://facebook.com/vmito'},
      });
    });
  });
}
