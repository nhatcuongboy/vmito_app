import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/domain/form/host_payment_forms.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

void main() {
  test('payment settings require bank details or a QR code', () {
    final form = createPaymentSettingsForm(null);
    addTearDown(form.dispose);

    expect(form.hasError('paymentMethodRequired'), isTrue);

    form.control(PaymentSettingsControl.bankName).value = 'VCB';
    expect(form.valid, isTrue);

    form.control(PaymentSettingsControl.bankName).value = '';
    form.control(PaymentSettingsControl.qrCodeUrl).value = 'https://qr.test';
    expect(form.valid, isTrue);
  });

  test('split amount must be a positive integer', () {
    final form = createSplitAmountForm();
    addTearDown(form.dispose);
    void setTotal(int value) {
      form.control(SplitAmountControl.total).value = value;
    }

    setTotal(0);
    expect(form.invalid, isTrue);
    setTotal(500000);
    expect(form.valid, isTrue);
  });

  test('expense requires a name and a non-negative amount', () {
    final form = createExpenseForm();
    addTearDown(form.dispose);

    form.patchValue({ExpenseControl.name: '', ExpenseControl.amount: -1});
    expect(form.invalid, isTrue);
    form.patchValue({
      ExpenseControl.name: 'Thuê sân',
      ExpenseControl.amount: 0,
    });
    expect(form.valid, isTrue);
  });

  test('fee form preserves fixed and split fee types', () {
    final form = createSessionFeeForm(
      const SessionFeeConfig(feeType: FeeType.splitEvenly, notes: 'Ghi chú'),
    );
    addTearDown(form.dispose);

    expect(form.control(SessionFeeControl.enabled).value, isTrue);
    expect(
      form.control(SessionFeeControl.feeType).value,
      FeeType.splitEvenly,
    );
  });
}
