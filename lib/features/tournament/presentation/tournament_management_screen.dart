import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_manage_panel.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

enum TournamentManageTab { organize, settings }

class TournamentManagementScreen extends ConsumerStatefulWidget {
  const TournamentManagementScreen({
    required this.idOrSlug,
    this.initialOption,
    this.initialCategoryId,
    super.key,
  });

  final String idOrSlug;
  final String? initialOption;
  final String? initialCategoryId;

  @override
  ConsumerState<TournamentManagementScreen> createState() =>
      _TournamentManagementScreenState();
}

class _TournamentManagementScreenState
    extends ConsumerState<TournamentManagementScreen> {
  String? selectedOption;
  late TournamentManageTab tab;

  @override
  void initState() {
    super.initState();
    selectedOption = normalizeTournamentManageOption(widget.initialOption);
    tab = _settingsOptions.contains(selectedOption)
        ? TournamentManageTab.settings
        : TournamentManageTab.organize;
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(
              tournamentManagementControllerProvider(widget.idOrSlug).notifier,
            )
            .load(),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TournamentManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idOrSlug != widget.idOrSlug) {
      selectedOption = normalizeTournamentManageOption(widget.initialOption);
      tab = _settingsOptions.contains(selectedOption)
          ? TournamentManageTab.settings
          : TournamentManageTab.organize;
      unawaited(
        ref
            .read(
              tournamentManagementControllerProvider(widget.idOrSlug).notifier,
            )
            .load(),
      );
    } else if (oldWidget.initialOption != widget.initialOption) {
      selectedOption = normalizeTournamentManageOption(widget.initialOption);
      tab = _settingsOptions.contains(selectedOption)
          ? TournamentManageTab.settings
          : TournamentManageTab.organize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      tournamentManagementControllerProvider(widget.idOrSlug),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(state.tournament?.name ?? l10n.tournamentManageTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            onPressed: state.isLoading
                ? null
                : () => ref
                      .read(
                        tournamentManagementControllerProvider(
                          widget.idOrSlug,
                        ).notifier,
                      )
                      .load(force: true),
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, TournamentManagementState state) {
    final l10n = AppLocalizations.of(context);
    if (!state.hasLoaded || state.isLoading && state.tournament == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null &&
        (state.tournament == null || state.access == null)) {
      return _Message(
        icon: AppIcons.error,
        text: l10n.tournamentManageLoadFailed,
        action: l10n.commonRetry,
        onAction: () => ref
            .read(
              tournamentManagementControllerProvider(widget.idOrSlug).notifier,
            )
            .load(force: true),
      );
    }
    if (!state.canManage) {
      return _Message(
        icon: AppIcons.lock,
        text: l10n.tournamentManageNoAccess,
      );
    }
    final tournament = state.tournament!;
    final access = state.access!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final availableOptions =
            _items(access, settings: false).map((item) => item.option).toSet()
              ..addAll(
                _items(access, settings: true).map((item) => item.option),
              );
        final effectiveTab = access.isHostOrAdmin
            ? tab
            : TournamentManageTab.organize;
        var effectiveOption = availableOptions.contains(selectedOption)
            ? selectedOption
            : null;
        effectiveOption ??= wide
            ? _items(
                access,
                settings: effectiveTab == TournamentManageTab.settings,
              ).firstOrNull?.option
            : null;
        final menu = _ManageMenu(
          tab: effectiveTab,
          access: access,
          tournament: tournament,
          selectedOption: effectiveOption,
          onTab: (value) => setState(() {
            tab = value;
            selectedOption = wide
                ? _items(
                    access,
                    settings: value == TournamentManageTab.settings,
                  ).firstOrNull?.option
                : null;
          }),
          onSelect: (option) => _select(option, wide: wide),
        );
        if (wide) {
          return Row(
            children: [
              SizedBox(width: 340, child: menu),
              const VerticalDivider(width: 1),
              Expanded(
                child: _panel(
                  tournament: tournament,
                  state: state,
                  option: effectiveOption,
                ),
              ),
            ],
          );
        }
        return PopScope(
          canPop: effectiveOption == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && effectiveOption != null) {
              _select(null, wide: false);
            }
          },
          child: effectiveOption == null
              ? menu
              : _panel(
                  tournament: tournament,
                  state: state,
                  option: effectiveOption,
                  showPanelBack: true,
                ),
        );
      },
    );
  }

  void _select(String? option, {required bool wide}) {
    setState(() {
      selectedOption = option;
      if (_settingsOptions.contains(option)) tab = TournamentManageTab.settings;
    });
    if (wide || option != null) {
      context.replace(
        AppRoutes.manageTournament(
          widget.idOrSlug,
          option: option,
          categoryId: widget.initialCategoryId,
        ),
      );
    } else {
      context.replace(AppRoutes.manageTournament(widget.idOrSlug));
    }
  }

  Widget _panel({
    required TournamentDetail tournament,
    required TournamentManagementState state,
    required String? option,
    bool showPanelBack = false,
  }) {
    final child = TournamentManagePanel(
      idOrSlug: widget.idOrSlug,
      tournament: tournament,
      state: state,
      option: option,
      initialCategoryId: widget.initialCategoryId,
    );
    if (!showPanelBack) return child;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => _select(null, wide: false),
            icon: const Icon(AppIcons.arrowBack),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ManageMenu extends StatelessWidget {
  const _ManageMenu({
    required this.tab,
    required this.access,
    required this.tournament,
    required this.selectedOption,
    required this.onTab,
    required this.onSelect,
  });
  final TournamentManageTab tab;
  final TournamentMyAccess access;
  final TournamentDetail tournament;
  final String? selectedOption;
  final ValueChanged<TournamentManageTab> onTab;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items(access, settings: tab == TournamentManageTab.settings);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (access.isHostOrAdmin)
          SegmentedButton<TournamentManageTab>(
            segments: [
              ButtonSegment(
                value: TournamentManageTab.organize,
                label: Text(l10n.tournamentManageOrganize),
              ),
              ButtonSegment(
                value: TournamentManageTab.settings,
                label: Text(l10n.tournamentManageSettings),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (value) => onTab(value.first),
            showSelectedIcon: false,
          ),
        const SizedBox(height: AppSpacing.md),
        for (final item in items)
          Card(
            color: selectedOption == item.option
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              minTileHeight: 64,
              leading: Icon(item.icon),
              title: Text(item.label(l10n)),
              subtitle: item.option == 'teams'
                  ? Text('${tournament.registrationCount}')
                  : null,
              trailing: const Icon(AppIcons.chevronRight),
              selected: selectedOption == item.option,
              onTap: () => onSelect(item.option),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: AppSpacing.md),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class _MenuItem {
  const _MenuItem(this.option, this.icon, this.label, {this.permission});
  final String option;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final TournamentPermission? permission;
}

List<_MenuItem> _items(TournamentMyAccess access, {required bool settings}) {
  final source = settings ? _settingsItems : _organizeItems;
  if (settings && !access.isHostOrAdmin) return const [];
  return source
      .where(
        (item) => item.permission == null || access.allows(item.permission!),
      )
      .toList(growable: false);
}

final _organizeItems = <_MenuItem>[
  _MenuItem(
    'teams',
    AppIcons.users,
    (l) => l.tournamentManageTeams,
    permission: TournamentPermission.participants,
  ),
  _MenuItem(
    'players',
    AppIcons.user,
    (l) => l.tournamentManagePlayers,
    permission: TournamentPermission.participants,
  ),
  _MenuItem(
    'categories',
    AppIcons.grid,
    (l) => l.tournamentManageCategories,
    permission: TournamentPermission.structure,
  ),
  _MenuItem(
    'format',
    AppIcons.settings,
    (l) => l.tournamentManageFormat,
    permission: TournamentPermission.structure,
  ),
  _MenuItem(
    'standings',
    AppIcons.trendingUp,
    (l) => l.tournamentManageStandings,
    permission: TournamentPermission.structure,
  ),
  _MenuItem(
    'rounds',
    AppIcons.repeat,
    (l) => l.tournamentManageRounds,
    permission: TournamentPermission.structure,
  ),
  _MenuItem(
    'venues',
    AppIcons.location,
    (l) => l.tournamentManageVenues,
    permission: TournamentPermission.schedule,
  ),
  _MenuItem(
    'schedule',
    AppIcons.calendar,
    (l) => l.tournamentManageSchedule,
    permission: TournamentPermission.schedule,
  ),
  _MenuItem(
    'umpires',
    AppIcons.shieldCheck,
    (l) => l.tournamentManageUmpires,
    permission: TournamentPermission.schedule,
  ),
  _MenuItem(
    'results',
    AppIcons.trophy,
    (l) => l.tournamentManageResults,
    permission: TournamentPermission.results,
  ),
  _MenuItem(
    'sponsors',
    AppIcons.favorite,
    (l) => l.tournamentManageSponsors,
    permission: TournamentPermission.structure,
  ),
];

final _settingsItems = <_MenuItem>[
  _MenuItem('status', AppIcons.playCircle, (l) => l.tournamentManageStatus),
  _MenuItem('managers', AppIcons.shield, (l) => l.tournamentManageManagers),
  _MenuItem('name', AppIcons.edit, (l) => l.tournamentManageName),
  _MenuItem('dates', AppIcons.calendar, (l) => l.tournamentManageDates),
  _MenuItem('visibility', AppIcons.eye, (l) => l.tournamentManageVisibility),
  _MenuItem('banner', AppIcons.image, (l) => l.tournamentManageBanner),
  _MenuItem('videos', AppIcons.play, (l) => l.tournamentManageVideos),
  _MenuItem('contact', AppIcons.phone, (l) => l.tournamentManageContact),
  _MenuItem('duplicate', AppIcons.copy, (l) => l.tournamentManageDuplicate),
  _MenuItem('delete', AppIcons.delete, (l) => l.tournamentManageDelete),
];

const _settingsOptions = {
  'status',
  'managers',
  'name',
  'dates',
  'visibility',
  'banner',
  'videos',
  'contact',
  'duplicate',
  'delete',
};

String? normalizeTournamentManageOption(String? option) => switch (option) {
  'location' => 'venues',
  'registration' => 'teams',
  '' => null,
  _ => option,
};
