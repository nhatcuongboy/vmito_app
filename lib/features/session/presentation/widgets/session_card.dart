import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/level_range_chips.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// One session in the browse list.
///
/// Horizontal, matching the web's mobile layout: the cover sits on the left so
/// the text column carries the two fields a player actually decides on — the
/// **skill band** and the **price**. A vertical card with a full-width cover
/// pushes both below the fold.
///
/// `BaseSessionCard` on web is 1,482 lines because it serves every context at
/// once. This is the browse card only.
/// Visual treatment for the contexts that reuse [SessionCard].
///
/// The public discovery feed needs availability at a glance, while hosted and
/// profile lists retain their established management-focused presentation.
enum SessionCardVariant { standard, browse }

/// An action shown in a session card's primary button or overflow menu.
class SessionCardAction {
  const SessionCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
}

class SessionCard extends ConsumerWidget {
  const SessionCard({
    required this.session,
    this.onTap,
    this.onHost,
    this.onClone,
    this.onDownloadImage,
    this.onShare,
    this.onDelete,
    this.compactStatusBadge = false,
    this.showFavorite = false,
    this.hideHostInfo = false,
    this.variant = SessionCardVariant.standard,
    this.registrationStatus,
    this.showSportBadge = false,
    this.showSessionStatusBadge = false,
    this.sessionStatusBadgeAtTop = false,
    this.sportBadgeAtBottom = false,
    this.registrationBadgeAtBottom = false,
    this.showSportIconInRegistrationBadge = false,
    this.primaryAction,
    this.moreActions = const [],
    this.extraTimeTopSpacing = false,
    this.hostRating,
    super.key,
  });

  final Session session;
  final VoidCallback? onTap;
  final VoidCallback? onHost;
  final VoidCallback? onClone;
  final VoidCallback? onDownloadImage;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool compactStatusBadge;
  final bool showFavorite;
  final bool hideHostInfo;
  final SessionCardVariant variant;
  final RegistrationStatus? registrationStatus;
  final bool showSportBadge;
  final bool showSessionStatusBadge;
  final bool sessionStatusBadgeAtTop;
  final bool sportBadgeAtBottom;
  final bool registrationBadgeAtBottom;
  final bool showSportIconInRegistrationBadge;
  final SessionCardAction? primaryAction;
  final List<SessionCardAction> moreActions;
  final bool extraTimeTopSpacing;
  final RatingStats? hostRating;

