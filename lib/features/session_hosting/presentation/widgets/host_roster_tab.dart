import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/registration/presentation/register_session_sheet.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_search_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
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
  bool _grid = true;

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
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _RosterHeader(
              approvedCount: _approved.length,
              capacity: _capacity,
              onAdd: () => _addPlayer(context),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
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
            ],
            const SizedBox(height: AppSpacing.md),
            PlayerSearchField(
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('host-roster-filter'),
                  onPressed: () => _showFilters(context, counts),
                  icon: Badge(
                    isLabelVisible: _filters.isNotEmpty,
                    label: Text('${_filters.length}'),
                    child: const Icon(AppIcons.filter),
                  ),
                  label: Text(_filters.isEmpty ? 'Bộ lọc' : 'Đã lọc'),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(AppIcons.grid),
                      tooltip: 'Dạng lưới',
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(AppIcons.list),
                      tooltip: 'Dạng danh sách',
                    ),
                  ],
                  selected: {_grid},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _grid = value.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_filteredPlayers.isEmpty)
              _RosterEmpty(isFiltered: _query.isNotEmpty || _filters.isNotEmpty)
            else if (_grid)
              _RosterGrid(
                players: _filteredPlayers,
                maxWidth: constraints.maxWidth,
                onAction: _playerAction,
              )
            else
              for (final player in _filteredPlayers)
                _RosterListTile(
                  player: player,
                  onAction: (action) => _playerAction(player, action),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlayer(BuildContext context) async {
    final added = await showRegisterSessionSheet(
      context,
      session: widget.session,
      asGuest: true,
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
    if (action == _RosterAction.toggleCheckIn) {
      await controller.toggleCheckIn(player.id);
    } else {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa người chơi?'),
          content: Text(
            'Xóa ${player.displayName ?? 'người chơi này'} khỏi kèo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );
      if (remove == true && mounted) await controller.removePlayer(player.id);
    }
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.approvedCount,
    required this.capacity,
    required this.onAdd,
  });
  final int approvedCount;
  final int capacity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Người chơi ($approvedCount/$capacity)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      FilledButton.icon(
        key: const Key('host-roster-add'),
        onPressed: onAdd,
        icon: const Icon(AppIcons.add),
        label: const Text('Thêm người'),
      ),
    ],
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
      title: Text(player.displayName ?? 'Người chơi'),
      subtitle: player.phone == null
          ? const Text('Chờ duyệt')
          : Text('${player.phone} · Chờ duyệt'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Từ chối',
            onPressed: onReject,
            icon: const Icon(AppIcons.close),
          ),
          IconButton.filled(
            tooltip: 'Duyệt',
            onPressed: onApprove,
            icon: const Icon(AppIcons.check),
          ),
        ],
      ),
    ),
  );
}

class _RosterGrid extends StatelessWidget {
  const _RosterGrid({
    required this.players,
    required this.maxWidth,
    required this.onAction,
  });
  final List<SessionPlayer> players;
  final double maxWidth;
  final void Function(SessionPlayer, _RosterAction) onAction;

  @override
  Widget build(BuildContext context) {
    final columns = (maxWidth / 180).floor().clamp(2, 4);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 144,
      ),
      itemBuilder: (context, index) => _RosterPlayerCard(
        player: players[index],
        onAction: (action) => onAction(players[index], action),
      ),
    );
  }
}

