import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/roster/data/roster_service.dart';
import 'package:vmito_app/features/roster/domain/host_recent_player.dart';
import 'package:vmito_app/features/session/domain/host_player.dart';
import 'package:vmito_app/features/session_hosting/application/host_add_players_controller.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_full_height_modal.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';

class HostPickedPlayer {
  const HostPickedPlayer({
    required this.name,
    this.userId,
    this.profileId,
    this.clubId,
    this.gender,
    this.level,
    this.levelDescription,
    this.phone,
    this.isMonthlyMember = false,
  });

  final String name;
  final String? userId;
  final String? profileId;
  final String? clubId;
  final Gender? gender;
  final int? level;
  final String? levelDescription;
  final String? phone;
  final bool isMonthlyMember;
}

Future<List<HostPickedPlayer>?> showHostPlayerPickerSheet(
  BuildContext context, {
  required String sessionId,
  String? clubId,
  Set<String> existingProfileIds = const {},
  Set<String> existingUserIds = const {},
}) {
  return showAppFullHeightModal<List<HostPickedPlayer>>(
    context,
    builder: (context) => _HostPlayerPickerSheet(
      sessionId: sessionId,
      clubId: clubId,
      existingProfileIds: existingProfileIds,
      existingUserIds: existingUserIds,
    ),
  );
}

class _HostPlayerPickerSheet extends ConsumerStatefulWidget {
  const _HostPlayerPickerSheet({
    required this.sessionId,
    this.clubId,
    required this.existingProfileIds,
    required this.existingUserIds,
  });

  final String sessionId;
  final String? clubId;
  final Set<String> existingProfileIds;
  final Set<String> existingUserIds;

  @override
  ConsumerState<_HostPlayerPickerSheet> createState() =>
      _HostPlayerPickerSheetState();
}