  static const _coverWidth = 108.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final isBrowse = variant == SessionCardVariant.browse;
    final isSplitFee = session.feeConfig?.isSplitEvenly == true;
    final priceLabel = isSplitFee ? l10n.sessionFeeSplit : session.priceLabel;
    final legacyMoreActions = [
      if (onClone != null)
        SessionCardAction(
          label: l10n.mySessionsClone,
          icon: AppIcons.copy,
          onPressed: onClone,
        ),
      if (onDownloadImage != null)
        SessionCardAction(
          label: l10n.mySessionsDownloadImage,
          icon: AppIcons.download,
          onPressed: onDownloadImage,
        ),
      if (onShare != null)
        SessionCardAction(
          label: l10n.mySessionsShare,
          icon: AppIcons.share,
          onPressed: onShare,
        ),
      if (onDelete != null)
        SessionCardAction(
          label: l10n.mySessionsDelete,
          icon: AppIcons.delete,
          onPressed: onDelete,
          isDestructive: true,
        ),
    ];
    final cardPrimaryAction =
        primaryAction ??
        (onHost == null
            ? null
            : SessionCardAction(
                label: 'Host',
                icon: AppIcons.settings,
                onPressed: onHost,
              ));
    final isLegacyHostAction = primaryAction == null && onHost != null;
    final cardMoreActions = moreActions.isNotEmpty
        ? moreActions
        : legacyMoreActions;
    final showActions = cardPrimaryAction != null || cardMoreActions.isNotEmpty;
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    final browseBorderColor = session.isCrawled
        ? theme.brightness == Brightness.dark
              ? palette.border
              : const Color(0xFFE5E7EB)
        // The light-mode mint (green-300) reads as a neon outline on the
        // dark card background, so dark mode uses the more muted brand green.
        : theme.brightness == Brightness.dark
        ? palette.success
        : const Color(0xFF86EFAC);
    final card = Card(
      color: isBrowse
          ? session.isCrawled
                ? _crawledCardColor(theme)
                : _browseCardColor(theme)
          : null,
      shape: isBrowse
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              side: BorderSide(color: browseBorderColor),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cover(
                session: session,
                width: _coverWidth,
                compactStatusBadge: compactStatusBadge,
                variant: variant,
                registrationStatus: registrationStatus,
                showSportBadge: showSportBadge,
                showSessionStatusBadge: showSessionStatusBadge,
                sessionStatusBadgeAtTop: sessionStatusBadgeAtTop,
                sportBadgeAtBottom: sportBadgeAtBottom,
                registrationBadgeAtBottom: registrationBadgeAtBottom,
                showSportIconInRegistrationBadge:
                    showSportIconInRegistrationBadge,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              session.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (showFavorite) ...[
                            const SizedBox(width: AppSpacing.xs),
                            FavoriteButton(
                              key: ValueKey('session-favorite-${session.id}'),
                              type: FavoriteType.session,
                              targetId: session.id,
                              initialIsFavorite: session.isFavorite,
                              variant: FavoriteButtonVariant.surface,
                              showCount: false,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (!hideHostInfo && session.displayHostName.isNotEmpty)
                        _HostLine(session: session, rating: hostRating),
                      if (extraTimeTopSpacing &&
                          session.displayStartTime != null)
                        const SizedBox(height: AppSpacing.xs),
                      if (session.displayStartTime case final start?)
                        _TimeLine(
                          start: start,
                          end: session.plannedEndTime,
                          locale: Localizations.localeOf(
                            context,
                          ).languageCode,
                          todayLabel: l10n.dateToday,
                          tomorrowLabel: l10n.dateTomorrow,
                          yesterdayLabel: l10n.dateYesterday,
                        ),
                      if (session.hasLocation)
                        _AddressLine(
                          icon: AppIcons.location,
                          place: session.placeParts(
                            showNewAddress: showNewAddress,
                          ),
                          trailing: session.distance == null
                              ? null
                              : '${session.distance!.toStringAsFixed(1)} km',
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: LevelRangeChips(
                                requiredLevels: session.requiredLevels,
                              ),
                            ),
                          ),
                          if (priceLabel != null)
                            _PriceLabel(
                              price: priceLabel,
                              showSlotSuffix: isBrowse && !isSplitFee,
                            ),
                        ],
                      ),
                      if (isBrowse) ...[
                        const SizedBox(height: AppSpacing.xs),
                        if (session.isCrawled)
                          _FacebookSourceRow(session: session)
                        else
                          _BrowseAvailability(session: session),
                      ],
                      if (showActions) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: palette.border),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (cardPrimaryAction != null)
                                FilledButton.icon(
                                  key: ValueKey(
                                    '${isLegacyHostAction ? 'session-host-button' : 'session-primary-button'}-${session.id}',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: AppSpacing.sm,
                                    ),
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    cardPrimaryAction.icon,
                                    size: 18,
                                  ),
                                  label: Text(
                                    cardPrimaryAction.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: cardPrimaryAction.onPressed,
                                ),
                              if (cardPrimaryAction != null &&
                                  cardMoreActions.isNotEmpty)
                                const SizedBox(width: AppSpacing.xs),
                              if (cardMoreActions.isNotEmpty)
                                PopupMenuButton<SessionCardAction>(
                                  key: ValueKey(
                                    'session-more-button-${session.id}',
                                  ),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      EdgeInsets.zero,
                                    ),
                                    minimumSize: WidgetStateProperty.all(
                                      const Size(40, 40),
                                    ),
                                  ),
                                  icon: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: palette.border),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: const Icon(
                                      AppIcons.moreVert,
                                      size: 20,
                                    ),
                                  ),
                                  itemBuilder: (context) => [
                                    for (final action in cardMoreActions)
                                      PopupMenuItem(
                                        value: action,
                                        child: Builder(
                                          builder: (context) {
                                            final color = action.isDestructive
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                : null;
                                            return Row(
                                              children: [
                                                Icon(
                                                  action.icon,
                                                  size: 18,
                                                  color: color,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
                                                Text(
                                                  action.label,
                                                  style: color == null
                                                      ? null
                                                      : TextStyle(color: color),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                  onSelected: (action) =>
                                      action.onPressed?.call(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isBrowse || session.isCrawled) return card;
    return DecoratedBox(
      key: const Key('session-browse-vmito-shadow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F10B981),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _SlotsBadge extends StatelessWidget {
  const _SlotsBadge({required this.session, this.compact = false});

  final Session session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (session.status == SessionStatus.finished) {
      return Container(
        key: const Key('session-finished-badge'),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppRadius.sm,
          ),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        child: Text(
          l10n.mySessionsEnded,
          style: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final slots = session.availableSlots ?? 0;
    final closed = !session.status.isOpen;
    final full = slots == 0;
    final label = closed
        ? l10n.sessionRegistrationClosed
        : full
        ? l10n.sessionSlotsFull
        : l10n.sessionSlotsLeft(slots);
    final color = closed || full ? palette.mutedForeground : palette.success;
    return Container(
      key: const Key('session-slots-badge'),
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: compact ? 0 : 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          AppRadius.sm,
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontSize: compact ? 10 : null,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.session,
    required this.width,
    this.compactStatusBadge = false,
    this.variant = SessionCardVariant.standard,
    this.registrationStatus,
    this.showSportBadge = false,
    this.showSessionStatusBadge = false,
    this.sessionStatusBadgeAtTop = false,
    this.sportBadgeAtBottom = false,
    this.registrationBadgeAtBottom = false,
    this.showSportIconInRegistrationBadge = false,
  });

  final Session session;
  final double width;
  final bool compactStatusBadge;
  final SessionCardVariant variant;
  final RegistrationStatus? registrationStatus;
  final bool showSportBadge;
  final bool showSessionStatusBadge;
  final bool sessionStatusBadgeAtTop;
  final bool sportBadgeAtBottom;
  final bool registrationBadgeAtBottom;
  final bool showSportIconInRegistrationBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final url = session.coverPhoto?.trim().isNotEmpty ?? false
        ? session.coverPhoto!.trim()
        : Session.defaultCoverPhoto;

    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, _) => ColoredBox(color: palette.muted),
              errorWidget: (context, _, _) => _Placeholder(palette: palette),
            ),
          ),
          if (showSessionStatusBadge)
            Positioned(
              top: sessionStatusBadgeAtTop ? AppSpacing.xs : null,
              left: AppSpacing.xs,
              bottom: sessionStatusBadgeAtTop ? null : AppSpacing.xs,
              child: _SessionStatusBadge(status: session.status),
            )
          else if ((variant == SessionCardVariant.browse || showSportBadge) &&
              !sportBadgeAtBottom)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _SportBadge(session: session),
            )
          else if (session.isCrawled)
            const Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _CrawledBadge(),
            ),
          if (variant == SessionCardVariant.standard &&
              !showSessionStatusBadge &&
              !showSportBadge &&
              !session.isCrawled &&
              (session.availableSlots != null ||
                  session.status == SessionStatus.finished))
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: _SlotsBadge(
                session: session,
                compact: compactStatusBadge,
              ),
            ),
          if ((variant == SessionCardVariant.browse || showSportBadge) &&
              sportBadgeAtBottom)
            Positioned(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: _SportBadge(session: session),
            ),
          if (registrationStatus != null)
            Positioned(
              left: AppSpacing.xs,
              top: registrationBadgeAtBottom ? null : AppSpacing.xs,
              bottom: registrationBadgeAtBottom ? AppSpacing.xs : null,
              child: showSportIconInRegistrationBadge
                  ? _RegistrationBadgeWithSport(
                      status: registrationStatus!,
                      sportType: session.sportType,
                    )
                  : _RegistrationBadge(status: registrationStatus!),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.muted,
      child: Icon(
        AppIcons.sessions,
        color: palette.mutedForeground,
      ),
    );
  }
}

Color _crawledCardColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF111827)
    : const Color(0xFFF8FAFC);

// Regular (non-crawled) browse cards were hardcoded to white, which stayed
// white against dark-mode text colors and read as a washed-out card.
Color _browseCardColor(ThemeData theme) =>
    theme.brightness == Brightness.dark ? AppColors.cardDark : Colors.white;

/// Identifies the sport without competing with the cover itself.
class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (session.sportType) {
      SessionSportType.badminton => '🏸 ${l10n.sessionSportBadminton}',
      SessionSportType.pickleball => '🏓 ${l10n.sessionSportPickleball}',
    };
    final radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            key: const Key('session-sport-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: radius,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationBadge extends StatelessWidget {
  const _RegistrationBadge({required this.status});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (label, color, icon) = switch (status) {
      RegistrationStatus.pending => (
        l10n.registrationStatusPending,
        palette.warning,
        AppIcons.clock,
      ),
      RegistrationStatus.approved => (
        l10n.registrationStatusApproved,
        palette.success,
        AppIcons.check,
      ),
      RegistrationStatus.rejected => (
        l10n.registrationStatusRejected,
        theme.colorScheme.error,
        null,
      ),
    };

    return Container(
      key: const Key('session-registration-status-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              key: const Key('session-registration-status-icon'),
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lifecycle state of the session, kept distinct from a player's
/// registration decision.
class _SessionStatusBadge extends StatelessWidget {
  const _SessionStatusBadge({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
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

    return Container(
      key: const Key('session-status-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RegistrationBadgeWithSport extends StatelessWidget {
  const _RegistrationBadgeWithSport({
    required this.status,
    required this.sportType,
  });

  final RegistrationStatus status;
  final SessionSportType sportType;

  @override
  Widget build(BuildContext context) {
    final icon = switch (sportType) {
      SessionSportType.badminton => '🏸',
      SessionSportType.pickleball => '🏓',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          key: const Key('session-registration-sport-icon'),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
        _RegistrationBadge(status: status),
      ],
    );
  }
}

class _BrowseAvailability extends StatelessWidget {
  const _BrowseAvailability({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final courts = session.numberOfCourts > 0
        ? l10n.sessionCourtCount(session.numberOfCourts)
        : null;
    final slots = session.availableSlots;

    // An unset capacity is not a full session. Keep the useful court count,
    // but never fabricate a percentage or a slot label.
    if (slots == null) {
      return _BrowseMetaRow(courts: courts);
    }

    final (label, color) = _availabilityPresentation(
      session: session,
      l10n: l10n,
      palette: palette,
      primary: theme.colorScheme.primary,
    );
    final trackColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1F2937)
        : const Color(0xFFF3F4F6);
    final fill = (session.playerCount / session.capacity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrowseMetaRow(
            label: label,
            labelColor: color,
            courts: courts,
          ),
          const SizedBox(height: 4),
          Semantics(
            label: '$label, ${(fill * 100).round()}%',
            child: SizedBox(
              key: const Key('session-browse-progress-track'),
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const borderWidth = 1.0;
                  final innerWidth = constraints.maxWidth - borderWidth * 2;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: trackColor,
                            border: Border.all(color: palette.border),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      if (fill > 0)
                        Positioned(
                          left: borderWidth,
                          top: borderWidth,
                          bottom: borderWidth,
                          width: innerWidth * fill,
                          child: DecoratedBox(
                            key: const Key('session-browse-progress-fill'),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.price, required this.showSlotSuffix});

  final String price;
  final bool showSlotSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    if (!showSlotSuffix) return Text(price, style: priceStyle);

    return Text.rich(
      key: const Key('session-price-per-slot'),
      TextSpan(
        children: [
          TextSpan(text: price, style: priceStyle),
          TextSpan(
            text: ' ${AppLocalizations.of(context).sessionFeeSlotSuffix}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF71717A),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

(String, Color) _availabilityPresentation({
  required Session session,
  required AppLocalizations l10n,
  required AppPalette palette,
  required Color primary,
}) {
  final slots = session.availableSlots!;
  if (!session.status.isOpen) {
    return (l10n.sessionRegistrationClosed, palette.mutedForeground);
  }
  if (slots == 0) return (l10n.sessionSlotsFull, const Color(0xFFEF4444));
  if (slots <= 2) {
    return (l10n.sessionSlotsLeftUrgent(slots), const Color(0xFFF97316));
  }
  return (l10n.sessionSlotsLeft(slots), primary);
}

class _BrowseMetaRow extends StatelessWidget {
  const _BrowseMetaRow({this.label, this.labelColor, this.courts});

  final String? label;
  final Color? labelColor;
  final String? courts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    if (label == null && courts == null) return const SizedBox.shrink();
    return Row(
      children: [
        if (label != null)
          Expanded(
            child: Text(
              label!,
              key: const Key('session-browse-slot-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          const Spacer(),
        if (label != null && courts != null)
          const SizedBox(width: AppSpacing.sm),
        if (courts != null)
          Text(
            courts!,
            key: const Key('session-browse-court-count'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _FacebookSourceRow extends StatelessWidget {
  const _FacebookSourceRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final courts = session.numberOfCourts > 0
        ? l10n.sessionCourtCount(session.numberOfCourts)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(AppIcons.facebook, size: 16, color: palette.mutedForeground),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              l10n.sessionFacebookSource,
              key: const Key('session-facebook-source'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (courts != null)
            Text(
              courts,
              key: const Key('session-browse-court-count'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Marks a session imported from a public Facebook post — view-only, with no
/// host account behind it.
class _CrawledBadge extends StatelessWidget {
  const _CrawledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFF8BB9FF)),
        boxShadow: const [BoxShadow(color: Color(0x471877F2), blurRadius: 8)],
      ),
      child: Text(
        AppLocalizations.of(context).sessionCrawledBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HostLine extends StatelessWidget {
  const _HostLine({required this.session, this.rating});

  final Session session;
  final RatingStats? rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final image = session.displayHostImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          UserAvatar(
            name: session.displayHostName,
            imageUrl: image,
            size: 24,
            borderWidth: 0,
            boxShadow: const [],
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: session.displayHostName,
                children: [
                  if (rating case final value? when value.total > 0)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Semantics(
                          label: 'Rating ${value.average.toStringAsFixed(1)}',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFEAB308),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                value.average.toStringAsFixed(1),
                                key: const Key('session-host-rating'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              key: const Key('session-host-name'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({
    required this.start,
    required this.end,
    required this.locale,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.yesterdayLabel,
  });

  final DateTime start;
  final DateTime? end;
  final String locale;
  final String todayLabel;
  final String tomorrowLabel;
  final String yesterdayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const dateColor = Color(0xFFF97316);
    final timeColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
        : const Color(0xFF3F3F46);
    final date = Dates.relativeDay(
      start,
      locale: locale,
      todayLabel: todayLabel,
      tomorrowLabel: tomorrowLabel,
      yesterdayLabel: yesterdayLabel,
    );
    final time = end == null
        ? Dates.timeOnly(start, locale: locale)
        : '${Dates.timeOnly(start, locale: locale)}-'
              '${Dates.timeOnly(end!, locale: locale)}';
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const Icon(AppIcons.clock, size: 13, color: dateColor),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$date,',
                    key: const Key('session-date-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(color: dateColor),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time,
                    key: const Key('session-time-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(color: timeColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.place,
    this.trailing,
  });

  final IconData icon;
  final (String main, String? area) place;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final tint = palette.mutedForeground;
    final (main, area) = place;
    final style = theme.textTheme.bodySmall?.copyWith(color: tint);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    main,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                // The ward/district must never be the part that gets
                // truncated, so it sits outside the venue name's Flexible.
                if (area != null && area.isNotEmpty)
                  Text(' • $area', maxLines: 1, style: style),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
