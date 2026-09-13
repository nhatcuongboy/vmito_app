import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_category_type.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

abstract final class CategoryControl {
  static const name = 'name';
  static const type = 'type';
  static const mode = 'registrationMode';
  static const teamSize = 'teamSize';
}

abstract final class CategoryValidation {
  static const duplicate = 'categoryNameDuplicate';
}

/// [existingNames] are the other categories' names; matching is trimmed and
/// case-insensitive, as on the web.
FormGroup tournamentCategoryForm({
  TournamentCategory? category,
  Iterable<String> existingNames = const [],
}) {
  final taken = {for (final name in existingNames) name.trim().toLowerCase()};
  final mode = category?.registrationMode ?? TournamentRegistrationMode.team;
  final form = FormGroup({
    CategoryControl.name: FormControl<String>(
      value: category?.name,
      validators: [
        Validators.delegate((control) {
          final text = (control.value as String?)?.trim() ?? '';
          if (text.isEmpty) return {ValidationMessage.required: true};
          return taken.contains(text.toLowerCase())
              ? {CategoryValidation.duplicate: true}
              : null;
        }),
      ],
    ),
    CategoryControl.type: FormControl<String>(
      value: category?.type ?? TournamentCategoryType.custom,
    ),
    CategoryControl.mode: FormControl<TournamentRegistrationMode>(value: mode),
    CategoryControl.teamSize: FormControl<int>(
      value: category?.teamSize ?? 2,
      validators: [Validators.required, Validators.min(2)],
    ),
  });
  _syncTeamSizeEnabled(form);
  return form;
}

/// Choosing a type resets mode and size the way the backend will anyway.
void applyCategoryType(FormGroup form, String type) {
  final config = registrationConfigForType(type);
  form.control(CategoryControl.mode).value = config.mode;
  form.control(CategoryControl.teamSize).value = config.teamSize;
  _syncTeamSizeEnabled(form);
}

void applyRegistrationMode(FormGroup form, TournamentRegistrationMode mode) {
  form.control(CategoryControl.teamSize).value =
      mode == TournamentRegistrationMode.individual ? 1 : 2;
  _syncTeamSizeEnabled(form);
}

// A disabled control skips validation, so the "at least 2" rule only applies
// to team registration.
void _syncTeamSizeEnabled(FormGroup form) {
  final teamSize = form.control(CategoryControl.teamSize);
  if (form.control(CategoryControl.mode).value ==
      TournamentRegistrationMode.team) {
    teamSize.markAsEnabled();
  } else {
    teamSize.markAsDisabled();
  }
}

class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.type,
    required this.registrationMode,
    required this.teamSize,
  });

  factory CategoryDraft.fromForm(FormGroup form) {
    final mode =
        form.control(CategoryControl.mode).value as TournamentRegistrationMode;
    return CategoryDraft(
      name: (form.control(CategoryControl.name).value as String).trim(),
      type: form.control(CategoryControl.type).value as String,
      registrationMode: mode,
      teamSize: mode == TournamentRegistrationMode.individual
          ? 1
          : form.control(CategoryControl.teamSize).value as int,
    );
  }

  final String name;
  final String type;
  final TournamentRegistrationMode registrationMode;
  final int teamSize;

  bool sameAs(TournamentCategory category) =>
      name == category.name &&
      type == category.type &&
      registrationMode == category.registrationMode &&
      teamSize == category.teamSize;

  /// On create, pickleball categories start from the sport's rally defaults
  /// (web: `CategoriesPanel` sends BEST_OF_1, 11 points, win by two, no cap).
  Map<String, dynamic> toJson({
    bool create = false,
    scoring.SportType sport = scoring.SportType.badminton,
  }) => {
    'name': name,
    'type': type,
    'registrationMode': registrationMode.wireValue,
    'teamSize': teamSize,
    if (create && sport == scoring.SportType.pickleball) ...{
      'matchFormat': 'BEST_OF_1',
      'pointsToWin': 11,
      'winByTwo': true,
      'pointCap': null,
    },
  };
}
