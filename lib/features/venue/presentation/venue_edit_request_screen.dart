import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/venue/application/venue_edit_request_controller.dart';
import 'package:vmito_app/features/venue/domain/form/venue_edit_request_form.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_time_picker.dart';

class VenueEditRequestScreen extends ConsumerStatefulWidget {
  const VenueEditRequestScreen({required this.venue, super.key});

  final Venue venue;

  @override
  ConsumerState<VenueEditRequestScreen> createState() =>
      _VenueEditRequestScreenState();
}

class _VenueEditRequestScreenState
    extends ConsumerState<VenueEditRequestScreen> {
  late final FormGroup _form;
  late final StreamSubscription<String?> _citySubscription;
  var _additionalOpen = false;

  @override
  void initState() {
    super.initState();
    _form = createVenueEditRequestForm(widget.venue);
    var previousCity =
        _form.control(VenueEditRequestControl.newCity).value as String?;
    _citySubscription =
        (_form.control(VenueEditRequestControl.newCity) as FormControl<String>)
            .valueChanges
            .listen((city) {
              if (city != previousCity) {
                previousCity = city;
                _form.control(VenueEditRequestControl.newDistrict).reset();
              }
            });
  }

  @override
  void dispose() {
    unawaited(_citySubscription.cancel());
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final success = await ref
        .read(venueEditRequestControllerProvider.notifier)
        .submit(
          venueId: widget.venue.id,
          draft: venueEditRequestDraftFromForm(_form),
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.venueEditSubmitError)));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submitting = ref.watch(
      venueEditRequestControllerProvider.select((state) => state.isSubmitting),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.venueEditTitle),
        actions: [
          IconButton(
            key: const Key('venue-edit-close'),
            tooltip: l10n.commonClose,
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
      body: AppReactiveForm<void>(
        formGroup: _form,
        child: AbsorbPointer(
          absorbing: submitting,
          child: ListView(
            key: const Key('venue-edit-scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.venueEditDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RequiredFields(form: _form),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        key: const Key('venue-edit-additional-toggle'),
                        onPressed: () => setState(
                          () => _additionalOpen = !_additionalOpen,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(l10n.venueEditAdditionalInfo)),
                            Icon(
                              _additionalOpen
                                  ? AppIcons.arrowUpward
                                  : AppIcons.arrowDownward,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _additionalOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _AdditionalFields(form: _form),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          child: FilledButton(
            key: const Key('venue-edit-submit'),
            onPressed: submitting ? null : _submit,
            child: submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.venueEditSubmit),
          ),
        ),
      ),
    );
  }
}

class _RequiredFields extends ConsumerWidget {
  const _RequiredFields({required this.form});

  final FormGroup form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          l10n: l10n,
          key: const Key('venue-edit-name'),
          controlName: VenueEditRequestControl.name,
          label: l10n.venueEditName,
          required: true,
          maxLength: 200,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium,
          child: AppRequiredLabel(l10n.venueEditSports),
        ),
        const SizedBox(height: AppSpacing.xs),
        ReactiveValueListenableBuilder<Set<String>>(
          formControlName: VenueEditRequestControl.sportTypes,
          builder: (context, control, _) => Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final sport in const ['BADMINTON', 'PICKLEBALL'])
                FilterChip(
                  key: Key('venue-edit-sport-$sport'),
                  label: Text(
                    sport == 'BADMINTON'
                        ? l10n.sessionSportBadminton
                        : l10n.sessionSportPickleball,
                  ),
                  selected: control.value?.contains(sport) ?? false,
                  onSelected: (selected) {
                    final next = {...?control.value};
                    selected ? next.add(sport) : next.remove(sport);
                    control.value = next;
                  },
                ),
            ],
          ),
        ),
        ReactiveValueListenableBuilder<Set<String>>(
          formControlName: VenueEditRequestControl.sportTypes,
          builder: (context, control, _) => control.invalid && control.touched
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.venueEditRequired,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),
        ReactiveValueListenableBuilder<String>(
          formControlName: VenueEditRequestControl.street,
          builder: (context, control, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _textField(
                l10n: l10n,
                key: const Key('venue-edit-street'),
                controlName: VenueEditRequestControl.street,
                label: l10n.venueEditStreet,
                required: true,
                maxLength: 500,
                hint: l10n.venueEditStreetHint,
                helper: hasAdminUnitsInStreet(control.value ?? '')
                    ? null
                    : l10n.venueEditStreetHelper,
              ),
              if (hasAdminUnitsInStreet(control.value ?? '')) ...[
                const SizedBox(height: AppSpacing.xs),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(AppIcons.warning, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(l10n.venueEditStreetWarning)),
                        TextButton(
                          key: const Key('venue-edit-extract-street'),
                          onPressed: () => control.value =
                              extractCleanStreetAddress(control.value ?? ''),
                          child: Text(l10n.venueEditExtractStreet),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _AdminUnitFields(form: form),
      ],
    );
  }
}

class _AdminUnitFields extends ConsumerWidget {
  const _AdminUnitFields({required this.form});

