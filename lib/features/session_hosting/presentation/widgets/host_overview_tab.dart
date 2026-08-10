import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_section.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_run_card.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// Mobile port of the host web app's `SessionOverviewTab`.
class HostOverviewTab extends ConsumerWidget {
  const HostOverviewTab({required this.session, super.key});

  final Session session;

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
        builder: (context, constraints) => Center(
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
                  _SessionGallery(name: session.name, images: images),
                ],
                const SizedBox(height: AppSpacing.md),
                SessionRunCard(session: session),
                const SizedBox(height: AppSpacing.md),
                _InfoCard(session: session, onShare: () => _share(context)),
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
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) => SharePlus.instance.share(
    ShareParams(
      text:
          '${session.name}\nhttps://vmito.com/vi/sessions/${session.slug ?? session.id}',
    ),
  );
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
            cancelled
                ? AppIcons.cancel
                : AppIcons.checkCircle,
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

class _SessionGallery extends StatelessWidget {
  const _SessionGallery({required this.name, required this.images});
  final String name;
  final List<String> images;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Mở ảnh kèo',
    child: InkWell(
      onTap: () => unawaited(showAppLightbox(context, images: images)),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: images.first,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE5E7EB),
                  child: Icon(AppIcons.imageOff),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.black45,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Chip(
                    avatar: const Icon(AppIcons.image, size: 16),
                    label: Text('${images.length}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.session, required this.onShare});
  final Session session;
  final VoidCallback onShare;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thông tin kèo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('host-overview-share'),
                  tooltip: 'Chia sẻ kèo',
                  onPressed: onShare,
                  icon: const Icon(AppIcons.share),
                ),
              ],
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
              label:
                  '${session.numberOfCourts} sân · ${session.maxPlayersPerCourt} người/sân',
            ),
            if (session.priceLabel != null)
              _InfoRow(
                icon: AppIcons.creditCard,
                label: session.priceLabel!,
              ),
            if (session.description?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text(
                session.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (session.notes?.trim().isNotEmpty ?? false) ...[
              const Divider(height: 24),
              Text('Ghi chú', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(session.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
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
