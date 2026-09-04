import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentSportCard extends StatelessWidget {
  const TournamentSportCard({
    required this.sport,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TournamentSportType sport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final selectedColor = sport == TournamentSportType.badminton
        ? Theme.of(context).colorScheme.primary
        : Colors.deepPurple;
    final label = sport == TournamentSportType.badminton
        ? l10n.tournamentCreateBadminton
        : l10n.tournamentCreatePickleball;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: ShapeDecoration(
          color: selected ? selectedColor : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: selected ? selectedColor : palette.border,
              width: selected ? 1 : 2,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('tournament-sport-${sport.name}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sport == TournamentSportType.badminton)
                    Image.asset(
                      'assets/icons/shuttlecock.png',
                      width: 22,
                      height: 22,
                    )
                  else
                    Icon(
                      Icons.sports_tennis,
                      size: 20,
                      color: selected ? Colors.white : null,
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? Colors.white : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentDateField extends StatelessWidget {
  const TournamentDateField({
    required this.controlName,
    required this.label,
    required this.requiredMessage,
    required this.domainError,
    required this.domainMessage,
    super.key,
  });

  final String controlName;
  final String label;
  final String requiredMessage;
  final String domainError;
  final String domainMessage;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return ReactiveDatePicker<DateTime>(
      formControlName: controlName,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
      builder: (context, picker, _) {
        final control = picker.control;
        final error = control.touched && control.invalid
            ? control.hasError(ValidationMessage.required)
                  ? requiredMessage
                  : control.hasError(domainError)
                  ? domainMessage
                  : null
            : null;
        final value = picker.value;
        return InkWell(
          key: Key('tournament-$controlName-field'),
          onTap: picker.showPicker,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(AppIcons.calendar),
              errorText: error,
            ),
            child: Text(
              value == null
                  ? AppLocalizations.of(context).tournamentCreateDateHint
                  : DateFormat.yMd(
                      Localizations.localeOf(context).toString(),
                    ).format(value),
            ),
          ),
        );
      },
    );
  }
}

class TournamentNextStepsCard extends StatelessWidget {
  const TournamentNextStepsCard({
    required this.title,
    required this.text,
    super.key,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).extension<AppPalette>()!.muted,
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.location, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );
}
