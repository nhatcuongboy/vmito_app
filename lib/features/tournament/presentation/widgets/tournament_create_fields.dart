import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_create_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_create_field_widgets.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_location_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentCreateFields extends StatelessWidget {
  const TournamentCreateFields({
    required this.form,
    required this.isWide,
    required this.onPickLocation,
    required this.onClearLocation,
    super.key,
  });

  final FormGroup form;
  final bool isWide;
  final VoidCallback onPickLocation;
  final VoidCallback onClearLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tournamentCreateBasicInformation,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.lg),
        ReactiveTextField<String>(
          key: const Key('tournament-name-field'),
          formControlName: TournamentCreateControl.name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.tournamentCreateName,
            hintText: l10n.tournamentCreateNameHint,
          ),
          validationMessages: {
            ValidationMessage.required: (_) =>
                l10n.tournamentCreateNameRequired,
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.tournamentCreateSport,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        ReactiveValueListenableBuilder<TournamentSportType>(
          formControlName: TournamentCreateControl.sportType,
          builder: (context, control, _) => Row(
            children: [
              for (final sport in TournamentSportType.values) ...[
                Expanded(
                  child: TournamentSportCard(
                    sport: sport,
                    selected: control.value == sport,
                    onTap: () => control.value = sport,
                  ),
                ),
                if (sport == TournamentSportType.badminton)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(AppIcons.calendarMonth, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.tournamentCreateSchedule,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TournamentDateField(
                  controlName: TournamentCreateControl.startDate,
                  label: l10n.tournamentCreateStartDate,
                  requiredMessage: l10n.tournamentCreateStartDateRequired,
                  domainError: TournamentCreateValidation.startDatePast,
                  domainMessage: l10n.tournamentCreateStartDatePast,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TournamentDateField(
                  controlName: TournamentCreateControl.endDate,
                  label: l10n.tournamentCreateEndDate,
                  requiredMessage: l10n.tournamentCreateEndDateRequired,
                  domainError: TournamentCreateValidation.endBeforeStart,
                  domainMessage: l10n.tournamentCreateEndBeforeStart,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              TournamentDateField(
                controlName: TournamentCreateControl.startDate,
                label: l10n.tournamentCreateStartDate,
                requiredMessage: l10n.tournamentCreateStartDateRequired,
                domainError: TournamentCreateValidation.startDatePast,
                domainMessage: l10n.tournamentCreateStartDatePast,
              ),
              const SizedBox(height: AppSpacing.md),
              TournamentDateField(
                controlName: TournamentCreateControl.endDate,
                label: l10n.tournamentCreateEndDate,
                requiredMessage: l10n.tournamentCreateEndDateRequired,
                domainError: TournamentCreateValidation.endBeforeStart,
                domainMessage: l10n.tournamentCreateEndBeforeStart,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        TournamentLocationField(
          form: form,
          onPick: onPickLocation,
          onClear: onClearLocation,
        ),
        const SizedBox(height: AppSpacing.lg),
        TournamentNextStepsCard(
          title: l10n.tournamentCreateNextStepsTitle,
          text: l10n.tournamentCreateNextStepsDescription,
        ),
      ],
    );
  }
}
