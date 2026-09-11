import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// "Submitted 2 days ago" for the last week, then the absolute date. A
/// relative time tells a host how stale a request is at a glance; past a
/// week the exact day is more useful.
String clubRequestSubmittedLabel(
  BuildContext context,
  DateTime date, {
  DateTime? now,
}) {
  final locale = Localizations.localeOf(context);
  final age = (now ?? DateTime.now()).difference(date.toLocal());
  final when = age.inDays < 7
      ? Dates.timeAgo(date, locale: locale.languageCode)
      : DateFormat.yMMMd(locale.toLanguageTag()).format(date.toLocal());
  return AppLocalizations.of(context).clubRequestSubmitted(when);
}

/// Runs a club management mutation and reports the outcome in a snackbar.
Future<void> runClubAction(
  BuildContext context,
  Future<void> Function() action,
  String failure, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
    }
  }
}

/// Asks for the mandatory rejection reason; `null` when cancelled.
Future<String?> askClubRejectionReason(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final form = FormGroup({
    'reason': FormControl<String>(validators: [Validators.required]),
  });
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.clubReject),
      content: AppReactiveForm<void>(
        formGroup: form,
        child: ReactiveTextField<String>(
          key: const Key('club-rejection-reason'),
          formControlName: 'reason',
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.clubRejectionReason),
          validationMessages: {
            ValidationMessage.required: (_) => l10n.clubRejectionReasonRequired,
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            form.markAllAsTouched();
            if (form.invalid || form.pending) return;
            Navigator.pop(
              dialogContext,
              (form.control('reason').value as String).trim(),
            );
          },
          child: Text(l10n.clubReject),
        ),
      ],
    ),
  );
  form.dispose();
  return result;
}
