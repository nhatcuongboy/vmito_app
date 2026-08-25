import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';

abstract final class MatchEditFormControl {
  static const noResult = 'noResult';
  static const pair1Score = 'pair1Score';
  static const pair2Score = 'pair2Score';
  static const isExtra = 'isExtra';
  static const shuttlecockCount = 'shuttlecockCount';
  static const notes = 'notes';

  static String player(int index) => 'player$index';
}

FormGroup matchEditForm({
  required Match match,
  required int? pair1Score,
  required int? pair2Score,
}) {
  final ids = match.orderedPlayerIds;
  final hasResult = pair1Score != null || pair2Score != null;
  return FormGroup(
    {
      MatchEditFormControl.noResult: FormControl<bool>(value: !hasResult),
      MatchEditFormControl.pair1Score: FormControl<String>(
        value: pair1Score?.toString() ?? '',
        validators: [Validators.delegate(_nonNegativeInteger)],
      ),
      MatchEditFormControl.pair2Score: FormControl<String>(
        value: pair2Score?.toString() ?? '',
        validators: [Validators.delegate(_nonNegativeInteger)],
      ),
      for (var index = 0; index < ids.length; index++)
        MatchEditFormControl.player(index): FormControl<String>(
          value: ids[index],
          validators: [Validators.required],
        ),
      MatchEditFormControl.isExtra: FormControl<bool>(value: match.isExtra),
      MatchEditFormControl.shuttlecockCount: FormControl<String>(
        value: match.shuttlecockCount?.toString() ?? '',
        validators: [Validators.delegate(_nonNegativeNumber)],
      ),
      MatchEditFormControl.notes: FormControl<String>(value: match.notes ?? ''),
    },
    validators: [Validators.delegate(_uniquePlayers(ids.length))],
  );
}

ValidatorFunction _uniquePlayers(int playerCount) => (control) {
  if (control is! FormGroup) return null;
  final ids = [
    for (var index = 0; index < playerCount; index++)
      control.control(MatchEditFormControl.player(index)).value as String?,
  ].whereType<String>().where((id) => id.isNotEmpty).toList();
  return ids.length == playerCount && ids.toSet().length != playerCount
      ? {'duplicatePlayers': true}
      : null;
};

Map<String, dynamic>? _nonNegativeNumber(AbstractControl<dynamic> control) {
  final text = (control.value as String? ?? '').trim();
  if (text.isEmpty) return null;
  final value = num.tryParse(text);
  return value == null || value < 0 ? {'nonNegativeNumber': true} : null;
}

Map<String, dynamic>? _nonNegativeInteger(AbstractControl<dynamic> control) {
  final text = (control.value as String? ?? '').trim();
  if (text.isEmpty) return null;
  final value = int.tryParse(text);
  return value == null || value < 0 ? {'nonNegativeNumber': true} : null;
}

MatchUpdateDraft matchUpdateDraftFromForm(
  FormGroup form, {
  required int playerCount,
  required CourtDirection direction,
}) {
  final ids = [
    for (var index = 0; index < playerCount; index++)
      form.control(MatchEditFormControl.player(index)).value! as String,
  ];
  final firstIndexes = playerCount <= 2
      ? const [0]
      : direction == CourtDirection.vertical
      ? const [0, 2]
      : const [0, 1];
  final secondIndexes = playerCount <= 2
      ? const [1]
      : direction == CourtDirection.vertical
      ? const [1, 3]
      : const [2, 3];
  int score(String name) =>
      int.tryParse((form.control(name).value as String? ?? '').trim()) ?? 0;
  final shuttlecockText =
      (form.control(MatchEditFormControl.shuttlecockCount).value as String? ??
              '')
          .trim();
  return MatchUpdateDraft(
    playerIds: ids,
    pair1PlayerIds: [for (final index in firstIndexes) ids[index]],
    pair2PlayerIds: [for (final index in secondIndexes) ids[index]],
    noResult:
        form.control(MatchEditFormControl.noResult).value as bool? ?? false,
    pair1Score: score(MatchEditFormControl.pair1Score),
    pair2Score: score(MatchEditFormControl.pair2Score),
    isExtra: form.control(MatchEditFormControl.isExtra).value as bool? ?? false,
    notes: form.control(MatchEditFormControl.notes).value as String? ?? '',
    shuttlecockCount: shuttlecockText.isEmpty
        ? null
        : double.tryParse(shuttlecockText),
  );
}
