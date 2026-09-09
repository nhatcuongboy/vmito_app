import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

abstract final class PlayerPaymentControl {
  static const method = 'method';
  static const proofImageUrl = 'proofImageUrl';
  static const proofNotes = 'proofNotes';
}

FormGroup createPlayerPaymentForm() => FormGroup({
  PlayerPaymentControl.method: FormControl<PaymentMethod>(
    value: PaymentMethod.bankTransfer,
    validators: [Validators.required],
  ),
  PlayerPaymentControl.proofImageUrl: FormControl<String>(),
  PlayerPaymentControl.proofNotes: FormControl<String>(
    validators: [Validators.maxLength(500)],
  ),
});

abstract final class FastTransferControl {
  static const amount = 'amount';
  static const message = 'message';
  static const bankCode = 'bankCode';
}

FormGroup createFastTransferForm({
  required int amount,
  required String message,
  String bankCode = 'TPB',
}) => FormGroup({
  FastTransferControl.amount: FormControl<int>(
    value: amount,
    validators: [Validators.required, Validators.min(1)],
  ),
  FastTransferControl.message: FormControl<String>(
    value: message,
    validators: [Validators.maxLength(70)],
  ),
  FastTransferControl.bankCode: FormControl<String>(
    value: bankCode,
    validators: [Validators.required],
  ),
});

String normalizeTransferMessage(String value) {
  const accented =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨ'
      'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const ascii =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
      'ooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIII'
      'OOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  var normalized = value;
  for (var index = 0; index < accented.length; index++) {
    normalized = normalized.replaceAll(accented[index], ascii[index]);
  }
  normalized = normalized
      .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized.length <= 70 ? normalized : normalized.substring(0, 70);
}
