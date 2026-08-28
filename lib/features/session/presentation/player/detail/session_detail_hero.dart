import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// Cover carousel and status badges for the session detail flexible space.
///
/// The two bottom badges carry the only facts a scroller needs before
/// committing: whether there is room, and whether the session already
/// happened.
class SessionDetailHero extends StatefulWidget {
  const SessionDetailHero({required this.session, super.key});

  final Session session;

  /// Keep the session cover aligned with the venue detail hero.
  static const heroHeight = 220.0;

  @override
  State<SessionDetailHero> createState() => _SessionDetailHeroState();
}

class _SessionDetailHeroState extends State<SessionDetailHero> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.session.galleryImages.isEmpty
        ? [Session.defaultCoverPhoto]
        : widget.session.galleryImages;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const Key('session-detail-hero-carousel'),
          controller: _controller,
          onPageChanged: (idx) => setState(() => _index = idx),
          itemCount: images.length,
          itemBuilder: (context, idx) {
            final image = images[idx];
            return GestureDetector(
              key: ValueKey('session-detail-cover-$idx'),
              onTap: () => unawaited(
                showAppLightbox(
                  context,
                  images: images,
                  initialIndex: idx,
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              ),
            );
          },
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: AppSpacing.lg,
            left: 0,
            right: 0,
            child: _Dots(count: images.length, current: _index),
          ),
        Positioned(
          bottom: AppSpacing.lg,
          left: AppSpacing.md,
          child: widget.session.isCrawled
              ? const _CrawledBadge()
              : _SlotBadge(session: widget.session),
        ),
        Positioned(
          bottom: AppSpacing.lg,
          right: AppSpacing.md,
          child: _StatusBadge(status: widget.session.status),
        ),
      ],
    );
  }
}

class _CrawledBadge extends StatelessWidget {
  const _CrawledBadge();

  @override
  Widget build(BuildContext context) => _Pill(
    label: AppLocalizations.of(context).sessionCrawledBadge,
    background: const Color(0xFF1877F2),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == current ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: i == current ? 1 : 0.6),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
    ],
  );
}

/// `Còn 16 slot` / `Hết slot` / `Đã đóng đăng ký`.
class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final slots = session.availableSlots;

    final (label, isMuted) = switch ((session.status.isOpen, session.isFull)) {
      (false, _) => (l10n.sessionRegistrationClosed, true),
      (_, true) => (l10n.sessionSlotsFull, true),
      // Capacity unset: saying "0 slots" would read as full when the host has
      // simply not configured courts yet.
      _ => (slots == null ? null : l10n.sessionSlotsLeft(slots), false),
    };
    if (label == null) return const SizedBox.shrink();

    return _Pill(
      label: label,
      background: isMuted
          ? Colors.black.withValues(alpha: 0.6)
          : palette.success,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    final (label, background, foreground) = switch (status) {
      SessionStatus.preparing => (
        l10n.sessionStatusPreparing,
        Colors.white,
        Colors.black87,
      ),
      SessionStatus.inProgress => (
        l10n.sessionStatusInProgress,
        theme.colorScheme.primary,
        theme.colorScheme.onPrimary,
      ),
      SessionStatus.finished => (
        l10n.sessionStatusFinished,
        Colors.black.withValues(alpha: 0.6),
        Colors.white,
      ),
      SessionStatus.cancelled => (
        l10n.sessionStatusCancelled,
        palette.warning,
        Colors.white,
      ),
    };

    return _Pill(label: label, background: background, foreground: foreground);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    this.foreground = Colors.white,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 4,
      vertical: 5,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
