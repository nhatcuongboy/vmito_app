import 'package:reactive_forms/reactive_forms.dart';

abstract final class HomeSearchControl {
  static const query = 'query';
}

FormGroup createHomeSearchForm({String initialQuery = ''}) => FormGroup({
  HomeSearchControl.query: FormControl<String>(
    value: initialQuery,
    validators: [Validators.required],
  ),
});
