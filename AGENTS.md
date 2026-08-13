# Project rules

## Forms

`reactive_forms` is the required form-management solution for this app. Read
[`docs/FORM_MANAGEMENT.md`](docs/FORM_MANAGEMENT.md) before creating or
changing a form.

- New user-editable forms must use `FormGroup`, `ReactiveForm`, and the
  matching `Reactive*` field widgets. Do not introduce `Form`,
  `GlobalKey<FormState>`, or `TextFormField` for a new screen.
- When changing a legacy native Flutter form's fields, validation, submit
  flow, or UI, migrate that form to `reactive_forms` in the same change.
  A presentation-only change that preserves its inputs and behaviour (for
  example applying `AppRequiredLabel`) is exempt. Do not make unrelated,
  bulk migrations.
- Put pure business and cross-field validation in the feature `domain/form/`
  layer. Keep local display-only validation and l10n error-message mapping in
  the presentation layer.
- A form's submit action must mark controls touched, stop when invalid,
  prevent duplicate submits while pending, and dispose its `FormGroup`.
- Choose the label convention per form, based on its fields: when required
  fields are the majority, use plain labels for them and `AppOptionalLabel`
  for optional fields; when optional fields are the majority, use
  `AppRequiredLabel` for required fields. Both labels preserve accessibility
  semantics.
- Form state stays local to the screen unless a multi-step flow needs to
  survive navigation. Riverpod owns API submission and server state, not
  individual keystrokes.
