import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/form/club_fee_form.dart';

void main() {
  test('club fee form starts from config and maps typed values', () {
    final form = createClubFeeForm(
      const ClubFeeConfig(
        maleFeeMonthly: 500000,
        femaleFeePerSession: 70000,
      ),
    );
    addTearDown(form.dispose);

    expect(form.clubFeeValue(ClubFeeControl.maleMonthly), 500000);
    expect(form.clubFeeValue(ClubFeeControl.femalePerSession), 70000);
    expect(form.valid, isTrue);
  });

  test('club fee form requires a per-session fee and rejects negatives', () {
    final form = createClubFeeForm();
    addTearDown(form.dispose);

    expect(form.invalid, isTrue);
    expect(form.hasError('perSessionRequired'), isTrue);
    form.control(ClubFeeControl.femalePerSession).value = 70000;
    expect(form.valid, isTrue);
    form.control(ClubFeeControl.malePerSession).value = -1;
    expect(form.invalid, isTrue);
  });
}
