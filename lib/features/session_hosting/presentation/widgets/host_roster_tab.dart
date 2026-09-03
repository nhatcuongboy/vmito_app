import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_add_players_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_edit_player_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_search_field.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_detail_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The host-facing version of the web `SessionPlayersTab`.
///
/// Pending registrations stay above the roster, while the roster itself is
/// searchable, filterable and can switch between a dense grid and a list.
class HostRosterTab extends ConsumerStatefulWidget {
  const HostRosterTab({required this.session, super.key});

  final Session session;

  @override
  ConsumerState<HostRosterTab> createState() => _HostRosterTabState();
}

class _HostRosterTabState extends ConsumerState<HostRosterTab> {
  String _query = '';
  Set<PlayerStatus> _filters = const {};

  List<SessionPlayer> get _approved =>
      widget.session.players
          .where((player) => !player.isPendingApproval)
          .toList()
        ..sort((a, b) => (a.playerNumber ?? 0).compareTo(b.playerNumber ?? 0));

  List<SessionPlayer> get _filteredPlayers => _approved
      .where((player) {
        final normalized = _query.trim().toLowerCase();
        final matchesSearch =
            normalized.isEmpty ||
            (player.name ?? '').toLowerCase().contains(normalized) ||
            (player.phone ?? '').toLowerCase().contains(normalized) ||
            '${player.playerNumber ?? ''}'.contains(normalized);
        return matchesSearch &&
            (_filters.isEmpty || _filters.contains(player.status));
      })
      .toList(growable: false);

  int get _capacity =>
      widget.session.numberOfCourts * widget.session.maxPlayersPerCourt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(widget.session.id).notifier,
    );
    final pending = widget.session.pendingPlayers.isNotEmpty
        ? widget.session.pendingPlayers
        : widget.session.players
              .where((player) => player.isPendingApproval)
              .toList();
    final counts = <PlayerStatus, int>{
      for (final status in PlayerStatus.values)
        status: _approved.where((player) => player.status == status).length,
    };

    return RefreshIndicator(
      onRefresh: () =>
          ref.refresh(sessionDetailProvider(widget.session.id).future),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 600;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            children: [
              if (pending.isNotEmpty) ...[
                Text(
                  l10n.hostManagePendingApprovals,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final player in pending)
                  _PendingPlayerCard(
                    player: player,
                    onApprove: () => unawaited(
                      controller.updateRegistration(player.id, approved: true),
                    ),
                    onReject: () => unawaited(
                      controller.updateRegistration(player.id, approved: false),
                    ),
                  ),
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: PlayerSearchField(
                        compact: false,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: OutlinedButton(
                      key: const Key('host-roster-filter'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        side: BorderSide(
                          color: _filters.isNotEmpty
                              ? Theme.of(context).colorScheme.primary
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: .3)
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      onPressed: () => _showFilters(context, counts),
                      child: Badge(
                        isLabelVisible: _filters.isNotEmpty,
                        label: Text('${_filters.length}'),
                        child: const Icon(AppIcons.filter, size: 19),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '${_approved.length}/$_capacity người',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('host-roster-add'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    onPressed: () => _addPlayer(context),
                    icon: const Icon(AppIcons.add, size: 18),
                    label: Text(l10n.hostRosterAdd),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_filteredPlayers.isEmpty)
                _RosterEmpty(
                  isFiltered: _query.isNotEmpty || _filters.isNotEmpty,
                )
              else
                _RosterListGrid(
                  players: _filteredPlayers,
                  maxWidth: constraints.maxWidth,
                  onAction: _playerAction,
                  onOpenDetail: _openDetail,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addPlayer(BuildContext context) async {
    final added = await showHostAddPlayersSheet(
      context,
      session: widget.session,
    );
    if (added == true) ref.invalidate(sessionDetailProvider(widget.session.id));
  }

  Future<void> _showFilters(
    BuildContext context,
    Map<PlayerStatus, int> counts,
  ) async {
    final selected = await showModalBottomSheet<Set<PlayerStatus>>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _StatusFilterSheet(selected: _filters, counts: counts),
    );
    if (selected != null && mounted) setState(() => _filters = selected);
  }

  Future<void> _playerAction(SessionPlayer player, _RosterAction action) async {
    final controller = ref.read(
      hostSessionManagementControllerProvider(widget.session.id).notifier,
    );
    if (action == _RosterAction.view) {
      await _openDetail(player);
    } else if (action == _RosterAction.edit) {
      await _editPlayer(player);
    } else if (action == _RosterAction.toggleCheckIn) {
      await controller.toggleCheckIn(player.id);
    } else {
      final remove = await showAppConfirmDialog(
        context,
        type: AppConfirmDialogType.destructive,
        title: AppLocalizations.of(context).hostRosterDeleteTitle,
        content: AppLocalizations.of(context).hostRosterDeleteMessage(
          player.displayName ??
              AppLocalizations.of(context).playerName(player),
        ),
        confirmLabel: AppLocalizations.of(context).hostRosterDeletePlayer,
      );
      if (remove == true && mounted) await controller.removePlayer(player.id);
    }
  }

  Future<void> _openDetail(SessionPlayer player) => showHostPlayerDetailSheet(
    context,
    sessionId: widget.session.id,
    playerId: player.id,
  );

  Future<void> _editPlayer(SessionPlayer player) => showHostEditPlayerSheet(
    context,
    session: widget.session,
    player: player,
  );
}

class _PendingPlayerCard extends StatelessWidget {
  const _PendingPlayerCard({
    required this.player,
    required this.onApprove,
    required this.onReject,
  });
  final SessionPlayer player;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(AppIcons.userPlus)),
      title: Text(
        player.displayName ?? AppLocalizations.of(context).playerName(player),
      ),
      subtitle: player.phone == null
          ? Text(AppLocalizations.of(context).hostRosterPending)
          : Text(
              '${player.phone} · ${AppLocalizations.of(context).hostRosterPending}',
            ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).hostRosterReject,
            onPressed: onReject,
            icon: const Icon(AppIcons.close),
          ),
          IconButton.filled(
            tooltip: AppLocalizations.of(context).hostRosterApprove,
            onPressed: onApprove,
            icon: const Icon(AppIcons.check),
          ),
        ],
      ),
    ),
  );
}

