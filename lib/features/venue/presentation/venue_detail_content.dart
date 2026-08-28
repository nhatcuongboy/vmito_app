import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_typography.dart';
import 'package:vmito_app/core/widgets/app_address_text.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

String venueDisplayName(Venue venue, AppLocalizations l10n) =>
    venue.displayName(
      generic: l10n.venueGenericName(venue.name),
      bySport: {
        'BADMINTON': l10n.venueBadmintonName(venue.name),
        'PICKLEBALL': l10n.venuePickleballName(venue.name),
      },
    );

class VenueDetailContent extends StatefulWidget {
  const VenueDetailContent({
    required this.venue,
    required this.priceBooks,
    required this.onBack,
    required this.onShare,
    required this.onCall,
    required this.onZalo,
    required this.onDirections,
    required this.onFindSessions,
    required this.onRequestUpdate,
    super.key,
  });

  final Venue venue;
  final AsyncValue<List<VenuePriceBook>> priceBooks;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onCall;
  final VoidCallback onZalo;
  final VoidCallback onDirections;
  final VoidCallback onFindSessions;
  final VoidCallback onRequestUpdate;

  @override
  State<VenueDetailContent> createState() => _VenueDetailContentState();
}

class _VenueDetailContentState extends State<VenueDetailContent> {
  static const _heroHeight = 220.0;
  final _scrollController = ScrollController();
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final pinned =
        _scrollController.offset >=
        _heroHeight - AppSizes.appBarHeight - AppSpacing.md;
    if (pinned != _isPinned && mounted) setState(() => _isPinned = pinned);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final pinnedForeground = theme.colorScheme.onSurface;
    const overlayForeground = Colors.white;

