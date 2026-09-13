import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_create_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_create_form.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_create_chrome.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_create_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_location_picker_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_form_submit_bar.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

const _wideTournamentFormBreakpoint = 700.0;
const _maxTournamentFormWidth = 760.0;

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  late final FormGroup _form;
  StreamSubscription<Object?>? _formSubscription;
  bool _allowNavigation = false;

  @override
  void initState() {
    super.initState();
    _form = createTournamentReactiveForm();
    _formSubscription = _form.valueChanges.listen((_) {
      _applyDateErrors();
      if (mounted) setState(() {});
    });
    unawaited(
      Future<void>.microtask(
        () => ref.read(tournamentCreateControllerProvider.notifier).reset(),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_formSubscription?.cancel());
    _form.dispose();
    super.dispose();
  }

  void _applyDateErrors() {
    final startControl = _form.control(TournamentCreateControl.startDate);
    final endControl = _form.control(TournamentCreateControl.endDate);
    startControl.removeError(TournamentCreateValidation.startDatePast);
    endControl.removeError(TournamentCreateValidation.endBeforeStart);
    final errors = validateTournamentDates(
      startDate: startControl.value as DateTime?,
      endDate: endControl.value as DateTime?,
      today: DateTime.now(),
    );
    if (errors[TournamentCreateField.startDate] ==
        TournamentCreateError.startDatePast) {
      startControl.setErrors({
        ...startControl.errors,
        TournamentCreateValidation.startDatePast: true,
      });
    }
    if (errors[TournamentCreateField.endDate] ==
        TournamentCreateError.endBeforeStart) {
      endControl.setErrors({
        ...endControl.errors,
        TournamentCreateValidation.endBeforeStart: true,
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _form.markAllAsTouched();
    _applyDateErrors();
    if (_form.invalid || _form.pending) {
      setState(() {});
      return;
    }
    final created = await ref
        .read(tournamentCreateControllerProvider.notifier)
        .submit(_form.toTournamentCreateRequest());
    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).tournamentCreateFailed,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).tournamentCreateSuccess,
        ),
      ),
    );
    // Hand the tournament back to whoever pushed this screen (the host list
    // opens it next, as web does); a deep link has nothing to return to.
    setState(() => _allowNavigation = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(created);
    } else {
      context.go(AppRoutes.homeForDiscoveryTab('tournaments'));
    }
  }

  Future<void> _pickLocation() async {
    final query =
        _form.control(TournamentCreateControl.locationQuery).value as String?;
    final choice = await showModalBottomSheet<TournamentLocationChoice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => TournamentLocationPickerSheet(
        initialQuery: query ?? '',
      ),
    );
    if (choice == null) return;
    final details = choice.details;
    _form
      ..control(TournamentCreateControl.locationQuery).value = choice.query
      ..control(TournamentCreateControl.locationName).value = choice.name ?? ''
      ..control(TournamentCreateControl.locationAddress).value =
          details?.address ?? choice.query
      ..control(TournamentCreateControl.locationPlaceId).value =
          details?.placeId ?? ''
      ..control(TournamentCreateControl.locationLatitude).value =
          details?.latitude
      ..control(TournamentCreateControl.locationLongitude).value =
          details?.longitude
      ..control(TournamentCreateControl.locationDistrict).value =
          details?.district ?? ''
      ..control(TournamentCreateControl.locationCity).value =
          details?.city ?? ''
      ..markAsDirty();
  }

  void _clearLocation() {
    for (final name in [
      TournamentCreateControl.locationQuery,
      TournamentCreateControl.locationName,
      TournamentCreateControl.locationAddress,
      TournamentCreateControl.locationPlaceId,
      TournamentCreateControl.locationLatitude,
      TournamentCreateControl.locationLongitude,
      TournamentCreateControl.locationDistrict,
      TournamentCreateControl.locationCity,
    ]) {
      _form.control(name).reset();
    }
    _form.markAsDirty();
  }

  Future<bool> _confirmDiscard() async {
    if (!_form.dirty || _allowNavigation) return true;
    final l10n = AppLocalizations.of(context);
    return await showAppConfirmDialog(
          context,
          type: AppConfirmDialogType.destructive,
          title: l10n.tournamentCreateUnsavedTitle,
          content: l10n.tournamentCreateUnsavedBody,
          cancelLabel: l10n.tournamentCreateUnsavedStay,
          confirmLabel: l10n.tournamentCreateUnsavedLeave,
        ) ??
        false;
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _allowNavigation = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.homeForDiscoveryTab('tournaments'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      tournamentCreateControllerProvider.select((state) => state.isLoading),
    );
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: !_form.dirty || _allowNavigation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _leave,
            icon: const Icon(AppIcons.arrowBack),
          ),
          title: Text(l10n.tournamentCreateTitle),
        ),
        // The submit button lives in `body`, not `bottomNavigationBar`: see
        // AppFormSubmitBar's doc comment for why.
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= _wideTournamentFormBreakpoint;
            return AppReactiveForm<void>(
              formGroup: _form,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.screenPadding,
                      AppSpacing.screenPadding,
                      isWide ? AppSpacing.screenPadding : 96,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxTournamentFormWidth,
                        ),
                        child: Column(
                          children: [
                            const TournamentCreateHero(),
                            const SizedBox(height: AppSpacing.md),
                            Card(
                              child: Padding(
                                padding: EdgeInsets.all(
                                  isWide ? AppSpacing.lg : AppSpacing.md,
                                ),
                                child: Column(
                                  children: [
                                    TournamentCreateFields(
                                      form: _form,
                                      isWide: isWide,
                                      onPickLocation: _pickLocation,
                                      onClearLocation: _clearLocation,
                                    ),
                                    if (isWide) ...[
                                      const SizedBox(height: AppSpacing.lg),
                                      const Divider(),
                                      AppFormSubmitBar(
                                        buttonKey: const Key(
                                          'tournament-submit-button',
                                        ),
                                        label: isSubmitting
                                            ? l10n.tournamentCreateSubmitting
                                            : l10n.tournamentCreateSubmit,
                                        icon: AppIcons.add,
                                        busy: isSubmitting,
                                        onSubmit: _submit,
                                        inline: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isWide)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AppFormSubmitBar(
                        buttonKey: const Key('tournament-submit-button'),
                        label: isSubmitting
                            ? l10n.tournamentCreateSubmitting
                            : l10n.tournamentCreateSubmit,
                        icon: AppIcons.add,
                        busy: isSubmitting,
                        onSubmit: _submit,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
