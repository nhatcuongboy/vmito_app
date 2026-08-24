import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

abstract final class FeedbackFormControl {
  static const title = 'title';
  static const description = 'description';
}

Map<String, dynamic>? validateFeedbackNonBlank(
  AbstractControl<dynamic> control,
) {
  final value = control.value as String?;
  return value == null || value.trim().isEmpty
      ? <String, dynamic>{ValidationMessage.required: true}
      : null;
}

FormGroup createFeedbackForm() => FormGroup({
  FeedbackFormControl.title: FormControl<String>(
    validators: [
      Validators.delegate(validateFeedbackNonBlank),
      Validators.maxLength(200),
    ],
  ),
  FeedbackFormControl.description: FormControl<String>(
    validators: [
      Validators.delegate(validateFeedbackNonBlank),
      Validators.maxLength(5000),
    ],
  ),
});

FeedbackDraft feedbackDraftFromForm(FormGroup form, FeedbackType type) =>
    FeedbackDraft(
      type: type,
      title: (form.control(FeedbackFormControl.title).value as String? ?? '')
          .trim(),
      description:
          (form.control(FeedbackFormControl.description).value as String? ?? '')
              .trim(),
    );
