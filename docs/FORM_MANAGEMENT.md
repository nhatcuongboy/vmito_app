# Form management

## Standard

Use [`reactive_forms`](https://pub.dev/packages/reactive_forms) for every
user-editable form. It is model-driven, supports typed controls, group and
array validation, and separates form state from widget lifecycle.

The standard replaces the former `Form` + `GlobalKey<FormState>` +
`TextFormField` pattern. Do not add a second form library.

Choose the label convention per form, rather than marking every required field:

- When required fields are the majority, use plain labels for required fields
  and `AppOptionalLabel` for optional fields. Add a short, localised note when
  it helps clarify that unmarked fields are required.
- When optional fields are the majority, use `AppRequiredLabel` for required
  fields. It adds the red `*` marker and announces the field as required to
  assistive technology.

Never append `*` or `(Optional)` manually to a localised label string.

## Ownership

| Concern | Owner |
|---|---|
| Field values, dirty/touched state, synchronous validation | Local `FormGroup` |
| Cross-field and business rules | `features/<feature>/domain/form/` |
| Localized error text and field presentation | Presentation widget |
| Submit request, loading and server error state | Riverpod controller |

Do not mirror every keystroke into Riverpod. Keep form state local unless a
multi-step flow must persist while its screen is not mounted.

## Required shape

Create the `FormGroup` in the owning `StatefulWidget`, dispose it in
`dispose`, and render it with `ReactiveForm`. Use typed controls and stable
control-name constants rather than string literals scattered through widgets.

```dart
abstract final class ClubFormControl {
  static const name = 'name';
}

final _form = FormGroup({
  ClubFormControl.name: FormControl<String>(
    validators: [Validators.required, Validators.maxLength(50)],
  ),
});

@override
Widget build(BuildContext context) => ReactiveForm(
  formGroup: _form,
  child: ReactiveTextField<String>(
    formControlName: ClubFormControl.name,
    validationMessages: {
      ValidationMessage.required: (_) => l10n.clubNameRequired,
    },
  ),
);

@override
void dispose() {
  _form.dispose();
  super.dispose();
}
```

On submit, call `markAllAsTouched()`. If `form.invalid` or `form.pending`,
return before mapping control values to a draft and calling the Riverpod
controller. Disable the submit button while the controller is loading.

## Validation rules

- Use package validators for single-field syntactic rules such as required,
  length, number range and email.
- Keep business rules and cross-field rules pure and testable in
  `domain/form/`; do not make network calls from widget validators.
- Use an async validator only for a genuine pre-submit server constraint and
  debounce it. The server remains the final authority.
- Map server failures to a form-level error or the affected control; never
  expose raw API error text directly as a field validator.
- Error messages must come from ARB localization, not hard-coded strings.

## Migration rule

New forms must follow this standard immediately. Legacy forms are migrated
when a change touches their fields, validation, submit flow, or UI. This keeps
feature work safe while ensuring the native Flutter form pattern steadily
disappears. A presentation-only change that preserves inputs and behaviour,
such as applying `AppRequiredLabel`, does not require a migration.

For each migration, preserve existing widget keys and validation behaviour,
add or update widget tests for invalid and successful submission, and avoid
mixing it with unrelated visual refactors.
