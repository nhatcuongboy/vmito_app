import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_form_sheet.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_stats_sheet.dart';
import 'package:vmito_app/features/roster/presentation/widgets/promote_player_dialog.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

enum _MemberFilter { all, members, guests }

class ClubMembersTab extends ConsumerStatefulWidget {
  const ClubMembersTab({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<ClubMembersTab> createState() => _ClubMembersTabState();
}

class _ClubMembersTabState extends ConsumerState<ClubMembersTab> {
  _MemberFilter _filter = _MemberFilter.all;

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(clubMembersProvider(widget.clubId).future),
      ref.refresh(clubRosterProvider(widget.clubId).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));
    final guestsAsync = ref.watch(clubRosterProvider(widget.clubId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: Key('club-members-add-fab-${widget.clubId}'),
        heroTag: 'club-members-add-fab-${widget.clubId}',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AddMemberDialog(clubId: widget.clubId),
        ),
        icon: const Icon(AppIcons.userPlus),
        label: Text(l10n.clubAddMember),
      ),
      body: membersAsync.when(
        data: (members) => guestsAsync.when(
          data: (guests) => _buildContent(
            context,
            l10n: l10n,
            members: members,
            guests: guests,
          ),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(clubRosterProvider(widget.clubId)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubMembersProvider(widget.clubId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required AppLocalizations l10n,
    required List<ClubMember> members,
    required List<PlayerProfile> guests,
  }) {
    final totalCount = members.length + guests.length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  key: const Key('club-members-filter-all'),
                  label: Text('${l10n.commonAll} ($totalCount)'),
                  selected: _filter == _MemberFilter.all,
                  onSelected: (_) =>
                      setState(() => _filter = _MemberFilter.all),
                ),
                ChoiceChip(
                  key: const Key('club-members-filter-members'),
                  label: Text('${l10n.clubMembers} (${members.length})'),
                  selected: _filter == _MemberFilter.members,
                  onSelected: (_) =>
                      setState(() => _filter = _MemberFilter.members),
                ),
                ChoiceChip(
                  key: const Key('club-members-filter-guests'),
                  label: Text('${l10n.clubGuestsTabTitle} (${guests.length})'),
                  selected: _filter == _MemberFilter.guests,
                  onSelected: (_) =>
                      setState(() => _filter = _MemberFilter.guests),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildList(
              context,
              l10n: l10n,
              members: members,
              guests: guests,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context, {
    required AppLocalizations l10n,
    required List<ClubMember> members,
    required List<PlayerProfile> guests,
  }) {
    final theme = Theme.of(context);

    switch (_filter) {
      case _MemberFilter.all:
        if (members.isEmpty && guests.isEmpty) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: Center(child: Text(l10n.clubMembersEmpty)),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 96),
          children: [
            if (members.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${l10n.clubMembers} (${members.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final member in members)
                _MemberTile(clubId: widget.clubId, member: member),
            ],
            if (guests.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${l10n.clubGuestsTabTitle} (${guests.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final guest in guests)
                _GuestTile(clubId: widget.clubId, guest: guest),
            ],
          ],
        );

      case _MemberFilter.members:
        if (members.isEmpty) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: Center(child: Text(l10n.clubMembersEmpty)),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 96),
          itemCount: members.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _MemberTile(clubId: widget.clubId, member: members[index]),
        );

      case _MemberFilter.guests:
        if (guests.isEmpty) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: Center(
                  child: Text(
                    l10n.clubGuestsEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 96),
          itemCount: guests.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _GuestTile(clubId: widget.clubId, guest: guests[index]),
        );
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.clubId, required this.member});

  final String clubId;
  final ClubMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: UserAvatar(
        name: member.name,
        imageUrl: member.image,
        gender: member.gender,
        size: 40,
      ),
      title: Text(member.name),
      subtitle: Text('${member.email}\n${_roleLabel(l10n, member.role)}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'remove') {
            await _remove(context, ref);
          } else {
            await ref
                .read(clubManagementControllerProvider.notifier)
                .updateMemberRole(clubId, member.userId, value);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'ADMIN', child: Text(l10n.clubRoleAdmin)),
          PopupMenuItem(
            value: 'MODERATOR',
            child: Text(l10n.clubRoleModerator),
          ),
          PopupMenuItem(value: 'MEMBER', child: Text(l10n.clubRoleMember)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'remove', child: Text(l10n.commonRemove)),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) => switch (role) {
    'ADMIN' => l10n.clubRoleAdmin,
    'MODERATOR' => 'Mod',
    _ => l10n.clubRoleMember,
  };

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubRemoveMember,
      content: l10n.clubRemoveMemberConfirm(member.name),
      confirmLabel: l10n.commonRemove,
    );
    if (confirmed == true) {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .removeMember(clubId, member.userId);
    }
  }
}