class _HostPlayerPickerSheetState
    extends ConsumerState<_HostPlayerPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AppSheetHeader(
            key: const Key('host-player-picker-header'),
            closeButtonKey: const Key('host-player-picker-close'),
            title: l10n.hostAddPlayerSelectExisting,
            onClose: () => Navigator.pop(context),
          ),
          TabBar(
            tabs: [
              Tab(
                key: const Key('host-picker-tab-system'),
                text: l10n.hostAddPlayerSelectExisting,
              ),
              Tab(
                key: const Key('host-picker-tab-roster'),
                text: l10n.rosterPickFromRosterButton,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SystemUserPickerTab(
                  sessionId: widget.sessionId,
                  clubId: widget.clubId,
                  existingUserIds: widget.existingUserIds,
                ),
                _RosterPickerTab(
                  sessionId: widget.sessionId,
                  clubId: widget.clubId,
                  existingProfileIds: widget.existingProfileIds,
                  existingUserIds: widget.existingUserIds,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterPickerTab extends ConsumerStatefulWidget {
  const _RosterPickerTab({
    required this.sessionId,
    this.clubId,
    required this.existingProfileIds,
    required this.existingUserIds,
  });

  final String sessionId;
  final String? clubId;
  final Set<String> existingProfileIds;
  final Set<String> existingUserIds;

  @override
  ConsumerState<_RosterPickerTab> createState() => _RosterPickerTabState();
}

class _RosterPickerTabState extends ConsumerState<_RosterPickerTab> {
  final _searchController = TextEditingController();
  final Set<HostRecentPlayer> _selected = {};
  Timer? _debounce;
  List<HostRecentPlayer> _rawPlayers = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchPlayers(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayers(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(rosterServiceProvider)
          .getHostRecentPlayers(
            clubId: widget.clubId,
            search: query,
          );
      if (!mounted) return;
      setState(() {
        _rawPlayers = results;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_fetchPlayers(query));
    });
  }

  void _toggleSelection(HostRecentPlayer player) {
    setState(() {
      if (_selected.any((p) => p.profileId == player.profileId)) {
        _selected.removeWhere((p) => p.profileId == player.profileId);
      } else {
        _selected.add(player);
      }
    });
  }

  List<HostRecentPlayer> _sortPlayers(List<HostRecentPlayer> players) {
    final myClubs = ref.watch(myClubsProvider).asData?.value ?? const [];
    final managedClubs =
        ref.watch(managedClubsProvider).asData?.value ?? const [];
    final userClubIds = <String>{
      if (widget.clubId != null) widget.clubId!,
      for (final c in myClubs) c.id,
      for (final c in managedClubs) c.id,
    };

    int getPriority(HostRecentPlayer p) {
      if (widget.clubId != null && p.clubId == widget.clubId) return 0;
      if (p.clubId != null && userClubIds.contains(p.clubId)) return 1;
      if (p.isClubMember) return 2;
      return 3;
    }

    return [...players]..sort((a, b) {
      final prioA = getPriority(a);
      final prioB = getPriority(b);
      if (prioA != prioB) return prioA.compareTo(prioB);

      final dateA = a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCmp = dateB.compareTo(dateA);
      if (dateCmp != 0) return dateCmp;

      return b.totalSessions.compareTo(a.totalSessions);
    });
  }

  void _submit() {
    final hostState = ref.read(
      hostAddPlayersControllerProvider(widget.sessionId),
    );
    final result = _selected
        .map((player) {
          final isMonthly =
              player.userId != null &&
              hostState.monthlyMemberUserIds.contains(player.userId);
          return HostPickedPlayer(
            name: player.name,
            userId: player.userId,
            profileId: player.profileId,
            clubId: player.clubId,
            gender: player.gender,
            level: player.level,
            phone: player.phone,
            isMonthlyMember: isMonthly,
          );
        })
        .toList(growable: false);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sortedPlayers = _sortPlayers(_rawPlayers);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            key: const Key('host-roster-search-field'),
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.rosterSearchPlaceholder,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.errorUnknown,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () =>
                              _fetchPlayers(_searchController.text),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : sortedPlayers.isEmpty && !_loading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      l10n.rosterNoRecentPlayersFound,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: sortedPlayers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final player = sortedPlayers[index];
                    final isAlreadyInSession =
                        widget.existingProfileIds.contains(player.profileId) ||
                        (player.userId != null &&
                            widget.existingUserIds.contains(player.userId));
                    final isChecked = _selected.any(
                      (p) => p.profileId == player.profileId,
                    );

                    return CheckboxListTile(
                      key: ValueKey('roster-player-${player.profileId}'),
                      value: isChecked,
                      enabled: !isAlreadyInSession,
                      onChanged: isAlreadyInSession
                          ? null
                          : (_) => _toggleSelection(player),
                      secondary: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (player.gender != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(genderIcon(player.gender), size: 16),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (player.level != null) ...[
                                Text(
                                  l10n.levelName(player.level!),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Text(
                                '${player.totalSessions} sessions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (player.lastPlayedAt != null) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '• ${Dates.dateOnly(player.lastPlayedAt!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (isAlreadyInSession)
                            Text(
                              l10n.hostAddPlayerAlreadySelected,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            )
                          else if (player.club?.name != null)
                            Text(
                              '[${l10n.rosterGroupName(player.club!.name)}]',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              '[${l10n.rosterPersonalBadge}]',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        AppSheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('host-roster-add-button'),
                  onPressed: _selected.isEmpty ? null : _submit,
                  child: Text(
                    _selected.isEmpty
                        ? l10n.rosterAddToSessionAction
                        : '${l10n.rosterAddToSessionAction} (${_selected.length})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemUserPickerTab extends ConsumerStatefulWidget {
  const _SystemUserPickerTab({
    required this.sessionId,
    this.clubId,
    required this.existingUserIds,
  });

  final String sessionId;
  final String? clubId;
  final Set<String> existingUserIds;

  @override
  ConsumerState<_SystemUserPickerTab> createState() =>
      _SystemUserPickerTabState();
}

class _SystemUserPickerTabState extends ConsumerState<_SystemUserPickerTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(hostAddPlayersControllerProvider(widget.sessionId).notifier)
              .searchUsers(''),
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        ref
            .read(hostAddPlayersControllerProvider(widget.sessionId).notifier)
            .searchUsers(query),
      );
    });
  }

  void _selectUser(HostPlayerUserOption user) {
    final hostState = ref.read(
      hostAddPlayersControllerProvider(widget.sessionId),
    );
    final isMonthly = hostState.monthlyMemberUserIds.contains(user.id);
    Navigator.pop(
      context,
      [
        HostPickedPlayer(
          name: user.name,
          userId: user.id,
          gender: user.gender,
          level: user.level,
          levelDescription: user.levelDescription,
          isMonthlyMember: isMonthly,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(hostAddPlayersControllerProvider(widget.sessionId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            key: const Key('host-user-search-field'),
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.hostAddPlayerSearchExisting,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (state.loadingUsers) const LinearProgressIndicator(),
        Expanded(
          child: state.users.isEmpty && !state.loadingUsers
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      l10n.hostAddPlayerNoUsersFound,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: state.users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    final disabled = widget.existingUserIds.contains(user.id);
                    final isMonthly = state.monthlyMemberUserIds.contains(
                      user.id,
                    );

                    return ListTile(
                      key: ValueKey('system-user-${user.id}'),
                      enabled: !disabled,
                      leading: const CircleAvatar(
                        child: Icon(AppIcons.user),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.gender != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(genderIcon(user.gender), size: 16),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        disabled
                            ? l10n.hostAddPlayerAlreadySelected
                            : user.email,
                      ),
                      trailing: isMonthly
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.hostAddPlayerClubFee,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      onTap: disabled ? null : () => _selectUser(user),
                    );
                  },
                ),
        ),
        AppSheetActionBar(
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
          ),
        ),
      ],
    );
  }
}
