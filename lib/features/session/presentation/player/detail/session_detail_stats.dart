import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_player_detail_sheet.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/skill_level_badge.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Roster, capacity facts and the accepted skill band.
///
/// The structure follows the web detail page: players are a visual roster,
/// while the two-column facts below answer the practical questions about the
/// session at a glance.
class SessionDetailStats extends StatelessWidget {
  const SessionDetailStats({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!session.isCrawled) ...[
          _Participants(session: session),
          Divider(height: AppSpacing.lg, color: palette.border),
        ],
        _FactGrid(session: session),
        const SizedBox(height: AppSpacing.md),
        _LevelRow(requiredLevels: session.requiredLevels),
      ],
    );
  }
}

class _Participants extends StatefulWidget {
  const _Participants({required this.session});

  final Session session;

  @override
  State<_Participants> createState() => _ParticipantsState();
}

class _ParticipantsState extends State<_Participants> {
  static const _maxVisibleSlots = 10;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final players = widget.session.approvedPlayers;
    final capacity = widget.session.capacity;
    final availableSlots = capacity > players.length
        ? capacity - players.length
        : 0;
    final totalSlots = players.length + availableSlots;
    final hasMore = totalSlots > _maxVisibleSlots;

    final visiblePlayers = _expanded
        ? players
        : players.take(_maxVisibleSlots).toList();
    final visibleEmptySlots = _expanded
        ? availableSlots
        : availableSlots.clamp(
            0,
            (_maxVisibleSlots - visiblePlayers.length).clamp(0, 999),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(AppIcons.clubs, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.sessionParticipantsQuestion,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${players.length}/${capacity > 0 ? capacity : players.length}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              l10n.sessionNoPlayersYet,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final player in visiblePlayers)
                _PlayerAvatarTile(player: player),
              for (var i = 0; i < visibleEmptySlots; i++)
                _EmptySlotTile(key: ValueKey('empty-slot-$i')),
            ],
          ),
          if (hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? l10n.sessionShowLess : l10n.sessionViewAllPlayers,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PlayerAvatarTile extends StatelessWidget {
  const _PlayerAvatarTile({required this.player});

  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = l10n.playerName(player);
    final level = player.level;

    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => unawaited(
          showSessionPlayerDetailSheet(context, player: player),
        ),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: UserAvatar(
                      name: name,
                      gender: player.gender?.name,
                      status: player.status.name,
                      imageUrl: player.userImage,
                      size: 40,
                      borderWidth: 0,
                      boxShadow: const [],
                    ),
                  ),
                  if (level != null)
                    Positioned(
                      top: -5,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 1,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: theme.colorScheme.surface,
                          ),
                        ),
                        child: Text(
                          levelShortLabel(level) ?? '$level',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlotTile extends StatelessWidget {
  const _EmptySlotTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            foregroundPainter: _DashedCirclePainter(
              color: palette.border,
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                AppIcons.add,
                size: 18,
                color: palette.mutedForeground.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.sessionEmptySlot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Courts, capacity, registrations and shuttlecock, two per row.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approved = session.approvedPlayers;
    final male = approved.where((p) => p.gender == Gender.male).length;
    final female = approved.where((p) => p.gender == Gender.female).length;
    final courtNumbers = session.orderedCourts
        .map((court) => court.courtNumber)
        .join(', ');

    final facts = <Widget>[
      if (!session.isCrawled)
        _Fact(
          icon: AppIcons.grid,
          label: l10n.sessionCourtCount(session.numberOfCourts),
          suffix: courtNumbers.isEmpty ? null : '($courtNumbers)',
        ),
      if (!session.isCrawled && session.capacity > 0)
        _Fact(
          icon: AppIcons.clubs,
          label: l10n.sessionMaxPlayers(session.capacity),
        ),
      if (!session.isCrawled)
        _Fact(
          icon: AppIcons.userCheck,
          label: l10n.sessionRegisteredCount(session.playerCount),
          detail: male > 0 || female > 0
              ? _GenderBreakdown(male: male, female: female)
              : null,
        ),
      if (session.shuttlecock case final brand? when brand.trim().isNotEmpty)
        _Fact(
          icon: AppIcons.sessions,
          label: l10n.sessionShuttlecock(brand.trim()),
        ),
      if (session.clubId case final clubId? when clubId.isNotEmpty)
        _ManagedClubFact(clubId: clubId),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 340;
        const gap = AppSpacing.sm + 4;
        final width = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.sm + 4,
          children: [
            for (final fact in facts) SizedBox(width: width, child: fact),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    this.suffix,
    this.detail,
    this.onTap,
    this.hideLabel = false,
  });

  final IconData icon;
  final String label;
  final String? suffix;
  final Widget? detail;
  final VoidCallback? onTap;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideLabel)
                Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (suffix != null)
                        TextSpan(
                          text: ' $suffix',
                          style: TextStyle(color: palette.mutedForeground),
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              if (detail case final detail?)
                Padding(
                  padding: EdgeInsets.only(top: hideLabel ? 0 : 2),
                  child: detail,
                ),
            ],
          ),
        ),
      ],
    );
    return onTap == null
        ? content
        : InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: content,
          );
  }
}

class _GenderBreakdown extends StatelessWidget {
  const _GenderBreakdown({required this.male, required this.female});

  final int male;
  final int female;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (male > 0)
          _GenderCount(
            icon: AppIcons.male,
            count: male,
            label: l10n.genderMale,
            color: const Color(0xFF2563EB),
          ),
        if (female > 0)
          _GenderCount(
            icon: AppIcons.female,
            count: female,
            label: l10n.genderFemale,
            color: const Color(0xFFEC4899),
          ),
      ],
    );
  }
}

class _GenderCount extends StatelessWidget {
  const _GenderCount({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 3),
      Text(
        '$count $label',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ],
  );
}

class _ManagedClubFact extends ConsumerWidget {
  const _ManagedClubFact({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final club = ref.watch(clubDetailProvider(clubId));
    return club.when(
      loading: () => _Fact(
        icon: AppIcons.building,
        label: '',
        detail: Text('...', style: theme.textTheme.bodySmall),
        hideLabel: true,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (club) => _Fact(
        icon: AppIcons.building,
        label: '',
        detail: Text(
          club.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        hideLabel: true,
        onTap: () => context.push(AppRoutes.clubDetail(club.slug ?? club.id)),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.requiredLevels});

  final List<int> requiredLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final levels = sortByRank(requiredLevels.toSet());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.shield,
          size: 22,
          color: levels.isEmpty
              ? palette.mutedForeground
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: levels.isEmpty
                ? [
                    AllSkillLevelsBadge(label: l10n.sessionAllLevels),
                  ]
                : [
                    for (final level in levels)
                      if (levelShortLabel(level) != null)
                        SkillLevelBadge(level: level),
                  ],
          ),
        ),
        IconButton(
          tooltip: l10n.levelDescriptionsTitle,
          icon: const Icon(AppIcons.info, size: 18),
          visualDensity: VisualDensity.compact,
          color: theme.colorScheme.primary,
          onPressed: () => unawaited(showLevelDescriptions(context)),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashLength = .17;
    const gapLength = .11;
    var angle = 0.0;
    while (angle < 6.283185307179586) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dashLength,
        false,
        paint,
      );
      angle += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
