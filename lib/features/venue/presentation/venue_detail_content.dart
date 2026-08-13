import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

class VenueDetailContent extends StatefulWidget {
  const VenueDetailContent({
    required this.venue,
    required this.priceBooks,
    required this.onBack,
    required this.onShare,
    required this.onCall,
    required this.onWebsite,
    required this.onZalo,
    required this.onDirections,
    required this.onFindSessions,
    required this.onRequestUpdate,
    required this.onPriceCorrection,
    required this.onImageCorrection,
    super.key,
  });

  final Venue venue;
  final AsyncValue<List<VenuePriceBook>> priceBooks;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onCall;
  final VoidCallback onWebsite;
  final VoidCallback onZalo;
  final VoidCallback onDirections;
  final VoidCallback onFindSessions;
  final VoidCallback onRequestUpdate;
  final VoidCallback onPriceCorrection;
  final VoidCallback onImageCorrection;

  @override
  State<VenueDetailContent> createState() => _VenueDetailContentState();
}

class _VenueDetailContentState extends State<VenueDetailContent> {
  static const _heroHeight = 260.0;
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
              widget.venue.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          actions: [
            FavoriteButton(
              type: FavoriteType.venue,
              targetId: widget.venue.id,
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
                      onWebsite: widget.onWebsite,
                      onZalo: widget.onZalo,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AboutCard(venue: widget.venue),
                    const SizedBox(height: AppSpacing.md),
                    _PricingCard(priceBooks: widget.priceBooks),
                    if (widget.venue.images.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _PhotosCard(venue: widget.venue),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _LocationCard(
                      venue: widget.venue,
                      onDirections: widget.onDirections,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ContributionCard(
                      onRequestUpdate: widget.onRequestUpdate,
                      onPriceCorrection: widget.onPriceCorrection,
                      onImageCorrection: widget.onImageCorrection,
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
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, color: pinned ? null : Colors.white),
    style: IconButton.styleFrom(
      backgroundColor: pinned ? Colors.transparent : Colors.black54,
      minimumSize: const Size.square(44),
    ),
    onPressed: onPressed,
  );
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
          ColoredBox(color: Theme.of(context).colorScheme.primaryContainer)
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
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons/app-logo-96.png', width: 20),
                  const SizedBox(width: 6),
                  const Text(
                    'Vmito',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
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
              if (widget.venue.isVerified)
                _StatusBadge(
                  key: const Key('venue-verified-badge'),
                  icon: AppIcons.verified,
                  label: l10n.venueVerified,
                  color: Colors.green,
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
    super.key,
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
    required this.onWebsite,
    required this.onZalo,
  });

  final Venue venue;
  final VoidCallback onWebsite;
  final VoidCallback onZalo;

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
                    venue.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            if (venue.addressLabel.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.location,
                    size: 19,
                    color: palette.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      venue.distance == null
                          ? venue.addressLabel
                          : '${venue.addressLabel} (${l10n.venueDistance(venue.distance!)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
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
            if ((venue.website?.trim().isNotEmpty ?? false) ||
                (venue.phone?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: palette.border),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (venue.phone?.trim().isNotEmpty ?? false)
                    OutlinedButton.icon(
                      key: const Key('venue-zalo-button'),
                      onPressed: onZalo,
                      icon: const Icon(AppIcons.chat),
                      label: Text(l10n.venueZalo),
                    ),
                  if (venue.website?.trim().isNotEmpty ?? false)
                    OutlinedButton.icon(
                      key: const Key('venue-website-button'),
                      onPressed: onWebsite,
                      icon: const Icon(AppIcons.language),
                      label: Text(l10n.venueWebsite),
                    ),
                ],
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
        if (venue.amenities.isNotEmpty) ...[
          Divider(height: AppSpacing.xl, color: palette.border),
          Text(
            l10n.venueAmenities,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: venue.amenities
                .map((amenity) => Chip(label: Text(amenity)))
                .toList(growable: false),
          ),
        ],
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
              return Text(l10n.venueNoPricing);
            }
            final groups = _pricingGroups(book.rules, l10n);
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
  const _PricingGroup(this.day, this.rows);
  final String day;
  final List<_PricingRow> rows;
}

class _PricingRow {
  const _PricingRow({required this.time, this.fixed, this.walkIn});
  final String time;
  final int? fixed;
  final int? walkIn;
}

List<_PricingGroup> _pricingGroups(
  List<VenuePriceRule> rules,
  AppLocalizations l10n,
) {
  final grouped = <String, Map<String, (int?, int?)>>{};
  for (final rule in rules) {
    final day = _dayLabel(rule, l10n);
    final time = '${_time(rule.startMinute)} – ${_time(rule.endMinute)}';
    final current = grouped.putIfAbsent(day, () => {})[time] ?? (null, null);
    grouped[day]![time] = rule.customerType == 'FIXED'
        ? (rule.pricePerHour, current.$2)
        : (current.$1, rule.pricePerHour);
  }
  return grouped.entries
      .map(
        (entry) => _PricingGroup(
          entry.key,
          entry.value.entries
              .map(
                (row) => _PricingRow(
                  time: row.key,
                  fixed: row.value.$1,
                  walkIn: row.value.$2,
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
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
            '${_money(row.fixed!)}đ',
            key: const Key('venue-price-collapsed-rate'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (row.fixed != null)
                Text('${l10n.venueFixedCustomer}: ${_money(row.fixed!)}đ'),
              if (row.walkIn != null)
                Text('${l10n.venueWalkInCustomer}: ${_money(row.walkIn!)}đ'),
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.venue, required this.onDirections});
  final Venue venue;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) => _SectionCard(
    key: const Key('venue-location-card'),
    title: AppLocalizations.of(context).venueMap,
    children: [
      if (venue.addressLabel.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.location),
          title: Text(venue.addressLabel),
        ),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('venue-directions-button'),
          onPressed: onDirections,
          icon: const Icon(AppIcons.externalLink),
          label: Text(AppLocalizations.of(context).venueGoogleMaps),
        ),
      ),
    ],
  );
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.onRequestUpdate,
    required this.onPriceCorrection,
    required this.onImageCorrection,
  });

