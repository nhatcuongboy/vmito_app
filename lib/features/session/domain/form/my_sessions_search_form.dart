import 'package:reactive_forms/reactive_forms.dart';

abstract final class MySessionsSearchControl {
  static const query = 'query';
}

FormGroup createMySessionsSearchForm({String initialQuery = ''}) => FormGroup({
  MySessionsSearchControl.query: FormControl<String>(
    value: initialQuery,
    validators: [Validators.required],
  ),
});

String normalizeMySessionsSearchQuery(String query) =>
    query.trim().replaceAll(RegExp(r'\s+'), ' ');
