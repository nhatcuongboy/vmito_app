import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_create_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class TournamentLocationField extends StatelessWidget {
  const TournamentLocationField({
    required this.form,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final FormGroup form;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppOptionalLabel(
          l10n.tournamentCreateLocation,
          optionalText: l10n.tournamentCreateOptional,
        ),
        const SizedBox(height: AppSpacing.sm),
        ReactiveValueListenableBuilder<String>(
          formControlName: TournamentCreateControl.locationQuery,
          builder: (context, control, _) => InkWell(
            key: const Key('tournament-location-field'),
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(AppIcons.location),
                suffixIcon: const Icon(AppIcons.search),
                hintText: l10n.tournamentCreateLocationHint,
              ),
              child: Text(
                control.value?.trim().isNotEmpty == true
                    ? control.value!
                    : l10n.tournamentCreateLocationHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: control.value?.trim().isNotEmpty == true
                    ? null
                    : TextStyle(color: palette.mutedForeground),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.tournamentCreateLocationHelper,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.mutedForeground),
        ),
        ReactiveValueListenableBuilder<String>(
          formControlName: TournamentCreateControl.locationName,
          builder: (context, control, _) {
            final name = control.value?.trim() ?? '';
            if (name.isEmpty) return const SizedBox.shrink();
            final address =
                form.control(TournamentCreateControl.locationAddress).value
                    as String?;
            return Container(
              key: const Key('tournament-selected-location'),
              margin: const EdgeInsets.only(top: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .08),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .3),
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.checkCircle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tournamentCreateSelectedLocation,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (address?.trim().isNotEmpty == true &&
                            address!.trim() != name)
                          Text(
                            address,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.mutedForeground),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('tournament-clear-location'),
                    onPressed: onClear,
                    child: Text(l10n.tournamentCreateClearLocation),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
