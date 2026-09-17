import 'package:reactive_forms/reactive_forms.dart';

abstract final class ChatConsentFormControl {
  static const accepted = 'accepted';
}

FormGroup createChatConsentForm() => FormGroup({
  ChatConsentFormControl.accepted: FormControl<bool>(
    value: false,
    validators: [Validators.requiredTrue],
  ),
});