/// Uses two compact cards per row for the host roster and adds a third column
/// only when the available width can keep each card comfortably readable.
class _RosterListGrid extends StatelessWidget {
  const _RosterListGrid({
    required this.players,
    required this.maxWidth,
    required this.onAction,
    required this.onOpenDetail,
  });

  final List<SessionPlayer> players;
  final double maxWidth;
  final void Function(SessionPlayer, _RosterAction) onAction;
  final ValueChanged<SessionPlayer> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final columns = (maxWidth / 340).floor().clamp(2, 3);
    const spacing = AppSpacing.sm;
    final itemWidth = (maxWidth - spacing * (columns - 1)) / columns;
    final itemHeight = itemWidth < 240 ? 114.0 : 100.0;
    return GridView.builder(
      key: const Key('host-roster-list-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: itemHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemBuilder: (context, index) => _RosterListTile(
        player: players[index],
        onAction: (action) => onAction(players[index], action),
        onOpenDetail: () => onOpenDetail(players[index]),
      ),
    );
  }
}

class _RosterListTile extends StatelessWidget {
  const _RosterListTile({
    required this.player,
    required this.onAction,
    required this.onOpenDetail,
  });
  final SessionPlayer player;
  final ValueChanged<_RosterAction> onAction;
  final VoidCallback onOpenDetail;
  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(player.status, Theme.of(context).brightness);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      key: ValueKey('host-roster-player-${player.id}'),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: dark
          ? scheme.surface
          : Color.alphaBlend(
              colors.background.withValues(alpha: .35),
              const Color(0xFFF8FAFC),
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: dark
              ? scheme.outlineVariant.withValues(alpha: .3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: onOpenDetail,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              key: ValueKey('host-roster-status-${player.id}'),
              color: colors.border,
              child: const SizedBox(width: 6),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        4,
                        AppSpacing.xxs,
                        4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _PlayerAvatar(
                            player: player,
                            statusColor: colors.dot,
                            radius: 19,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              key: ValueKey(
                                'host-roster-name-${player.id}',
                              ),
                              player.displayName ?? l10n.playerName(player),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.2,
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: _ActionMenu(
                              player: player,
                              onAction: onAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dark
                        ? scheme.outlineVariant.withValues(alpha: .2)
                        : const Color(0xFFF1F5F9),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    color: dark
                        ? scheme.surfaceContainerLow
                        : Color.alphaBlend(
                            colors.border.withValues(alpha: .08),
                            const Color(0xFFF1F5F9).withValues(alpha: .6),
                          ),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _NumberBadge(
                          number: player.playerNumber,
                          compact: true,
                        ),
                        _LevelBadge(
                          key: ValueKey('host-roster-level-${player.id}'),
                          label: _levelLabel(l10n, player.level),
                        ),
                        _GenderBadge(
                          key: ValueKey('host-roster-gender-${player.id}'),
                          gender: player.gender,
                        ),
                        if (player.isClubMember &&
                            player.clubName?.isNotEmpty == true)
                          _ClubBadge(
                            key: ValueKey('host-roster-club-${player.id}'),
                            label: player.clubName!,
                          ),
                        Text(
                          l10n.playerMatchesCount(player.matchesPlayed),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.player,
    required this.statusColor,
    this.radius = 19,
  });

  final SessionPlayer player;
  final Color statusColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = player.userImage?.isNotEmpty == true;
    final initials = _playerInitials(player.displayName ?? player.name);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasImage ? null : const Color(0xFF3B82F6),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: hasImage
                ? Image.network(
                    player.userImage!,
                    fit: BoxFit.cover,
                    width: radius * 2,
                    height: radius * 2,
                    errorBuilder: (_, __, ___) =>
                        _InitialsFallback(initials: initials),
                  )
                : _InitialsFallback(initials: initials),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3B82F6),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          height: 1,
        ),
      ),
    );
  }
}

