import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_management_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class TournamentManagersPanel extends ConsumerStatefulWidget {
  const TournamentManagersPanel({required this.tournamentId, super.key});
  final String tournamentId;

  @override
  ConsumerState<TournamentManagersPanel> createState() =>
      _TournamentManagersPanelState();
}

class _TournamentManagersPanelState
    extends ConsumerState<TournamentManagersPanel> {
  late final FormGroup managerForm = tournamentManagerForm(
    permissions: {...TournamentPermission.values},
  );
  Timer? debounce;
  String query = '';
  TournamentUserOption? selectedUser;

  @override
  void initState() {
    super.initState();
    managerForm.control(TournamentManagerControl.query).valueChanges.listen((
      value,
    ) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => query = value?.toString() ?? '');
      });
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    managerForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final managers = ref.watch(tournamentManagersProvider(widget.tournamentId));
    final mutation = ref.watch(tournamentManagerControllerProvider);
    final users = query.trim().length < 2
        ? const AsyncData<List<TournamentUserOption>>([])
        : ref.watch(tournamentUserSearchProvider(query));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          l10n.tournamentManageManagers,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppReactiveForm(
          formGroup: managerForm,
          child: ReactiveTextField<String>(
            formControlName: TournamentManagerControl.query,
            decoration: InputDecoration(
              labelText: l10n.tournamentManageSearchUsers,
              prefixIcon: const Icon(AppIcons.search),
            ),
          ),
        ),
        users.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) => Column(
            children: [
              for (final user in items.take(6))
                ListTile(
                  selected: selectedUser?.id == user.id,
                  onTap: () => setState(() {
                    selectedUser = user;
                    managerForm.control(TournamentManagerControl.userId).value =
                        user.id;
                  }),
                  title: Text(user.name.isEmpty ? user.email : user.name),
                  subtitle: Text(user.email),
                  trailing: selectedUser?.id == user.id
                      ? const Icon(AppIcons.check)
                      : null,
                ),
            ],
          ),
        ),
        if (selectedUser != null) ...[
          AppReactiveForm(
            formGroup: managerForm,
            child: Column(
              children: [
                const _PermissionSelector(),
                ReactiveFormConsumer(
                  builder: (context, form, _) =>
                      form.hasError(
                        TournamentManagementValidation.permissionsRequired,
                      )
                      ? Text(
                          l10n.tournamentManagePermissionsRequired,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: mutation.isLoading
                ? null
                : () async {
                    managerForm.markAllAsTouched();
                    if (managerForm.invalid || managerForm.pending) return;
                    try {
                      await ref
                          .read(tournamentManagerControllerProvider.notifier)
                          .add(
                            widget.tournamentId,
                            selectedUser!.id,
                            tournamentManagerPermissions(managerForm),
                          );
                      if (mounted) {
                        setState(() {
                          selectedUser = null;
                          query = '';
                          managerForm.reset(
                            value: {
                              for (final permission
                                  in TournamentPermission.values)
                                TournamentManagerControl.permission(
                                  permission,
                                ): true,
                            },
                          );
                        });
                      }
                    } on Object {
                      if (mounted) _showMutationError();
                    }
                  },
            icon: const Icon(AppIcons.userPlus),
            label: Text(l10n.tournamentManageAddManager),
          ),
        ],
        const Divider(height: AppSpacing.xxl),
        managers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(
                tournamentManagersProvider(widget.tournamentId),
              ),
              child: Text(l10n.commonRetry),
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(child: Text(l10n.tournamentManageManagersEmpty))
              : Column(
                  children: [
                    for (final manager in items)
                      Card(
                        child: ListTile(
                          title: Text(
                            manager.user?.name.isNotEmpty == true
                                ? manager.user!.name
                                : manager.user?.email ?? manager.userId,
                          ),
                          subtitle: Text(
                            manager.permissions
                                .map((item) => _permissionLabel(l10n, item))
                                .join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await _editManager(manager);
                              } else if (action == 'delete') {
                                await _removeManager(manager);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(l10n.commonEdit),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.commonDelete),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _editManager(TournamentManager manager) async {
    final editForm = tournamentManagerForm(
      userId: manager.userId,
      permissions: manager.permissions,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AppReactiveForm(
        formGroup: editForm,
        child: AlertDialog(
          title: Text(AppLocalizations.of(context).tournamentManageManagers),
          content: const _PermissionSelector(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            ReactiveFormConsumer(
              builder: (context, form, _) => FilledButton(
                onPressed: () {
                  form.markAllAsTouched();
                  if (form.invalid || form.pending) return;
                  Navigator.pop(context, true);
                },
                child: Text(AppLocalizations.of(context).commonSave),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      try {
        await ref
            .read(tournamentManagerControllerProvider.notifier)
            .update(
              widget.tournamentId,
              manager.userId,
              tournamentManagerPermissions(editForm),
            );
      } on Object {
        if (mounted) _showMutationError();
      }
    }
    editForm.dispose();
  }

  Future<void> _removeManager(TournamentManager manager) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.commonDelete,
      content: manager.user?.name.isNotEmpty == true
          ? manager.user!.name
          : manager.user?.email ?? manager.userId,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(tournamentManagerControllerProvider.notifier)
          .remove(widget.tournamentId, manager.userId);
    } on Object {
      if (mounted) _showMutationError();
    }
  }

  void _showMutationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).tournamentManageSaveFailed,
        ),
      ),
    );
  }
}

class _PermissionSelector extends StatelessWidget {
  const _PermissionSelector();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final permission in TournamentPermission.values)
        ReactiveCheckboxListTile(
          formControlName: TournamentManagerControl.permission(permission),
          title: Text(
            _permissionLabel(AppLocalizations.of(context), permission),
          ),
          contentPadding: EdgeInsets.zero,
        ),
    ],
  );
}

class TournamentDuplicatePanel extends ConsumerStatefulWidget {
  const TournamentDuplicatePanel({
    required this.idOrSlug,
    required this.tournament,
    super.key,
  });
  final String idOrSlug;
  final TournamentDetail tournament;

  @override
  ConsumerState<TournamentDuplicatePanel> createState() =>
      _TournamentDuplicatePanelState();
}

class _TournamentDuplicatePanelState
    extends ConsumerState<TournamentDuplicatePanel> {
  late final FormGroup form = tournamentDuplicateForm(widget.tournament);
  Timer? venueDebounce;
  StreamSubscription<Object?>? scheduleSubscription;
  String venueQuery = '';
  Venue? selectedVenue;

  @override
  void initState() {
    super.initState();
    form.control(TournamentDuplicateControl.venueQuery).valueChanges.listen((
      value,
    ) {
      venueDebounce?.cancel();
      venueDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => venueQuery = value?.toString() ?? '');
      });
    });
    scheduleSubscription = form
        .control(TournamentDuplicateControl.copySchedule)
        .valueChanges
        .listen((value) {
          final results = form.control(TournamentDuplicateControl.copyResults);
          if (value != true) {
            results
              ..value = false
              ..markAsDisabled();
          } else {
            results.markAsEnabled();
          }
        });
  }

  @override
  void dispose() {
    venueDebounce?.cancel();
    unawaited(scheduleSubscription?.cancel());
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(
      tournamentManagementControllerProvider(widget.idOrSlug).select(
        (state) => state.isMutating,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          l10n.tournamentManageDuplicate,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppReactiveForm(
          formGroup: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReactiveTextField<String>(
                formControlName: TournamentDuplicateControl.name,
                decoration: InputDecoration(
                  labelText: l10n.tournamentManageName,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DuplicateDate(
                name: TournamentDuplicateControl.startDate,
                label: l10n.tournamentManageStartDate,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DuplicateDate(
                name: TournamentDuplicateControl.endDate,
                label: l10n.tournamentManageEndDate,
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveTextField<String>(
                formControlName: TournamentDuplicateControl.venueQuery,
                decoration: InputDecoration(
                  labelText: l10n.sessionFormSearchVenue,
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: selectedVenue == null
                      ? null
                      : IconButton(
                          tooltip: l10n.commonRemove,
                          onPressed: () => setState(() {
                            selectedVenue = null;
                            form
                                    .control(
                                      TournamentDuplicateControl.venueId,
                                    )
                                    .value =
                                null;
                          }),
                          icon: const Icon(AppIcons.close),
                        ),
                ),
              ),
              if (selectedVenue != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.location),
                  title: Text(selectedVenue!.name),
                  subtitle: Text(
                    [
                          selectedVenue!.address,
                          selectedVenue!.district,
                          selectedVenue!.city,
                        ]
                        .whereType<String>()
                        .where((text) => text.isNotEmpty)
                        .join(
                          ', ',
                        ),
                  ),
                  trailing: const Icon(AppIcons.check),
                )
              else
                _VenueSearchResults(
                  query: venueQuery,
                  onSelect: (venue) => setState(() {
                    selectedVenue = venue;
                    form.control(TournamentDuplicateControl.venueId).value =
                        venue.id;
                    form.control(TournamentDuplicateControl.venueQuery).value =
                        venue.name;
                  }),
                ),
              const Divider(height: AppSpacing.xxl),
              ReactiveSwitchListTile(
                formControlName: TournamentDuplicateControl.copyFormat,
                title: Text(l10n.tournamentManageCopyFormat),
              ),
              _copySwitch(
                TournamentDuplicateControl.copySchedule,
                l10n.tournamentManageCopySchedule,
              ),
              _copySwitch(
                TournamentDuplicateControl.copyTeams,
                l10n.tournamentManageCopyTeams,
              ),
              _copySwitch(
                TournamentDuplicateControl.copyResults,
                l10n.tournamentManageCopyResults,
              ),
              _copySwitch(
                TournamentDuplicateControl.copyVenues,
                l10n.tournamentManageCopyVenues,
              ),
              _copySwitch(
                TournamentDuplicateControl.copyHome,
                l10n.tournamentManageCopyHome,
              ),
              ReactiveFormConsumer(
                builder: (context, form, _) =>
                    form.hasError(
                      TournamentManagementValidation.resultRequiresSchedule,
                    )
                    ? Text(
                        l10n.tournamentManageResultsRequireSchedule,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              ReactiveFormConsumer(
                builder: (context, form, _) => FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          form.markAllAsTouched();
                          if (form.invalid || form.pending) return;
                          try {
                            final duplicated = await ref
                                .read(
                                  tournamentManagementControllerProvider(
                                    widget.idOrSlug,
                                  ).notifier,
                                )
                                .duplicate(duplicateDraftFromForm(form));
                            if (context.mounted) {
                              context.go(
                                AppRoutes.manageTournament(duplicated.slug),
                              );
                            }
                          } on Object {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.tournamentManageSaveFailed,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(AppIcons.copy),
                  label: Text(l10n.tournamentManageDuplicate),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ReactiveSwitchListTile _copySwitch(String name, String label) =>
      ReactiveSwitchListTile(formControlName: name, title: Text(label));
}

class _VenueSearchResults extends ConsumerWidget {
  const _VenueSearchResults({required this.query, required this.onSelect});
  final String query;
  final ValueChanged<Venue> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(tournamentVenueSearchProvider(query));
    return venues.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => ref.invalidate(tournamentVenueSearchProvider(query)),
          child: Text(AppLocalizations.of(context).commonRetry),
        ),
      ),
      data: (items) => Column(
        children: [
          for (final venue in items.take(6))
            ListTile(
              minTileHeight: 56,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.location),
              title: Text(venue.name),
              subtitle: Text(
                [venue.address, venue.district, venue.city]
                    .whereType<String>()
                    .where((text) => text.isNotEmpty)
                    .join(', '),
              ),
              onTap: () => onSelect(venue),
            ),
        ],
      ),
    );
  }
}

class _DuplicateDate extends StatelessWidget {
  const _DuplicateDate({required this.name, required this.label});
  final String name;
  final String label;

  @override
  Widget build(BuildContext context) => ReactiveDatePicker<DateTime>(
    formControlName: name,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
    builder: (context, picker, _) => ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: picker.showPicker,
      leading: const Icon(AppIcons.calendar),
      title: Text(label),
      subtitle: Text(
        picker.value?.toLocal().toString().split(' ').first ?? '—',
      ),
    ),
  );
}

String _permissionLabel(
  AppLocalizations l10n,
  TournamentPermission permission,
) => switch (permission) {
  TournamentPermission.results => l10n.tournamentManagePermissionResults,
  TournamentPermission.schedule => l10n.tournamentManagePermissionSchedule,
  TournamentPermission.participants =>
    l10n.tournamentManagePermissionParticipants,
  TournamentPermission.structure => l10n.tournamentManagePermissionStructure,
};
