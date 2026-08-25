import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_fee_detail_dialog.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_section.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Mobile port of the host web app's `SessionOverviewTab`.
class HostOverviewTab extends ConsumerWidget {
  const HostOverviewTab({
    required this.session,
    this.onEdit,
    super.key,
  });

  final Session session;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = session.approvedPlayers;
    final capacity = session.capacity;
    final waiting = players
        .where((player) => player.status == PlayerStatus.waiting)
        .length;
    final playing = players
        .where((player) => player.status == PlayerStatus.playing)
        .length;
    final ready = players
        .where((player) => player.status == PlayerStatus.ready)
        .length;
    final male = players.where((player) => player.gender == Gender.male).length;
    final female = players
        .where((player) => player.gender == Gender.female)
        .length;
    final images = session.galleryImages;

    final showStartButton = session.status == SessionStatus.preparing;
    final showEndButton = session.status == SessionStatus.inProgress;
    final showBottomBar = showStartButton || showEndButton;

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(sessionDetailProvider(session.id))
          ..invalidate(playerStatisticsProvider(session.id));
        await Future.wait([
          ref.read(sessionDetailProvider(session.id).future),
          ref.read(playerStatisticsProvider(session.id).future),
        ]);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _StatusBanner(session: session),
                  if (session.status == SessionStatus.cancelled)
                    const SizedBox(height: AppSpacing.md),
                  if (images.isNotEmpty) ...[
                    if (session.status != SessionStatus.cancelled)
                      const SizedBox(height: AppSpacing.md),
                    _SessionGallery(
                      images: images,
                      onShare: () => _share(context, session),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _InfoCard(session: session, onEdit: onEdit),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Thống kê kèo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatsGrid(
                    maxWidth: constraints.maxWidth,
                    players: players.length,
                    capacity: capacity,
                    male: male,
                    female: female,
                    waiting: waiting,
                    playing: playing,
                    ready: ready,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PlayerStatisticsSection(session: session),
                ],
              ),
            ),
          );

          if (!showBottomBar) return content;

          return Column(
            children: [
              Expanded(child: content),
              _SessionActionBar(
                sessionId: session.id,
                showStart: showStartButton,
                showEnd: showEndButton,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _share(BuildContext context, Session session) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${session.name}\nhttps://vmito.com/vi/sessions/${session.slug ?? session.id}',
      ),
    );
  }
}

class _SessionActionBar extends StatelessWidget {
  const _SessionActionBar({
    required this.sessionId,
    required this.showStart,
    required this.showEnd,
  });

  final String sessionId;
  final bool showStart;
  final bool showEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: showStart
                  ? _StartSessionButton(sessionId: sessionId)
                  : (showEnd
                      ? _EndSessionButton(sessionId: sessionId)
                      : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Start session button inside sticky action bar.
class _StartSessionButton extends ConsumerWidget {
  const _StartSessionButton({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(sessionId).notifier,
    );
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('start-session'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
        ),
        onPressed: controller.startSession,
        icon: const Icon(AppIcons.play, size: 18),
        label: Text(l10n.hostManageStartSession),
      ),
    );
  }
}

