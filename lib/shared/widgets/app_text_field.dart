import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    decoration: decoration,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    enabled: enabled,
    obscureText: obscureText,
    maxLines: maxLines,
  );
}
