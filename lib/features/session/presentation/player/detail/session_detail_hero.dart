import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// Cover carousel with the overlay chrome, ported from the web app's
/// `SessionDetailHero`.
///
/// The two bottom badges carry the only facts a scroller needs before
/// committing: whether there is room, and whether the session already
/// happened.
class SessionDetailHero extends StatefulWidget {
  const SessionDetailHero({
    required this.session,
    required this.onShare,
    required this.onSignInRequired,
    super.key,
  });

  final Session session;
  final VoidCallback onShare;

  /// Raised when a signed-out visitor taps the heart.
  final VoidCallback onSignInRequired;

  /// Matches the web's `clamp(170px, 29vh, 235px)`.
  static const double height = 235;

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
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: SessionDetailHero.height + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.grey.shade900,
            child: images.isEmpty
                ? const _CoverPlaceholder()
                : PageView.builder(
                    controller: _controller,
                    itemCount: images.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => unawaited(
                        showAppLightbox(
                          context,
                          images: images,
                          initialIndex: index,
                        ),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        errorWidget: (context, _, _) =>
                            const _CoverPlaceholder(),
                      ),
                    ),
                  ),
          ),
          const _Scrim(alignment: Alignment.topCenter),
          const _Scrim(alignment: Alignment.bottomCenter),
          Positioned(
            top: topInset + AppSpacing.sm,
            left: AppSpacing.sm,
            child: _OverlayButton(
              icon: AppIcons.chevronLeft,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: topInset + AppSpacing.sm,
            right: AppSpacing.md,
            child: Row(
              children: [
                FavoriteButton(
                  type: FavoriteType.session,
                  targetId: widget.session.id,
                  onSignInRequired: widget.onSignInRequired,
                ),
                const SizedBox(width: AppSpacing.sm),
                _OverlayButton(
                  icon: AppIcons.share,
                  tooltip: AppLocalizations.of(context).sessionShareAction,
                  onPressed: widget.onShare,
                ),
              ],
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
            child: _SlotBadge(session: widget.session),
          ),
          Positioned(
            bottom: AppSpacing.lg,
            right: AppSpacing.md,
            child: _StatusBadge(status: widget.session.status),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.grey.shade800,
    child: Icon(
      AppIcons.sessions,
      size: 48,
      color: Colors.white.withValues(alpha: 0.5),
    ),
  );
}

/// Darkens the strip behind the overlay buttons and badges so white text
/// stays legible on a light photo.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment == Alignment.topCenter;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, color: Colors.white),
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      // Below the 48px floor on purpose: a larger circle would cover a
      // meaningful slice of a 235px-tall photo. Still above the 44px iOS
      // minimum.
      minimumSize: const Size.square(44),
    ),
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