class _GuestTile extends ConsumerWidget {
  const _GuestTile({required this.clubId, required this.guest});

  final String clubId;
  final PlayerProfile guest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phone = guest.phone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;

    return ListTile(
      leading: UserAvatar(
        name: guest.name,
        gender: switch (guest.gender) {
          Gender.male => 'MALE',
          Gender.female => 'FEMALE',
          Gender.other => 'OTHER',
          null => null,
        },
        size: 40,
      ),
      title: Text(guest.name),
      subtitle: Text(
        hasPhone
            ? '$phone\n${l10n.clubGuestsTabTitle}'
            : l10n.clubGuestsTabTitle,
      ),
      isThreeLine: hasPhone,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              final updated = await showPlayerProfileFormSheet(
                context,
                profile: guest,
                defaultClubId: clubId,
              );
              if (updated == true) {
                ref.invalidate(clubRosterProvider(clubId));
              }
            case 'promote':
              final result = await showPromotePlayerDialog(
                context,
                profile: guest,
              );
              if (result == true && context.mounted) {
                ref.invalidate(clubRosterProvider(clubId));
                ref.invalidate(clubMembersProvider(clubId));
              }
            case 'stats':
              unawaited(
                showPlayerProfileStatsSheet(context, profileId: guest.id),
              );
            case 'remove':
              final confirmed = await showAppConfirmDialog(
                context,
                type: AppConfirmDialogType.destructive,
                title: l10n.clubRemoveMember,
                content: l10n.clubRemoveMemberConfirm(guest.name),
                confirmLabel: l10n.commonRemove,
              );
              if (confirmed == true) {
                await ref
                    .read(rosterControllerProvider.notifier)
                    .deleteProfile(guest.id);
                ref.invalidate(clubRosterProvider(clubId));
              }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(AppIcons.edit, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.commonEdit),
              ],
            ),
          ),
          if (guest.isActive)
            PopupMenuItem(
              value: 'promote',
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_circle_up_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.rosterPromoteToUser),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'stats',
            child: Row(
              children: [
                const Icon(AppIcons.trendingUp, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.rosterViewStats),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(
                  AppIcons.delete,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.commonRemove,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _searchController = TextEditingController();
  List<ClubUserSearchResult> _results = const [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.clubAddMember),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('club-member-search'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                unawaited(_search());
              },
              decoration: InputDecoration(
                hintText: l10n.clubSearchUsers,
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : IconButton(
                        icon: const Icon(AppIcons.search),
                        onPressed: () {
                          _debounce?.cancel();
                          unawaited(_search());
                        },
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('club-add-guest-directly-button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: _addGuest,
              icon: const Icon(AppIcons.userPlus, size: 18),
              label: Text(l10n.clubAddGuestAction),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        _hasSearched
                            ? l10n.clubNoUsersFound
                            : l10n.clubSearchUsersHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        return ListTile(
                          leading: UserAvatar(
                            name: user.name,
                            imageUrl: user.image,
                            size: 36,
                          ),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          trailing: IconButton(
                            tooltip: l10n.clubAddMember,
                            onPressed: () => _add(user),
                            icon: const Icon(AppIcons.userPlus),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final results = await ref.read(
        clubUserSearchProvider((clubId: widget.clubId, query: query)).future,
      );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(ClubUserSearchResult user) async {
    await ref
        .read(clubManagementControllerProvider.notifier)
        .addMember(widget.clubId, user.id);
    if (mounted) {
      setState(
        () => _results = _results.where((item) => item.id != user.id).toList(),
      );
    }
  }

  Future<void> _addGuest() async {
    final added = await showPlayerProfileFormSheet(
      context,
      defaultClubId: widget.clubId,
      lockClubSelection: true,
    );
    if (added == true && mounted) {
      ref.invalidate(clubRosterProvider(widget.clubId));
      Navigator.of(context).pop();
    }
  }
}
