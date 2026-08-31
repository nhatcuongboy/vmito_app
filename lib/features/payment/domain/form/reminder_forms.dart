import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

abstract final class CreateCustomReminderControl {
  static const recipientUserId = 'recipientUserId';
  static const recipientName = 'recipientName';
  static const amount = 'amount';
  static const note = 'note';
}

abstract final class MarkPaidControl {
  static const paymentMethod = 'paymentMethod';
  static const proofImageUrl = 'proofImageUrl';
  static const proofImagePublicId = 'proofImagePublicId';
  static const proofNotes = 'proofNotes';
}

abstract final class RejectReminderControl {
  static const hostNotes = 'hostNotes';
}

FormGroup createCustomReminderForm() => FormGroup({
  CreateCustomReminderControl.recipientUserId: FormControl<String>(
    validators: [Validators.required],
  ),
  CreateCustomReminderControl.recipientName: FormControl<String>(),
  CreateCustomReminderControl.amount: FormControl<int>(
    validators: [Validators.required, Validators.min(1)],
  ),
  CreateCustomReminderControl.note: FormControl<String>(
    validators: [Validators.required, Validators.maxLength(500)],
  ),
});

FormGroup createMarkPaidForm() => FormGroup({
  MarkPaidControl.paymentMethod: FormControl<PaymentMethod>(
    value: PaymentMethod.bankTransfer,
    validators: [Validators.required],
  ),
  MarkPaidControl.proofImageUrl: FormControl<String>(),
  MarkPaidControl.proofImagePublicId: FormControl<String>(),
  MarkPaidControl.proofNotes: FormControl<String>(
    validators: [Validators.maxLength(500)],
  ),
});

FormGroup createRejectReminderForm() => FormGroup({
  RejectReminderControl.hostNotes: FormControl<String>(
    validators: [Validators.maxLength(500)],
  ),
});
