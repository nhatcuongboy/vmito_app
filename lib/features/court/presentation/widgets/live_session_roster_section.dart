import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The player roster in `LiveSessionOverviewTab`'s "Tổng quan" tab.
///
/// A denser, read-only counterpart to `HostRosterTab`'s management grid: no
/// search/filter/actions, just enough at-a-glance context (level, gender,
/// matches played, current wait) for a player to see who else is around.
/// Ports `OverviewPlayerTable.tsx`'s number/name/level/status table, redesigned
/// as cards — a plain table reads poorly at phone width.
class LiveSessionRosterSection extends StatelessWidget {
  const LiveSessionRosterSection({
    required this.roster,
    required this.currentPlayerId,
    super.key,
  });

  final List<SessionPlayer> roster;
  final String currentPlayerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.users, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(l10n.playerLiveRoster, style: theme.textTheme.titleMedium),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '(${roster.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final player in roster) ...[
          _RosterTile(player: player, isMe: player.id == currentPlayerId),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.player, required this.isMe});
  final SessionPlayer player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final status = _statusStyle(player.status, dark);
    final showWait =
        player.status == PlayerStatus.waiting ||
        player.status == PlayerStatus.ready;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isMe
            ? theme.colorScheme.primary.withValues(alpha: dark ? 0.16 : 0.07)
            : (dark ? theme.colorScheme.surfaceContainerLow : Colors.white),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.55)
              : (dark
                    ? theme.colorScheme.outlineVariant.withValues(alpha: .3)
                    : const Color(0xFFE2E8F0)),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(player: player, dotColor: status.dot),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.displayName ?? l10n.playerName(player),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      _YouBadge(label: l10n.leaderboardYou),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaText(text: '#${player.playerNumber ?? '–'}'),
                    if (player.gender != null)
                      _MetaText(
                        icon: genderIcon(player.gender),
                        text: switch (player.gender!) {
                          Gender.male => l10n.genderMale,
                          Gender.female => l10n.genderFemale,
                          Gender.other => l10n.genderOther,
                        },
                      ),
                    _MetaText(
                      text: player.level == null
                          ? l10n.hostRosterUnranked
                          : levelShortLabel(player.level!) ?? '${player.level}',
                    ),
                    _MetaText(
                      icon: AppIcons.trophy,
                      text: l10n.playerMatchesCount(player.matchesPlayed),
                    ),
                    if (showWait)
                      _MetaText(
                        icon: AppIcons.clock,
                        text: l10n.playerLiveMinutes(player.currentWaitTime),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatusPill(label: _statusLabel(l10n, player.status), style: status),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.player, required this.dotColor});
  final SessionPlayer player;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final hasImage = player.userImage?.isNotEmpty == true;
    final initials = _initials(player.displayName ?? player.name);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF3B82F6),
          ),
          child: ClipOval(
            child: hasImage
                ? Image.network(
                    player.userImage!,
                    fit: BoxFit.cover,
                    width: radius * 2,
                    height: radius * 2,
                    errorBuilder: (_, _, _) => _initialsLabel(initials),
                  )
                : _initialsLabel(initials),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialsLabel(String initials) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );

  static String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _YouBadge extends StatelessWidget {
  const _YouBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
    ),
  );
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.style});
  final String label;
  final _StatusStyle style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: style.background,
      border: Border.all(color: style.border),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: style.foreground,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

String _statusLabel(AppLocalizations l10n, PlayerStatus status) =>
    switch (status) {
      PlayerStatus.playing => l10n.hostPlayerDetailStatusPlaying,
      PlayerStatus.ready => l10n.hostPlayerDetailStatusReady,
      PlayerStatus.waiting => l10n.hostPlayerDetailStatusWaiting,
      PlayerStatus.finished => l10n.hostPlayerDetailStatusFinished,
      PlayerStatus.inactive => l10n.hostPlayerDetailStatusInactive,
    };

typedef _StatusStyle = ({
  Color background,
  Color border,
  Color foreground,
  Color dot,
});

_StatusStyle _statusStyle(PlayerStatus status, bool dark) => switch (status) {
  PlayerStatus.playing => (
    background: dark ? const Color(0xFF132A1C) : const Color(0xFFF0FDF4),
    border: dark ? const Color(0xFF22C55E) : const Color(0xFF86EFAC),
    foreground: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
    dot: const Color(0xFF22C55E),
  ),
  PlayerStatus.ready => (
    background: dark ? const Color(0xFF17264A) : const Color(0xFFEFF6FF),
    border: dark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
    foreground: dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
    dot: const Color(0xFF3B82F6),
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
