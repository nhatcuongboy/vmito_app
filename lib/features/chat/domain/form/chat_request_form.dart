import 'package:reactive_forms/reactive_forms.dart';

abstract final class ChatRequestFormControl {
  static const message = 'message';
}

const chatMessageMaxLength = 2000;

Map<String, dynamic>? _requiredTrimmed(AbstractControl<dynamic> control) {
  final value = control.value;
  if (value == null || (value is String && value.trim().isEmpty)) {
    return {ValidationMessage.required: true};
  }
  return null;
}

/// The single-field form for a request's initial message, shared by the
/// contacts screen and the public-profile "Nhắn tin" CTA.
FormGroup createChatRequestForm() => FormGroup({
  ChatRequestFormControl.message: FormControl<String>(
    validators: [
      Validators.delegate(_requiredTrimmed),
      Validators.maxLength(chatMessageMaxLength),
    ],
  ),
});
