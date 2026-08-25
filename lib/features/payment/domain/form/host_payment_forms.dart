import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

abstract final class PaymentSettingsControl {
  static const bankName = 'bankName';
  static const accountNumber = 'accountNumber';
  static const accountHolder = 'accountHolder';
  static const qrCodeUrl = 'qrCodeUrl';
}

abstract final class SessionFeeControl {
  static const enabled = 'enabled';
  static const feeType = 'feeType';
  static const maleFee = 'maleFee';
  static const femaleFee = 'femaleFee';
  static const notes = 'notes';
}

abstract final class SplitAmountControl {
  static const total = 'total';
}

abstract final class ExpenseControl {
  static const name = 'name';
  static const amount = 'amount';
}

FormGroup createPaymentSettingsForm(HostPaymentSettings? settings) => FormGroup(
  {
    PaymentSettingsControl.bankName: FormControl<String>(
      value: settings?.bankName ?? '',
    ),
    PaymentSettingsControl.accountNumber: FormControl<String>(
      value: settings?.bankAccountNumber ?? '',
    ),
    PaymentSettingsControl.accountHolder: FormControl<String>(
      value: settings?.accountHolderName ?? '',
    ),
    PaymentSettingsControl.qrCodeUrl: FormControl<String>(
      value: settings?.qrCodeUrl,
    ),
  },
  validators: [Validators.delegate(validatePaymentSettings)],
);

Map<String, dynamic>? validatePaymentSettings(
  AbstractControl<dynamic> control,
) {
  final form = control as FormGroup;
  final hasBank = _hasText(
    form.control(PaymentSettingsControl.bankName).value,
  );
  final hasAccount = _hasText(
    form.control(PaymentSettingsControl.accountNumber).value,
  );
  final hasQr = _hasText(
    form.control(PaymentSettingsControl.qrCodeUrl).value,
  );
  return hasBank || hasAccount || hasQr
      ? null
      : {'paymentMethodRequired': true};
}

FormGroup createSessionFeeForm(SessionFeeConfig? config) => FormGroup({
  SessionFeeControl.enabled: FormControl<bool>(value: config != null),
  SessionFeeControl.feeType: FormControl<FeeType>(
    value: config?.feeType ?? FeeType.fixed,
    validators: [Validators.required],
  ),
  SessionFeeControl.maleFee: FormControl<int>(
    value: config?.maleFee,
    validators: [Validators.min(0)],
  ),
  SessionFeeControl.femaleFee: FormControl<int>(
    value: config?.femaleFee,
    validators: [Validators.min(0)],
  ),
  SessionFeeControl.notes: FormControl<String>(value: config?.notes ?? ''),
});

FormGroup createSplitAmountForm() => FormGroup({
  SplitAmountControl.total: FormControl<int>(
    validators: [Validators.required, Validators.min(1)],
  ),
});

FormGroup createExpenseForm([SessionExpense? expense]) => FormGroup({
  ExpenseControl.name: FormControl<String>(
    value: expense?.name ?? '',
    validators: [Validators.required],
  ),
  ExpenseControl.amount: FormControl<int>(
    value: expense?.amount,
    validators: [Validators.required, Validators.min(0)],
  ),
});

bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;
