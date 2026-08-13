import 'package:flutter/material.dart';

/// An input label that visibly and semantically identifies a required field.
///
/// Use as [InputDecoration.label] rather than appending `*` to a localised
/// string. This keeps the marker's colour and accessibility label consistent.
class AppRequiredLabel extends StatelessWidget {
  const AppRequiredLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$text, required',
    child: ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    ),
  );
}

/// An input label that identifies an optional field.
///
/// Use when optional fields are the minority in a form, so the form avoids a
/// visually noisy required marker on nearly every label.
class AppOptionalLabel extends StatelessWidget {
  const AppOptionalLabel(this.text, {required this.optionalText, super.key});

  final String text;
  final String optionalText;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$text, $optionalText',
    child: ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            TextSpan(
              text: ' ($optionalText)',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