  final FormGroup form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unitsState = ref.watch(newAdminUnitsProvider);
    return switch (unitsState) {
      AsyncData<List<NewAdminUnit>>(:final value) =>
        ReactiveValueListenableBuilder<String>(
          formControlName: VenueEditRequestControl.newCity,
          builder: (context, cityControl, _) {
            final currentCity = cityControl.value ?? '';
            final cities = value.map((unit) => unit.city).toSet();
            final cityItems = <String>{
              if (currentCity.isNotEmpty) currentCity,
              ...cities,
            }.toList();
            final wards = value
                .where((unit) => unit.city == currentCity)
                .expand((unit) => unit.wards)
                .toSet();
            final ward =
                form.control(VenueEditRequestControl.newDistrict).value
                    as String? ??
                '';
            final wardItems = <String>{if (ward.isNotEmpty) ward, ...wards};
            return Column(
              children: [
                ReactiveDropdownField<String>(
                  key: const Key('venue-edit-city'),
                  formControlName: VenueEditRequestControl.newCity,
                  isExpanded: true,
                  decoration: InputDecoration(
                    label: AppRequiredLabel(l10n.venueEditCity),
                  ),
                  validationMessages: _requiredMessages(l10n),
                  items: [
                    for (final city in cityItems)
                      DropdownMenuItem(
                        value: city,
                        enabled: cities.contains(city),
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveDropdownField<String>(
                  key: ValueKey('venue-edit-ward-$currentCity'),
                  formControlName: VenueEditRequestControl.newDistrict,
                  isExpanded: true,
                  readOnly: currentCity.isEmpty || wards.isEmpty,
                  decoration: InputDecoration(
                    label: AppRequiredLabel(l10n.venueEditWard),
                    helperText: l10n.venueEditWardHelper,
                  ),
                  validationMessages: _requiredMessages(l10n),
                  items: [
                    for (final item in wardItems)
                      DropdownMenuItem(
                        value: item,
                        enabled: wards.contains(item),
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      AsyncError() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Text(l10n.venueEditAdminUnitsError),
              TextButton.icon(
                key: const Key('venue-edit-admin-units-retry'),
                onPressed: () => ref.invalidate(newAdminUnitsProvider),
                icon: const Icon(AppIcons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _AdditionalFields extends StatelessWidget {
  const _AdditionalFields({required this.form});

  final FormGroup form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.locatedWithin,
          label: l10n.venueEditLocatedWithin,
          maxLength: 200,
          helper: l10n.venueEditLocatedWithinHelper,
        ),
        const SizedBox(height: AppSpacing.md),
        ReactiveTextField<int>(
          key: const Key('venue-edit-court-count'),
          formControlName: VenueEditRequestControl.numberOfCourts,
          valueAccessor: IntValueAccessor(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.venueEditCourtCount),
          validationMessages: {
            ValidationMessage.number: (_) => l10n.venueEditWholeNumber,
            ValidationMessage.min: (_) => l10n.venueEditPositiveNumber,
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.venueEditOpeningHours,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                controlName: VenueEditRequestControl.openTime,
                label: l10n.venueEditOpenTime,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TimeField(
                controlName: VenueEditRequestControl.closeTime,
                label: l10n.venueEditCloseTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.phone,
          label: l10n.venueEditPhone,
          maxLength: 40,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.website,
          label: l10n.venueEditWebsite,
          maxLength: 500,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.wifiName,
          label: l10n.venueEditWifiName,
          maxLength: 200,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.wifiPassword,
          label: l10n.venueEditWifiPassword,
          maxLength: 200,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.description,
          label: l10n.venueEditVenueDescription,
          maxLength: 5000,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          l10n: l10n,
          controlName: VenueEditRequestControl.note,
          label: l10n.venueEditNote,
          maxLength: 2000,
          hint: l10n.venueEditNoteHint,
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controlName,
    required this.label,
  });

  final String controlName;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) => ReactiveValueListenableBuilder<Duration>(
    formControlName: controlName,
    builder: (context, control, _) {
      final value = control.value;
      final text = value == null
          ? '—'
          : '${value.inHours.toString().padLeft(2, '0')}:'
                '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}';
      return OutlinedButton(
        onPressed: () async {
          final selected = await showAppTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: value?.inHours ?? TimeOfDay.now().hour,
              minute: value?.inMinutes.remainder(60) ?? 0,
            ),
          );
          if (selected != null) {
            control.value = Duration(
              hours: selected.hour,
              minutes: selected.minute,
            );
          }
        },
        child: Column(
          children: [
            Text(label),
            Text(text, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    },
  );
}

ReactiveTextField<String> _textField({
  Key? key,
  required AppLocalizations l10n,
  required String controlName,
  required String label,
  bool required = false,
  int? maxLength,
  String? hint,
  String? helper,
  int? minLines,
  int? maxLines = 1,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
}) => ReactiveTextField<String>(
  key: key,
  formControlName: controlName,
  maxLength: maxLength,
  minLines: minLines,
  maxLines: maxLines,
  keyboardType: keyboardType,
  textInputAction: textInputAction,
  decoration: InputDecoration(
    label: required ? AppRequiredLabel(label) : Text(label),
    hintText: hint,
    helperText: helper,
  ),
  validationMessages: {
    ValidationMessage.required: (_) => l10n.venueEditRequired,
    ValidationMessage.minLength: (_) => l10n.venueEditTooShort,
    ValidationMessage.maxLength: (_) => l10n.venueEditTooLong,
  },
);

Map<String, String Function(Object)> _requiredMessages(
  AppLocalizations l10n,
) => {ValidationMessage.required: (_) => l10n.venueEditRequired};
