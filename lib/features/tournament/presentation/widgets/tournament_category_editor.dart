import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_categories_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_structure_refresh.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_category_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_category_type.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class TournamentCategoryEditor extends ConsumerStatefulWidget {
  const TournamentCategoryEditor({
    required this.tournament,
    required this.idOrSlug,
    this.category,
    super.key,
  });

  final TournamentDetail tournament;
  final String idOrSlug;
  final TournamentCategory? category;

  @override
  ConsumerState<TournamentCategoryEditor> createState() =>
      _TournamentCategoryEditorState();
}

class _TournamentCategoryEditorState
    extends ConsumerState<TournamentCategoryEditor> {
  late final FormGroup _form = tournamentCategoryForm(
    category: widget.category,
    existingNames: [
      for (final item
          in ref.read(tournamentCategoriesProvider(widget.tournament.id)).items)
        if (item.id != widget.category?.id) item.name,
    ],
  );

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tournamentCategoriesProvider(widget.tournament.id));
    return TournamentEditorFrame(
      title: widget.category == null
          ? l10n.tournamentCategoriesCreate
          : l10n.tournamentCategoriesEdit,
      form: _form,
      busy: state.busy,
      error: state.error,
      onSave: _submit,
      children: [
        ReactiveTextField<String>(
          formControlName: CategoryControl.name,
          decoration: InputDecoration(
            label: AppRequiredLabel(l10n.tournamentCategoriesNameLabel),
            hintText: l10n.tournamentCategoriesNamePlaceholder,
          ),
          validationMessages: {
            ValidationMessage.required: (_) =>
                l10n.tournamentCategoriesNameRequired,
            CategoryValidation.duplicate: (_) =>
                l10n.tournamentCategoriesNameDuplicate,
          },
        ),
        ReactiveDropdownField<String>(
          formControlName: CategoryControl.type,
          decoration: InputDecoration(
            labelText: l10n.tournamentCategoriesTypeLabel,
          ),
          items: [
            for (final type in TournamentCategoryType.values)
              DropdownMenuItem(
                value: type,
                child: Text(tournamentCategoryTypeLabel(l10n, type)),
              ),
          ],
          onChanged: (control) => applyCategoryType(_form, control.value!),
        ),
        // Listen to the control itself: `onChanged` fires before a setState
        // rebuild would see the new value, so conditional fields lagged a step.
        ReactiveValueListenableBuilder<String>(
          formControlName: CategoryControl.type,
          builder: (context, type, _) =>
              type.value == TournamentCategoryType.custom
              ? _customFields(l10n)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _customFields(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ReactiveDropdownField<TournamentRegistrationMode>(
        formControlName: CategoryControl.mode,
        decoration: InputDecoration(
          labelText: l10n.tournamentCategoriesRegistrationModeLabel,
        ),
        items: [
          DropdownMenuItem(
            value: TournamentRegistrationMode.individual,
            child: Text(l10n.tournamentCategoriesIndividual),
          ),
          DropdownMenuItem(
            value: TournamentRegistrationMode.team,
            child: Text(l10n.tournamentCategoriesTeam),
          ),
        ],
        onChanged: (control) => applyRegistrationMode(_form, control.value!),
      ),
      ReactiveValueListenableBuilder<TournamentRegistrationMode>(
        formControlName: CategoryControl.mode,
        builder: (context, mode, _) =>
            mode.value != TournamentRegistrationMode.team
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ReactiveTextField<int>(
                  formControlName: CategoryControl.teamSize,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.tournamentCategoriesTeamSizeLabel,
                    hintText: l10n.tournamentCategoriesTeamSizePlaceholder,
                    helperText: l10n.tournamentCategoriesTeamSizeHelp,
                    helperMaxLines: 3,
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.tournamentCategoriesTeamSizeMin,
                    ValidationMessage.min: (_) =>
                        l10n.tournamentCategoriesTeamSizeMin,
                    ValidationMessage.number: (_) =>
                        l10n.tournamentCategoriesTeamSizeMin,
                  },
                ),
              ),
      ),
    ],
  );

  Future<void> _submit() async {
    final draft = CategoryDraft.fromForm(_form);
    final existing = widget.category;
    if (existing != null && draft.sameAs(existing)) {
      Navigator.pop(context);
      return;
    }
    final saved = await ref
        .read(tournamentCategoriesProvider(widget.tournament.id).notifier)
        .save(draft, sport: widget.tournament.sportType, id: existing?.id);
    if (!saved || !mounted) return;
    refreshTournamentStructure(ref, widget.idOrSlug);
    Navigator.pop(context);
  }
}
