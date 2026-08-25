import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  group('host player form', () {
    test('requires name, level, and club when club fee is enabled', () {
      final form = hostPlayerRowForm();

      expect(form.invalid, isTrue);

      form
        ..patchValue({
          HostPlayerFormControl.name: 'Linh',
          HostPlayerFormControl.level: 4,
          HostPlayerFormControl.clubFeeEnabled: true,
        })
        ..updateValueAndValidity();

      expect(form.hasError('clubRequired'), isTrue);

      form
        ..control(HostPlayerFormControl.clubId).value = 'club-1'
        ..updateValueAndValidity();
      expect(form.valid, isTrue);

      form.dispose();
    });

    test('serializes trimmed bulk payload without display-only fields', () {
      const draft = HostPlayerDraft(
        userId: ' user-1 ',
        name: ' Linh ',
        phone: ' 0909 ',
        gender: Gender.female,
        level: 5,
        levelDescription: '  khá  ',
        clubFeeEnabled: true,
        clubId: ' club-1 ',
      );

      expect(draft.toJson(), {
        'name': 'Linh',
        'gender': 'FEMALE',
        'level': 5,
        'phone': '0909',
        'levelDescription': 'khá',
        'userId': 'user-1',
        'isClubMember': true,
        'clubId': 'club-1',
      });
      expect(draft.toJson(), isNot(contains('playerNumber')));
    });

    test('omits empty optional and disabled club fields', () {
      const draft = HostPlayerDraft(
        name: 'Nam',
        phone: ' ',
        gender: Gender.male,
        level: 1,
        levelDescription: '',
        clubFeeEnabled: false,
        clubId: 'club-ignored',
      );

      expect(draft.toJson(), {
        'name': 'Nam',
        'gender': 'MALE',
        'level': 1,
      });
    });

    test('edit payload explicitly clears optional and club fields', () {
      const draft = HostPlayerEditDraft(
        name: ' Nam ',
        phone: ' ',
        gender: Gender.male,
        level: 3,
        levelDescription: ' ',
        clubFeeEnabled: false,
        clubId: 'club-1',
      );

      expect(draft.toJson(), {
        'name': 'Nam',
        'gender': 'MALE',
        'level': 3,
        'phone': null,
        'levelDescription': null,
        'isClubMember': false,
        'clubId': null,
      });
    });
  });

  test('club fee falls back to the configured gender fee', () {
    const maleOnly = ClubFeeConfig(maleFeePerSession: 80000);
    const gendered = ClubFeeConfig(
      maleFeePerSession: 90000,
      femaleFeePerSession: 70000,
    );

    expect(maleOnly.feeForGender('FEMALE'), 80000);
    expect(gendered.feeForGender('FEMALE'), 70000);
    expect(gendered.feeForGender('MALE'), 90000);
  });
}