  final VoidCallback onRequestUpdate;
  final VoidCallback onPriceCorrection;
  final VoidCallback onImageCorrection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      key: const Key('venue-contribution-card'),
      title: l10n.venueUpdateInfo,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: onRequestUpdate,
              icon: const Icon(AppIcons.edit),
              label: Text(l10n.venueRequestUpdate),
            ),
            OutlinedButton.icon(
              onPressed: onPriceCorrection,
              icon: const Icon(AppIcons.priceTag),
              label: Text(l10n.venueSendPricePhoto),
            ),
            OutlinedButton.icon(
              onPressed: onImageCorrection,
              icon: const Icon(AppIcons.imagePlus),
              label: Text(l10n.venueSendPhotos),
            ),
          ],
        ),
      ],
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
    required this.minimumPrice,
    required this.onCall,
    required this.onFindSessions,
    super.key,
  });

  final String? phone;
  final int? minimumPrice;
  final VoidCallback onCall;
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
              child: Row(
                children: [
                  if (minimumPrice != null)
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: l10n.venuePriceFrom(_money(minimumPrice!)),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: ' ${l10n.venuePerHour}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (minimumPrice != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (phone?.trim().isNotEmpty ?? false) ...[
                    IconButton.outlined(
                      key: const Key('venue-call-button'),
                      tooltip: l10n.venueCallNow,
                      onPressed: onCall,
                      icon: const Icon(AppIcons.phone),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
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
        ..sort((a, b) => b.priority.compareTo(a.priority));
  return active.isEmpty ? null : active.first;
}

int? minimumVenuePrice(List<VenuePriceBook> values) {
  final rules = activeVenuePriceBook(values)?.rules ?? const <VenuePriceRule>[];
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
      'WEEKDAY' => l10n.venueWeekday,
      _ => l10n.venueBySchedule,
    };

String _time(int minutes) =>
    '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : (minutes % 60).toString().padLeft(2, '0')}';

String _money(int value) => value.toString().replaceAllMapped(
  RegExp(r'(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

String _plainText(String? html) => (html ?? '')
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