    return CustomScrollView(
      key: const Key('venue-detail-scroll'),
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: _heroHeight,
          backgroundColor: _isPinned
              ? theme.colorScheme.surface
              : Colors.transparent,
          foregroundColor: _isPinned ? pinnedForeground : overlayForeground,
          surfaceTintColor: theme.colorScheme.surface,
          shadowColor: Colors.black26,
          elevation: _isPinned ? 2 : 0,
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: _HeaderButton(
              key: const Key('venue-back-button'),
              icon: AppIcons.chevronLeft,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              pinned: _isPinned,
              onPressed: widget.onBack,
            ),
          ),
          title: AnimatedOpacity(
            key: const Key('venue-sticky-title'),
            opacity: _isPinned ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Text(
              venueDisplayName(widget.venue, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.compactAppBarTitle(theme.textTheme),
            ),
          ),
          actions: [
            FavoriteButton(
              key: const Key('venue-favorite-button'),
              type: FavoriteType.venue,
              targetId: widget.venue.id,
              overlay: !_isPinned,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: _HeaderButton(
                key: const Key('venue-share-button'),
                icon: AppIcons.share,
                tooltip: l10n.commonShare,
                pinned: _isPinned,
                onPressed: widget.onShare,
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _VenueHero(venue: widget.venue),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoCard(
                      venue: widget.venue,
                      onDirections: widget.onDirections,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AboutCard(
                      venue: widget.venue,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PricingCard(priceBooks: widget.priceBooks),
                    if (widget.venue.images.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _PhotosCard(venue: widget.venue),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _ContributionCard(
                      onRequestUpdate: widget.onRequestUpdate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.pinned,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool pinned;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = pinned ? 28.0 : 32.0;
    return SizedBox(
      width: width,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: pinned ? null : Colors.white),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.expand(),
        style: IconButton.styleFrom(
          backgroundColor: pinned ? Colors.transparent : Colors.black54,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _VenueHero extends StatefulWidget {
  const _VenueHero({required this.venue});

  final Venue venue;

  @override
  State<_VenueHero> createState() => _VenueHeroState();
}

class _VenueHeroState extends State<_VenueHero> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final images = widget.venue.gallery;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isEmpty)
          CachedNetworkImage(
            key: const Key('venue-default-cover'),
            imageUrl: kDefaultCoverPhoto,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(AppIcons.imageOff),
            ),
          )
        else
          PageView.builder(
            key: const Key('venue-hero-carousel'),
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => unawaited(
                showAppLightbox(context, images: images, initialIndex: index),
              ),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(AppIcons.imageOff),
                ),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black54],
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: AppSpacing.md,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < images.length; index++)
                  AnimatedContainer(
                    key: ValueKey('venue-hero-dot-$index'),
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: index == _index ? 1 : .6,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          bottom: AppSpacing.md,
          left: AppSpacing.md,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (widget.venue.closureStatus != 'OPERATING')
                _StatusBadge(
                  icon: AppIcons.cancel,
                  label: widget.venue.closureStatus == 'PERMANENTLY_CLOSED'
                      ? l10n.venuePermanentlyClosed
                      : l10n.venueTemporarilyClosed,
                  color: widget.venue.closureStatus == 'PERMANENTLY_CLOSED'
                      ? Colors.red
                      : Colors.orange,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.venue,
    required this.onDirections,
  });

  final Venue venue;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    final hasHours = venue.openingHours?.trim().isNotEmpty ?? false;
    final hasCourts = venue.numberOfCourts != null && venue.numberOfCourts! > 0;

    return Card(
      key: const Key('venue-info-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (venue.logo?.trim().isNotEmpty ?? false) ...[
                  ClipRRect(
                    key: const Key('venue-logo'),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: CachedNetworkImage(
                      imageUrl: venue.logo!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    venueDisplayName(venue, l10n),
                    key: const Key('venue-display-name'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                if (venue.isVerified)
                  Tooltip(
                    message: l10n.venueVerified,
                    child: Icon(
                      key: const Key('venue-verified-icon'),
                      AppIcons.verified,
                      size: 22,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            ),
            if (venue.hasAddressData) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      key: const Key('venue-address-location-icon'),
                      AppIcons.location,
                      size: 19,
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppAddressText(
                      key: const Key('venue-address'),
                      address: venue.address,
                      district: venue.district,
                      city: venue.city,
                      newAddress: venue.newAddress,
                      newDistrict: venue.newDistrict,
                      newCity: venue.newCity,
                      maxLines: 5,
                      suffix: venue.distance == null
                          ? null
                          : ' (${l10n.venueDistance(venue.distance!)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                        height: 1.5,
                      ),
                      trailing: IconButton(
                        key: const Key('venue-address-directions-button'),
                        tooltip: l10n.venueGoogleMaps,
                        onPressed: onDirections,
                        icon: const Icon(AppIcons.navigation, size: 20),
                        color: theme.colorScheme.primary,
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(24),
                          maximumSize: const Size.square(24),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (hasHours || hasCourts) ...[
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHours)
                      Expanded(
                        child: _FactBox(
                          label: l10n.venueOpeningHours,
                          value: venue.openingHours!,
                        ),
                      ),
                    if (hasHours && hasCourts)
                      const SizedBox(width: AppSpacing.sm),
                    if (hasCourts)
                      Expanded(
                        child: _FactBox(
                          label: l10n.venueCourtsLabel,
                          value: l10n.venueCourtsValue(venue.numberOfCourts!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactBox extends StatelessWidget {
  const _FactBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.muted,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final description = _plainText(venue.description);
    final hasAmenities =
        venue.hasCarParking != null ||
        venue.hasCanteen != null ||
        (venue.wifiName?.trim().isNotEmpty ?? false) ||
        (venue.bookingPolicy?.trim().isNotEmpty ?? false);
    return _SectionCard(
      key: const Key('venue-about-card'),
      title: l10n.venueAbout,
      children: [
        _ExpandableDescription(
          text: description.isEmpty ? l10n.venueNoDescription : description,
        ),
        if (venue.courtLayoutImage?.trim().isNotEmpty ?? false) ...[
          Divider(height: AppSpacing.xl, color: palette.border),
          Text(
            l10n.venueCourtLayout,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () => unawaited(
              showAppLightbox(context, images: [venue.courtLayoutImage!]),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: CachedNetworkImage(
                imageUrl: venue.courtLayoutImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
        if (hasAmenities) ...[
          Divider(height: AppSpacing.xl, color: palette.border),
          Text(
            l10n.venueAmenities,
            key: const Key('venue-amenities-heading'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _VenueAmenities(venue: venue),
        ],
      ],
    );
  }
}

class _VenueAmenities extends StatelessWidget {
  const _VenueAmenities({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasWifi = venue.wifiName?.trim().isNotEmpty ?? false;
    final hasPolicy = venue.bookingPolicy?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (venue.hasCarParking != null || venue.hasCanteen != null)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (venue.hasCarParking != null)
                _AmenityBadge(
                  key: const Key('venue-car-parking'),
                  icon: AppIcons.car,
                  label: l10n.venueCarParking,
                  available: venue.hasCarParking!,
                ),
              if (venue.hasCanteen != null)
                _AmenityBadge(
                  key: const Key('venue-canteen'),
                  icon: AppIcons.canteen,
                  label: l10n.venueCanteen,
                  available: venue.hasCanteen!,
                ),
            ],
          ),
        if ((venue.hasCarParking != null || venue.hasCanteen != null) &&
            (hasWifi || hasPolicy))
          const SizedBox(height: AppSpacing.lg),
        if (hasWifi)
          _AmenityDetail(
            key: const Key('venue-wifi'),
            icon: AppIcons.wifi,
            iconColor: Colors.cyan.shade700,
            iconBackground: Colors.cyan.shade50,
            label: l10n.venueWifi,
            value: venue.wifiName!,
            secondary: venue.wifiPassword?.trim().isEmpty ?? true
                ? null
                : '${l10n.venueWifiPassword} ${venue.wifiPassword}',
          ),
        if (hasWifi && hasPolicy) const SizedBox(height: AppSpacing.lg),
        if (hasPolicy)
          _AmenityDetail(
            key: const Key('venue-booking-policy'),
            icon: AppIcons.info,
            iconColor: Colors.amber.shade800,
            iconBackground: Colors.amber.shade50,
            label: l10n.venueBookingPolicy,
            value: venue.bookingPolicy!,
          ),
      ],
    );
  }
}

class _AmenityBadge extends StatelessWidget {
  const _AmenityBadge({
    required this.icon,
    required this.label,
    required this.available,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final foreground = available ? Colors.green.shade800 : Colors.red.shade800;
    final background = available ? Colors.green.shade50 : Colors.red.shade50;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenityDetail extends StatelessWidget {
  const _AmenityDetail({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    this.secondary,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 22, color: iconColor),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (secondary != null)
                Text(
                  secondary!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});

  final String text;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          maxLines: 7,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 7,
              overflow: _expanded ? null : TextOverflow.fade,
              style: style?.copyWith(height: 1.5),
            ),
            if (overflows)
              TextButton.icon(
                key: const Key('venue-description-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? AppIcons.arrowUpward : AppIcons.arrowDownward,
                  size: 16,
                ),
                label: Text(
                  _expanded ? l10n.venueReadLess : l10n.venueReadMore,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.priceBooks});

  final AsyncValue<List<VenuePriceBook>> priceBooks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      key: const Key('venue-pricing-card'),
      title: l10n.venuePricing,
      children: [
        priceBooks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(l10n.venuePriceLoadError),
          data: (books) {
            final book = activeVenuePriceBook(books);
            if (book == null || book.rules.isEmpty) {
              return Text(
                l10n.venueNoPricing,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              );
            }
            final groups = _pricingGroups(book.rules, l10n);
            if (groups.isEmpty) {
              return Text(
                l10n.venueNoPricing,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              );
            }
            return Column(
              children: [
                for (
                  var groupIndex = 0;
                  groupIndex < groups.length;
                  groupIndex++
                ) ...[
                  if (groupIndex > 0) const SizedBox(height: AppSpacing.sm),
                  _PricingGroupCard(group: groups[groupIndex]),
                ],
                if (book.notes?.trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(book.notes!),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PricingGroup {
  const _PricingGroup(this.day, this.daySort, this.rows);
  final String day;
  final int daySort;
  final List<_PricingRow> rows;
}

class _PricingRow {
  const _PricingRow({
    required this.time,
    required this.startMinute,
    this.fixed,
    this.walkIn,
  });
  final String time;
  final int startMinute;
  final int? fixed;
  final int? walkIn;
}

List<_PricingGroup> _pricingGroups(
  List<VenuePriceRule> rules,
  AppLocalizations l10n,
) {
  final grouped = <String, (int, Map<String, _PricingRow>)>{};
  for (final rule in rules) {
    if (rule.customerType != 'FIXED' && rule.customerType != 'WALK_IN') {
      continue;
    }
    final day = _dayLabel(rule, l10n);
    final time = '${_time(rule.startMinute)} - ${_time(rule.endMinute)}';
    final group = grouped.putIfAbsent(
      day,
      () => (_daySort(rule), <String, _PricingRow>{}),
    );
    final current = group.$2[time];
    group.$2[time] = _PricingRow(
      time: time,
      startMinute: rule.startMinute,
      fixed: rule.customerType == 'FIXED' ? rule.pricePerHour : current?.fixed,
      walkIn: rule.customerType == 'WALK_IN'
          ? rule.pricePerHour
          : current?.walkIn,
    );
  }
  final groups = grouped.entries.map((entry) {
    final rows = entry.value.$2.values.toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return _PricingGroup(entry.key, entry.value.$1, rows);
  }).toList()..sort((a, b) => a.daySort.compareTo(b.daySort));
  return groups;
}

class _PricingGroupCard extends StatelessWidget {
  const _PricingGroupCard({required this.group});

  final _PricingGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Text(
              group.day,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (var index = 0; index < group.rows.length; index++)
            Container(
              key: ValueKey('venue-price-row-${group.day}-$index'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: index == 0
                    ? null
                    : Border(top: BorderSide(color: palette.border)),
              ),
              child: _PricingLine(row: group.rows[index], l10n: l10n),
            ),
        ],
      ),
    );
  }
}

class _PricingLine extends StatelessWidget {
  const _PricingLine({required this.row, required this.l10n});
  final _PricingRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final same = row.fixed != null && row.fixed == row.walkIn;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.time,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (same)
          Text(
            '${_money(row.fixed!)} đ',
            key: const Key('venue-price-collapsed-rate'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (row.fixed != null)
                Text('${l10n.venueFixedCustomer}: ${_money(row.fixed!)} đ'),
              if (row.walkIn != null)
                Text('${l10n.venueWalkInCustomer}: ${_money(row.walkIn!)} đ'),
            ],
          ),
      ],
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) => _SectionCard(
    key: const Key('venue-photos-card'),
    title: AppLocalizations.of(context).venuePhotos,
    children: [
      LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          key: const Key('venue-photo-grid'),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: venue.images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 600 ? 3 : 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (context, index) => InkWell(
            onTap: () => unawaited(
              showAppLightbox(
                context,
                images: venue.images,
                initialIndex: index,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: CachedNetworkImage(
                imageUrl: venue.images[index],
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.onRequestUpdate});

  final VoidCallback onRequestUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Align(
      key: const Key('venue-contribution-card'),
      child: TextButton.icon(
        key: const Key('venue-request-update-button'),
        onPressed: onRequestUpdate,
        style: TextButton.styleFrom(foregroundColor: palette.mutedForeground),
        icon: const Icon(AppIcons.edit, size: 16),
        label: Text(l10n.venueRequestUpdate),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class VenueDetailBottomBar extends StatelessWidget {
  const VenueDetailBottomBar({
    required this.phone,
    required this.website,
    required this.onCall,
    required this.onZalo,
    required this.onWebsite,
    required this.onFindSessions,
    super.key,
  });

  final String? phone;
  final String? website;
  final VoidCallback onCall;
  final VoidCallback onZalo;
  final VoidCallback onWebsite;
  final VoidCallback onFindSessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasPhone = phone?.trim().isNotEmpty ?? false;
                  final hasWebsite = website?.trim().isNotEmpty ?? false;

                  final actionButtons = <Widget>[
                    if (hasPhone) ...[
                      IconButton.outlined(
                        key: const Key('venue-call-button'),
                        tooltip: l10n.venueCallNow,
                        onPressed: onCall,
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          minimumSize: const Size.square(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        icon: const Icon(AppIcons.phone, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.outlined(
                        key: const Key('venue-zalo-bottom-button'),
                        tooltip: l10n.venueZalo,
                        onPressed: onZalo,
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          minimumSize: const Size.square(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        icon: const Image(
                          image: AssetImage('assets/icons/zalo.png'),
                          width: 21,
                          height: 21,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (hasWebsite) ...[
                      IconButton.outlined(
                        key: const Key('venue-website-bottom-button'),
                        tooltip: l10n.tournamentDetailOpenWebsite,
                        onPressed: onWebsite,
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          minimumSize: const Size.square(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                        icon: const Icon(AppIcons.language, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('venue-find-sessions-button'),
                        onPressed: onFindSessions,
                        icon: const Icon(AppIcons.search),
                        label: Text(
                          l10n.venueFindSessions,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ];

                  return Row(
                    children: [
                      ...actionButtons,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

VenuePriceBook? activeVenuePriceBook(List<VenuePriceBook> values) {
  final active =
      values
          .where(
            (book) =>
                book.isActive &&
                !(book.notes?.trimLeft().startsWith('Tự động tạo từ') ?? false),
          )
          .toList()
        ..sort((a, b) {
          final priority = b.priority.compareTo(a.priority);
          if (priority != 0) return priority;
          return b.effectiveFrom.compareTo(a.effectiveFrom);
        });
  return active.isEmpty ? null : active.first;
}

int? minimumVenuePrice(List<VenuePriceBook> values) {
  final rules =
      (activeVenuePriceBook(values)?.rules ?? const <VenuePriceRule>[])
          .where(
            (rule) =>
                rule.customerType == 'FIXED' || rule.customerType == 'WALK_IN',
          )
          .toList();
  if (rules.isEmpty) return null;
  return rules
      .map((rule) => rule.pricePerHour)
      .reduce(
        (current, value) => value < current ? value : current,
      );
}

String _dayLabel(VenuePriceRule rule, AppLocalizations l10n) =>
    switch (rule.dayType) {
      'EVERYDAY' => l10n.venueEveryDay,
      'WEEKEND' => l10n.venueWeekend,
      'WEEKDAY' => _weekdayRangeLabel(rule.daysOfWeek, l10n),
      'HOLIDAY' => l10n.venueHoliday,
      'SPECIFIC_DATE' => _specificDateLabel(rule.specificDate, l10n),
      _ => l10n.venueOtherDay,
    };

String _weekdayRangeLabel(List<int> values, AppLocalizations l10n) {
  final days = values.toSet().toList()..sort();
  final key = days.join(',');
  return switch (key) {
    '' => l10n.venueBySchedule,
    '1,2,3,4,5' => l10n.venueWeekday,
    '6,7' => l10n.venueWeekend,
    '1,2,3,4,5,6,7' => l10n.venueEveryDay,
    _ => days.map((day) => l10n.venueWeekdayShort('$day')).join(', '),
  };
}

String _specificDateLabel(String? value, AppLocalizations l10n) {
  final date = DateTime.tryParse(value ?? '');
  return date == null
      ? l10n.venueOtherDay
      : DateFormat.yMd(l10n.localeName).format(date);
}

int _daySort(VenuePriceRule rule) => switch (rule.dayType) {
  'EVERYDAY' => 0,
  'WEEKDAY' =>
    rule.daysOfWeek.isEmpty
        ? 1
        : rule.daysOfWeek.reduce((a, b) => a < b ? a : b),
  'WEEKEND' => 6,
  'HOLIDAY' => 8,
  _ => 9,
};

String _time(int minutes) =>
    '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : (minutes % 60).toString().padLeft(2, '0')}';

String _money(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

String _plainText(String? html) => (html ?? '')
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
