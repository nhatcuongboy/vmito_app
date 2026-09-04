import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: title,
    content: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 320),
      child: content,
    ),
    actions: actions,
  );
}

/// Distinguishes between safe confirmations and irreversible/dangerous ones.
///
/// - [submit]: the primary action is constructive (save, start, send).
///   The confirm button uses the default primary (blue) colour.
/// - [destructive]: the primary action removes or terminates something.
///   The confirm button uses the error (red) colour to signal danger.
enum AppConfirmDialogType { submit, destructive }

/// A standardised two-button confirm dialog.
///
/// Use [showAppConfirmDialog] to display it and get the boolean result.
///
/// ```dart
/// final ok = await showAppConfirmDialog(
///   context,
///   type: AppConfirmDialogType.destructive,
///   title: 'Delete post',
///   content: 'This cannot be undone.',
///   confirmLabel: 'Delete',
/// );
/// if (ok == true) { /* proceed */ }
/// ```
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.type = AppConfirmDialogType.submit,
    this.cancelLabel,
    this.icon,
    this.confirmKey,
    super.key,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final AppConfirmDialogType type;

  /// Defaults to [MaterialLocalizations.cancelButtonLabel] when null.
  final String? cancelLabel;
  final Widget? icon;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmStyle = switch (type) {
      AppConfirmDialogType.submit => null, // use theme default (primary/blue)
      AppConfirmDialogType.destructive => FilledButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
      ),
    };

    return AlertDialog(
      icon: icon,
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320),
        child: Text(content),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel,
          ),
        ),
        FilledButton(
          key: confirmKey,
          style: confirmStyle,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Shows an [AppConfirmDialog] and returns `true` when the user confirms,
/// `false` when they cancel, and `null` when the dialog is dismissed by
/// tapping outside (barrier).
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  AppConfirmDialogType type = AppConfirmDialogType.submit,
  String? cancelLabel,
  Widget? icon,
  Key? confirmKey,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AppConfirmDialog(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      type: type,
      cancelLabel: cancelLabel,
      icon: icon,
      confirmKey: confirmKey,
    ),
  );
}
