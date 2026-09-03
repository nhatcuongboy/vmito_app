import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

void main() {
  group('FormRewardEarlyPunishLateX & AppReactiveForm', () {
    testWidgets(
      'suppresses validation errors before submit (Punish Late), reveals on submit, and clears on valid input (Reward Early)',
      (tester) async {
        final form = FormGroup({
          'email': FormControl<String>(
            validators: [Validators.required, Validators.email],
          ),
          'name': FormControl<String>(
            validators: [Validators.required],
          ),
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppReactiveForm(
                formGroup: form,
                child: Column(
                  children: [
                    ReactiveTextField<String>(
                      key: const ValueKey('email-field'),
                      formControlName: 'email',
                      validationMessages: {
                        ValidationMessage.required: (_) => 'Email is required',
                        ValidationMessage.email: (_) => 'Invalid email format',
                      },
                    ),
                    ReactiveTextField<String>(
                      key: const ValueKey('name-field'),
                      formControlName: 'name',
                      validationMessages: {
                        ValidationMessage.required: (_) => 'Name is required',
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially no errors are displayed
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Invalid email format'), findsNothing);
        expect(find.text('Name is required'), findsNothing);

        // 2. Type an invalid email and then move focus to name-field (blur email)
        await tester.enterText(find.byKey(const ValueKey('email-field')), 'invalid-email');
        await tester.tap(find.byKey(const ValueKey('name-field')));
        await tester.pumpAndSettle();

        // Before submit: errors MUST NOT be displayed (Punish Late)
        expect(find.text('Invalid email format'), findsNothing);
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Name is required'), findsNothing);
        expect(form.isSubmitted, isFalse);

        // 3. User attempts to submit the form
        form.markAllAsTouched();
        await tester.pumpAndSettle();

        // Errors MUST now be displayed for both invalid fields
        expect(form.isSubmitted, isTrue);
        expect(find.text('Invalid email format'), findsOneWidget);
        expect(find.text('Name is required'), findsOneWidget);

        // 4. Reward Early: user corrects email in real time
        await tester.enterText(
          find.byKey(const ValueKey('email-field')),
          'user@example.com',
        );
        await tester.pump();

        // Email error must disappear immediately upon becoming valid!
        expect(find.text('Invalid email format'), findsNothing);
        expect(find.text('Email is required'), findsNothing);
        // Name is still empty so its error persists
        expect(find.text('Name is required'), findsOneWidget);

        // 5. User enters invalid text again: error displays immediately in real time
        await tester.enterText(
          find.byKey(const ValueKey('email-field')),
          'broken',
        );
        await tester.pump();
        expect(find.text('Invalid email format'), findsOneWidget);

        // 6. User enters valid values for both fields
        await tester.enterText(
          find.byKey(const ValueKey('email-field')),
          'valid@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('name-field')),
          'Valid Name',
        );
        await tester.pump();
        expect(find.text('Invalid email format'), findsNothing);
        expect(find.text('Name is required'), findsNothing);
        expect(form.valid, isTrue);

        // 7. Calling reset returns form to unsubmitted state
        form.reset();
        await tester.pumpAndSettle();
        expect(form.isSubmitted, isFalse);
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Name is required'), findsNothing);
      },
    );
  });
}
