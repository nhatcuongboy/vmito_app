import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/domain/form/player_payment_form.dart';

void main() {
  test('normalizes Vietnamese transfer content and limits it to 70 chars', () {
    final result = normalizeTransferMessage(
      'Vmito – Kèo cầu lông Đặng Văn Ngữ ${List.filled(80, 'x').join()}',
    );

    expect(result, startsWith('Vmito Keo cau long Dang Van Ngu'));
    expect(result.length, lessThanOrEqualTo(70));
    expect(result, isNot(contains('–')));
  });

  test('payment notes reject more than 500 characters after validation', () {
    final form = createPlayerPaymentForm();
    addTearDown(form.dispose);

    form.control(PlayerPaymentControl.proofNotes).value = List.filled(
      501,
      'x',
    ).join();

    expect(form.invalid, isTrue);
  });
}
