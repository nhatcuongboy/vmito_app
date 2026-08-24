import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';
import 'package:vmito_app/features/feedback/domain/form/feedback_form.dart';

void main() {
  test('rejects blank values and values above backend limits', () {
    final form = createFeedbackForm();
    addTearDown(form.dispose);

    form.control(FeedbackFormControl.title).value = '   ';
    form.control(FeedbackFormControl.description).value = '\n  ';
    expect(form.invalid, isTrue);
    expect(
      form
          .control(FeedbackFormControl.title)
          .hasError(
            ValidationMessage.required,
          ),
      isTrue,
    );

    form.control(FeedbackFormControl.title).value = List.filled(
      201,
      'a',
    ).join();
    form.control(FeedbackFormControl.description).value = List.filled(
      5001,
      'b',
    ).join();
    expect(
      form
          .control(FeedbackFormControl.title)
          .hasError(
            ValidationMessage.maxLength,
          ),
      isTrue,
    );
    expect(
      form
          .control(FeedbackFormControl.description)
          .hasError(
            ValidationMessage.maxLength,
          ),
      isTrue,
    );
  });

  test('maps valid form values to a trimmed draft', () {
    final form = createFeedbackForm();
    addTearDown(form.dispose);
    form.control(FeedbackFormControl.title).value = '  Need help  ';
    form.control(FeedbackFormControl.description).value = '  Details here  ';

    final draft = feedbackDraftFromForm(form, FeedbackType.contact);

    expect(form.valid, isTrue);
    expect(draft.title, 'Need help');
    expect(draft.description, 'Details here');
    expect(draft.type, FeedbackType.contact);
  });
}