String _playerInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  final first = parts.first.characters.first.toUpperCase();
  final last = parts.last.characters.first.toUpperCase();
  return '$first$last';
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.player, required this.onAction});
  final SessionPlayer player;
  final ValueChanged<_RosterAction> onAction;
  @override
  Widget build(BuildContext context) => PopupMenuButton<_RosterAction>(
    key: ValueKey('host-roster-actions-${player.id}'),
    tooltip: AppLocalizations.of(context).hostRosterActions,
    padding: EdgeInsets.zero,
    offset: const Offset(0, 40),
    icon: const Icon(AppIcons.moreVert, size: 20),
    onSelected: onAction,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _RosterAction.view,
        child: Text(AppLocalizations.of(context).hostRosterViewPlayer),
      ),
      PopupMenuItem(
        value: _RosterAction.edit,
        child: Text(AppLocalizations.of(context).hostRosterEditPlayer),
      ),
      PopupMenuItem(
        value: _RosterAction.toggleCheckIn,
        enabled: !player.isOnCourt,
        child: Text(
          player.status == PlayerStatus.inactive
              ? AppLocalizations.of(context).hostRosterContinuePlayer
              : AppLocalizations.of(context).hostRosterPausePlayer,
        ),
      ),
      PopupMenuItem(
        value: _RosterAction.remove,
        enabled: !player.isOnCourt,
        child: Text(AppLocalizations.of(context).hostRosterDeletePlayer),
      ),
    ],
  );
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, this.compact = false});
  final int? number;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fg = dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '#${number ?? '–'}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : null,
        ),
      ),
    );
  }
}

class _ClubBadge extends StatelessWidget {
  const _ClubBadge({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
    final fg = dark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final border = dark ? const Color(0xFF312E81) : const Color(0xFFC7D2FE);

    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final border = dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender, super.key});
  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (bg, border, fg, icon) = switch (gender) {
      Gender.male => (
        dark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
        dark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
        dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
        AppIcons.male,
      ),
      Gender.female => (
        dark ? const Color(0xFF4C0519) : const Color(0xFFFDF2F8),
        dark ? const Color(0xFF9D174D) : const Color(0xFFFBCFE8),
        dark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
        AppIcons.female,
      ),
      _ => (
        dark ? const Color(0xFF2E1065) : const Color(0xFFFAF5FF),
        dark ? const Color(0xFF581C87) : const Color(0xFFE9D5FF),
        dark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
        AppIcons.user,
      ),
    };