class _RosterPlayerCard extends StatelessWidget {
  const _RosterPlayerCard({required this.player, required this.onAction});
  final SessionPlayer player;
  final ValueChanged<_RosterAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(player.status, Theme.of(context).brightness);
    final l10n = AppLocalizations.of(context);
    return Card(
      color: colors.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NumberBadge(number: player.playerNumber),
                const Spacer(),
                _ActionMenu(player: player, onAction: onAction),
              ],
            ),
            const Spacer(),
            Text(
              player.displayName ?? l10n.playerName(player),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _InfoChip(label: _levelLabel(player.level)),
                const SizedBox(width: 5),
                _GenderChip(gender: player.gender),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${player.matchesPlayed} trận',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: colors.foreground),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterListTile extends StatelessWidget {
  const _RosterListTile({required this.player, required this.onAction});
  final SessionPlayer player;
  final ValueChanged<_RosterAction> onAction;
  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(player.status, Theme.of(context).brightness);
    return Card(
      color: colors.background,
      child: ListTile(
        leading: _NumberBadge(number: player.playerNumber),
        title: Text(
          player.displayName ?? AppLocalizations.of(context).playerName(player),
        ),
        subtitle: Text(
          '${_levelLabel(player.level)} · ${player.matchesPlayed} trận',
        ),
        trailing: _ActionMenu(player: player, onAction: onAction),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.player, required this.onAction});
  final SessionPlayer player;
  final ValueChanged<_RosterAction> onAction;
  @override
  Widget build(BuildContext context) => PopupMenuButton<_RosterAction>(
    tooltip: 'Tác vụ người chơi',
    onSelected: onAction,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _RosterAction.toggleCheckIn,
        enabled: !player.isOnCourt,
        child: Text(
          player.status == PlayerStatus.inactive ? 'Check-in' : 'Check-out',
        ),
      ),
      PopupMenuItem(
        value: _RosterAction.remove,
        enabled: !player.isOnCourt,
        child: const Text('Xóa người chơi'),
      ),
    ],
  );
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});
  final int? number;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.tertiary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      '#${number ?? '–'}',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onTertiary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label),
  );
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.gender});
  final Gender? gender;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Icon(
      switch (gender) {
        Gender.female => AppIcons.user,
        Gender.other => AppIcons.profile,
        _ => AppIcons.user,
      },
      color: Theme.of(context).colorScheme.onPrimary,
      size: 16,
    ),
  );
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
              ? 'Không tìm thấy người chơi phù hợp.'
              : 'Chưa có người chơi.',
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
          Text('Lọc người chơi', style: Theme.of(context).textTheme.titleLarge),
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
              title: Text(_statusLabel(status)),
              secondary: Text('${widget.counts[status] ?? 0}'),
            ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: const Text('Xóa lọc'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _statusLabel(PlayerStatus status) => switch (status) {
  PlayerStatus.waiting => 'Chờ',
  PlayerStatus.playing => 'Đang chơi',
  PlayerStatus.ready => 'Sẵn sàng',
  PlayerStatus.inactive => 'Vắng mặt',
  PlayerStatus.finished => 'Kết thúc',
};

String _levelLabel(int? level) =>
    level == null ? 'Chưa xếp hạng' : levelShortLabel(level) ?? '$level';

enum _RosterAction { toggleCheckIn, remove }

({Color background, Color border, Color foreground}) _statusColors(
  PlayerStatus status,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  return switch (status) {
    PlayerStatus.playing => (
      background: dark ? const Color(0xFF1D5334) : const Color(0xFF8FE0A9),
      border: const Color(0xFF54B56F),
      foreground: const Color(0xFF31764A),
    ),
    PlayerStatus.ready => (
      background: dark ? const Color(0xFF5C5121) : const Color(0xFFFFD9A4),
      border: const Color(0xFFE2B06A),
      foreground: const Color(0xFF86601D),
    ),
    PlayerStatus.waiting => (
      background: dark ? const Color(0xFF5C3A1E) : const Color(0xFFFFD6A0),
      border: const Color(0xFFEBA456),
      foreground: const Color(0xFF945C1A),
    ),
    PlayerStatus.inactive => (
      background: dark ? const Color(0xFF404040) : const Color(0xFFE5E7EB),
      border: const Color(0xFF9CA3AF),
      foreground: const Color(0xFF6B7280),
    ),
    PlayerStatus.finished => (
      background: dark ? const Color(0xFF38465A) : const Color(0xFFDDE8F5),
      border: const Color(0xFF90A4BE),
      foreground: const Color(0xFF526B84),
    ),
  };
}