/// End session button inside sticky action bar.
class _EndSessionButton extends ConsumerWidget {
  const _EndSessionButton({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(sessionId).notifier,
    );
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('end-session'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
        ),
        onPressed: controller.endSession,
        icon: const Icon(AppIcons.stop, size: 18),
        label: Text(l10n.hostManageEndSession),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    if (session.status != SessionStatus.cancelled &&
        session.status != SessionStatus.finished) {
      return const SizedBox.shrink();
    }
    final cancelled = session.status == SessionStatus.cancelled;
    final color = cancelled
        ? Theme.of(context).colorScheme.outline
        : Colors.blue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? AppIcons.cancel : AppIcons.checkCircle,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cancelled ? 'Kèo đã bị hủy.' : 'Kèo đã kết thúc.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionGallery extends StatefulWidget {
  const _SessionGallery({required this.images, required this.onShare});
  final List<String> images;
  final VoidCallback onShare;

  @override
  State<_SessionGallery> createState() => _SessionGalleryState();
}

class _SessionGalleryState extends State<_SessionGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _SessionGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index < widget.images.length) return;
    _index = widget.images.isEmpty ? 0 : widget.images.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(_index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Mở ảnh kèo',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const Key('host-overview-gallery'),
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => GestureDetector(
                key: ValueKey('host-overview-cover-$index'),
                onTap: () => unawaited(
                  showAppLightbox(
                    context,
                    images: widget.images,
                    initialIndex: index,
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: Color(0xFFE5E7EB),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Icon(AppIcons.imageOff),
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm + 2,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < widget.images.length; index++)
                        AnimatedContainer(
                          key: ValueKey('host-gallery-dot-$index'),
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: index == _index ? 1 : 0.6,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 2,
                                offset: Offset(0, 1),
                                color: Color(0x4D000000),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(AppIcons.share, color: Colors.white),
                onPressed: widget.onShare,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  minimumSize: const Size.square(40),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.session, this.onEdit});
  final Session session;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final capacity = session.capacity;
    final feeConfig = session.feeConfig;
    final feeLabel = feeConfig == null
        ? null
        : sessionPriceLabel(session, locale) ??
              (feeConfig.isSplitEvenly
                  ? l10n.sessionFormFeeSplit
                  : l10n.feeNotSet);
    final showPerSlot =
        feeConfig != null &&
        !feeConfig.isSplitEvenly &&
        ((feeConfig.maleFee ?? 0) > 0 || (feeConfig.femaleFee ?? 0) > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCardHeader(onEdit: onEdit),
            if (session.displayHostName.isNotEmpty)
              _InfoRow(
                icon: AppIcons.user,
                label: '${l10n.sessionHostLabel}: ${session.displayHostName}',
              ),
            _InfoRow(
              icon: AppIcons.calendar,
              label: session.displayStartTime == null
                  ? 'Chưa có thời gian'
                  : Dates.dayWithRange(
                      session.displayStartTime!,
                      session.plannedEndTime,
                      locale: locale,
                    ),
            ),
            if (session.displayPlace.isNotEmpty)
              _InfoRow(
                icon: AppIcons.location,
                label: session.displayPlace,
              ),
            _InfoRow(
              icon: AppIcons.sessions,
              label: capacity > 0
                  ? '${session.numberOfCourts} sân · '
                        '${session.maxPlayersPerCourt} người/sân · '
                        '${l10n.sessionMaxPlayers(capacity)}'
                  : '${session.numberOfCourts} sân · '
                        '${session.maxPlayersPerCourt} người/sân',
            ),
            if (session.shuttlecock case final brand?
                when brand.trim().isNotEmpty)
              _InfoRow(
                icon: AppIcons.tag,
                label: l10n.sessionShuttlecock(brand.trim()),
              ),
            _InfoRow(
              icon: AppIcons.badge,
              alignCenter: true,
              topPadding: 8,
              child: _LevelBadges(levels: session.requiredLevels),
            ),
            if (feeLabel != null && feeConfig != null)
              _InfoRow(
                icon: AppIcons.creditCard,
                alignCenter: true,
                topPadding: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: feeLabel,
                              style: TextStyle(
                                color: palette.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (showPerSlot)
                              TextSpan(
                                text: ' ${l10n.sessionPerSlot}',
                                style: TextStyle(
                                  color: palette.mutedForeground,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('host-overview-fee-info'),
                      tooltip: l10n.feeTitle,
                      onPressed: () => unawaited(
                        showSessionFeeDetailDialog(
                          context,
                          feeConfig: feeConfig,
                        ),
                      ),
                      icon: const Icon(AppIcons.info, size: 17),
                      color: theme.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            if (session.description?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text('Mô tả', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(session.description!, style: theme.textTheme.bodyMedium),
            ],
            if (session.notes?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text('Ghi chú', style: theme.textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(session.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCardHeader extends StatelessWidget {
  const _InfoCardHeader({this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'THÔNG TIN KÈO',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
      if (onEdit != null) ...[
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('host-overview-edit-session'),
          onPressed: onEdit,
          icon: const Icon(AppIcons.edit, size: 14),
          label: Text(AppLocalizations.of(context).hostManageEditSession),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppSizes.minTapTarget),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
            ),
          ),
        ),
      ],
    ],
  );
}

class _LevelBadges extends StatelessWidget {
  const _LevelBadges({required this.levels});

  final List<int> levels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = sortByRank(levels.toSet());
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sorted.isEmpty)
          _OverviewLevelBadge(
            key: const Key('host-overview-all-levels'),
            label: l10n.sessionFormAllLevels,
            color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
          )
        else
          for (final level in sorted)
            _OverviewLevelBadge(
              key: ValueKey('host-overview-level-$level'),
              label: l10n.levelName(level),
              color: _levelColor(context, level),
            ),
        IconButton(
          key: const Key('host-overview-level-info'),
          tooltip: l10n.levelDescriptionsTitle,
          onPressed: () => unawaited(showLevelDescriptions(context)),
          icon: const Icon(AppIcons.info, size: 17),
          color: Theme.of(context).colorScheme.primary,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Color _levelColor(BuildContext context, int level) {
    final rank = levelRank(level);
    if (rank == null) {
      return Theme.of(context).extension<AppPalette>()!.mutedForeground;
    }
    if (rank <= 3) return AppColors.success;
    if (rank <= 6) return AppColors.warning;
    return Theme.of(context).colorScheme.error;
  }
}

class _OverviewLevelBadge extends StatelessWidget {
  const _OverviewLevelBadge({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    this.label,
    this.child,
    this.alignCenter = false,
    this.topPadding = 12,
  }) : assert(
         label != null || child != null,
         'Either label or child must be provided.',
       );
  final IconData icon;
  final String? label;
  final Widget? child;
  final bool alignCenter;
  final double topPadding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Row(
      crossAxisAlignment: alignCenter
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: child ?? Text(label!)),
      ],
    ),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.maxWidth,
    required this.players,
    required this.capacity,
    required this.male,
    required this.female,
    required this.waiting,
    required this.playing,
    required this.ready,
  });
  final double maxWidth;
  final int players;
  final int capacity;
  final int male;
  final int female;
  final int waiting;
  final int playing;
  final int ready;
  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 680 ? 4 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: columns == 2 ? 1.3 : 1.35,
      children: [
        _StatCard(
          icon: AppIcons.clubs,
          color: Colors.green,
          label: 'Người chơi',
          value: '$players/$capacity',
          detail: male + female == 0 ? null : 'Nam $male · Nữ $female',
          progress: capacity == 0 ? null : players / capacity,
        ),
        _StatCard(
          icon: AppIcons.hourglass,
          color: Colors.orange,
          label: 'Chờ',
          value: '$waiting',
        ),
        _StatCard(
          icon: AppIcons.trophy,
          color: Colors.green,
          label: 'Đang chơi',
          value: '$playing',
        ),
        _StatCard(
          icon: AppIcons.checkCircle,
          color: Colors.teal,
          label: 'Sẵn sàng',
          value: '$ready',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.detail,
    this.progress,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? detail;
  final double? progress;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          if (detail != null)
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (progress != null) ...[
            const SizedBox(height: 5),
            LinearProgressIndicator(value: progress!.clamp(0, 1), color: color),
          ],
        ],
      ),
    ),
  );
}
