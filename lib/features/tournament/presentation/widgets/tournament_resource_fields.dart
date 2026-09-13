import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

Widget resourceField(
  BuildContext context,
  String control,
  String label, {
  bool required = false,
  TextInputType? keyboard,
  int maxLines = 1,
}) => ReactiveTextField<String>(
  formControlName: control,
  maxLines: maxLines,
  keyboardType: keyboard,
  decoration: InputDecoration(
    label: required ? AppRequiredLabel(label) : Text(label),
  ),
  validationMessages: resourceValidationMessages(AppLocalizations.of(context)),
);

Map<String, String Function(Object)> resourceValidationMessages(
  AppLocalizations l,
) => {
  ValidationMessage.required: (_) => l.tournamentPlayerImportNameError,
  ValidationMessage.email: (_) => l.authEmailOrPhoneInvalid,
  ValidationMessage.min: (_) => l.tournamentResourceInvalid,
  ValidationMessage.max: (_) => l.tournamentResourceInvalid,
  ValidationMessage.number: (_) => l.tournamentResourceInvalid,
  'httpUrl': (_) => l.tournamentResourceUrlError,
};

String resourceGenderLabel(AppLocalizations l, String? value) =>
    switch (value) {
      'MALE' => l.profileGenderMale,
      'FEMALE' => l.profileGenderFemale,
      'OTHER' => l.profileGenderOther,
      'PREFER_NOT_TO_SAY' => l.profileGenderPreferNotToSay,
      _ => '—',
    };

Future<void> openResourceEditor(BuildContext context, Widget child) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => child, fullscreenDialog: true),
  );
}

Future<bool> confirmResourceDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Text(
          AppLocalizations.of(context).tournamentResourceDeleteWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    ) ??
    false;
