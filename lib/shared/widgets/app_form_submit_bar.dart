import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Primary submit button for a scrolling form.
///
/// Place inside the form's `body` (e.g. via `Stack` + `Align(bottomCenter)`
/// over the scrolling content), never in `Scaffold.bottomNavigationBar` —
/// `bottomNavigationBar` is not resized above the software keyboard, so a
/// button placed there gets covered by it. A button inside `body` stays
/// visible because `body` itself shrinks for the keyboard when
/// `resizeToAvoidBottomInset` is true (the Scaffold default).
class AppFormSubmitBar extends StatelessWidget {
  const AppFormSubmitBar({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onSubmit,
    this.inline = false,
    this.buttonKey,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onSubmit;

  /// True when rendered inline at the end of scrolling content (wide
  /// layouts) rather than pinned to the bottom of the screen.
  final bool inline;

  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Material(
    elevation: inline ? 0 : 8,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(inline ? 0 : AppSpacing.md),
        child: FilledButton.icon(
          key: buttonKey,
          onPressed: busy ? null : onSubmit,
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
        ),
      ),
    ),
  );
}