    final label = switch (gender) {
      Gender.male => l10n.genderMale,
      Gender.female => l10n.genderFemale,
      _ => l10n.genderOther,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterEmpty extends StatelessWidget {
  const _RosterEmpty({required this.isFiltered});
  final bool isFiltered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(
          isFiltered ? AppIcons.searchOff : AppIcons.clubs,
          size: 44,
        ),
        const SizedBox(height: 10),
        Text(
          isFiltered
              ? AppLocalizations.of(context).hostRosterEmptyFiltered
              : AppLocalizations.of(context).hostRosterEmpty,
        ),
      ],
    ),
  );
}

class _StatusFilterSheet extends StatefulWidget {
  const _StatusFilterSheet({required this.selected, required this.counts});
  final Set<PlayerStatus> selected;
  final Map<PlayerStatus, int> counts;
  @override
  State<_StatusFilterSheet> createState() => _StatusFilterSheetState();
}

class _StatusFilterSheetState extends State<_StatusFilterSheet> {
  late Set<PlayerStatus> _selected = {...widget.selected};
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).hostRosterFilterTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final status in PlayerStatus.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(status),
              onChanged: (_) => setState(
                () => _selected.contains(status)
                    ? _selected.remove(status)
                    : _selected.add(status),
              ),
              title: Text(_statusLabel(AppLocalizations.of(context), status)),
              secondary: Text('${widget.counts[status] ?? 0}'),
            ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: Text(AppLocalizations.of(context).hostRosterClearFilter),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(AppLocalizations.of(context).hostRosterApplyFilter),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _statusLabel(AppLocalizations l10n, PlayerStatus status) =>
    switch (status) {
      PlayerStatus.waiting => l10n.hostPlayerDetailStatusWaiting,
      PlayerStatus.playing => l10n.hostPlayerDetailStatusPlaying,
      PlayerStatus.ready => l10n.hostPlayerDetailStatusReady,
      PlayerStatus.inactive => l10n.hostPlayerDetailStatusInactive,
      PlayerStatus.finished => l10n.hostPlayerDetailStatusFinished,
    };

String _levelLabel(AppLocalizations l10n, int? level) => level == null
    ? l10n.hostRosterUnranked
    : levelShortLabel(level) ?? '$level';

enum _RosterAction { view, edit, toggleCheckIn, remove }

({Color background, Color border, Color foreground, Color dot}) _statusColors(
  PlayerStatus status,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  return switch (status) {
    PlayerStatus.playing => (
      background: dark ? const Color(0xFF132A1C) : const Color(0xFFF0FDF4),
      border: dark ? const Color(0xFF22C55E) : const Color(0xFF86EFAC),
      foreground: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
      dot: const Color(0xFF22C55E),
    ),
    PlayerStatus.ready => (
      background: dark ? const Color(0xFF2A2410) : const Color(0xFFFEFCE8),
      border: dark ? const Color(0xFFEAB308) : const Color(0xFFFDE047),
      foreground: dark ? const Color(0xFFFACC15) : const Color(0xFFCA8A04),
      dot: const Color(0xFFEAB308),
    ),
    PlayerStatus.waiting => (
      background: dark ? const Color(0xFF2A1C10) : const Color(0xFFFFF7ED),
      border: dark ? const Color(0xFFF97316) : const Color(0xFFFDBA74),
      foreground: dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
      dot: const Color(0xFFF97316),
    ),
    PlayerStatus.inactive => (
      background: dark ? const Color(0xFF1E2124) : const Color(0xFFF9FAFB),
      border: dark ? const Color(0xFF9CA3AF) : const Color(0xFFE2E8F0),
      foreground: dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
      dot: const Color(0xFF9CA3AF),
    ),
    PlayerStatus.finished => (
      background: dark ? const Color(0xFF1B2230) : const Color(0xFFF8FAFC),
      border: dark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
      foreground: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      dot: const Color(0xFF64748B),
    ),
  };
}
