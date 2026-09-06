import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_address_text.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';

@Preview(
  name: 'Session detail overview',
  group: 'Sessions',
  size: Size(390, 640),
)
Widget sessionDetailInfoPreview() => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SessionDetailInfo(
        session: Session(
          id: 'preview-session',
          name: 'Buổi cầu lông tối nay',
          status: SessionStatus.preparing,
          startTime: DateTime(2026, 8, 28, 18),
          scheduledEndTime: DateTime(2026, 8, 28, 20),
          venue: const SessionVenue(
            id: 'preview-venue',
            name: 'AKA Badminton Center',
            address: '730/4 Hương Lộ 2, Phường Bình Trị Đông',
          ),
          host: const SessionHost(id: 'preview-host', name: 'Ngọc Trâm'),
        ),
        onOpenMap: null,
        onCallHost: null,
        onZaloHost: null,
        onOpenHost: null,
        onOpenOriginalPost: null,
      ),
    ),
  ),
);

/// Title, schedule, place and host — the top of the web app's
/// `SessionDetailBody`.
class SessionDetailInfo extends StatelessWidget {
  const SessionDetailInfo({
    required this.session,
    required this.onOpenMap,
    required this.onCallHost,
    required this.onZaloHost,
    required this.onOpenHost,
    required this.onOpenOriginalPost,
    super.key,
  });

  final Session session;
  final VoidCallback? onOpenMap;
  final VoidCallback? onCallHost;
  final VoidCallback? onZaloHost;
  final VoidCallback? onOpenHost;
  final VoidCallback? onOpenOriginalPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final time = sessionDetailTimeLabel(session, locale);
    final date = sessionDetailDateLabel(session, l10n, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('session-detail-title'),
          session.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        if (time != null || date != null) ...[
          const SizedBox(height: AppSpacing.md - AppSpacing.xs),
          _ScheduleRow(time: time, date: date),
        ],
        const SizedBox(height: AppSpacing.xs),
        _SportAndMatchTypeRow(session: session),
        if (session.hasLocation) ...[
          const SizedBox(height: AppSpacing.md),
          _LocationRow(session: session, onOpenMap: onOpenMap),
        ],
        Divider(height: AppSpacing.lg, color: palette.border),
        _HostRow(
          session: session,
          onCall: onCallHost,
          onZalo: onZaloHost,
          onOpenHost: onOpenHost,
          onOpenOriginalPost: onOpenOriginalPost,
        ),
        if (session.description case final text? when text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _DescriptionCard(text: text.trim()),
          ),
      ],
    );
  }
}

/// The session's configured sport and default court format.
///
/// This mirrors the compact metadata row on the web session detail page.
class _SportAndMatchTypeRow extends StatelessWidget {
  const _SportAndMatchTypeRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.extension<AppPalette>()!.mutedForeground;
    final l10n = AppLocalizations.of(context);
    final sport = switch (session.sportType) {
      SessionSportType.badminton => (
        icon: Image.asset(
          'assets/icons/shuttlecock.png',
          key: const Key('session-detail-sport-icon'),
          width: 18,
          height: 18,
        ),
        label: l10n.sessionSportBadminton,
      ),
      SessionSportType.pickleball => (
        icon: Icon(
          Icons.sports_tennis,
          key: const Key('session-detail-sport-icon'),
          size: 18,
          color: color,
        ),
        label: l10n.sessionSportPickleball,
      ),
    };
    final matchType = switch (session.defaultMatchType) {
      MatchType.singles => l10n.sessionFormSingles,
      MatchType.doubles => l10n.sessionFormDoubles,
    };
    final style = theme.textTheme.bodyLarge?.copyWith(color: color);

    return Semantics(
      label: '${sport.label}, $matchType',
      child: Row(
        children: [
          sport.icon,
          const SizedBox(width: AppSpacing.sm + 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: sport.label,
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '  ·  ',
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: matchType,
                    style: style,
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.time, required this.date});

  final String? time;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final base = theme.textTheme.bodyLarge?.copyWith(
      color: palette.mutedForeground,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AppIcons.calendarMonth,
          size: 20,
          color: palette.mutedForeground,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (time != null)
                  TextSpan(
                    text: time,
                    style: base?.copyWith(fontWeight: FontWeight.w600),
                  ),
                if (time != null && date != null)
                  TextSpan(
                    text: '  ·  ',
                    style: base?.copyWith(fontWeight: FontWeight.bold),
                  ),
                if (date != null) TextSpan(text: date),
              ],
            ),
            style: base,
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends ConsumerWidget {
  const _LocationRow({required this.session, required this.onOpenMap});

  final Session session;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;

    final venueName = session.venue?.name?.trim();
    final title = venueName == null || venueName.isEmpty
        ? session.displayPlace(showNewAddress: showNewAddress)
        : _sessionVenueDisplayName(venueName, l10n);
    final venue = session.venue;
    final hasAddress = [
      venue?.address,
      venue?.district,
      venue?.city,
      venue?.newAddress,
      venue?.newDistrict,
      venue?.newCity,
    ].any((value) => value?.trim().isNotEmpty ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.location, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      key: const Key('session-detail-venue-name'),
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onOpenMap != null)
                    IconButton(
                      key: const Key('session-get-directions'),
                      tooltip: l10n.sessionGetDirections,
                      icon: const Icon(AppIcons.navigation, size: 20),
                      color: theme.colorScheme.primary,
                      onPressed: onOpenMap,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(24),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              // Keep all administrative parts together and let
              // [AppAddressText] append the new-address badge when enabled.
              if (hasAddress)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppAddressText(
                    key: const Key('session-detail-address'),
                    address: venue?.address,
                    district: venue?.district,
                    city: venue?.city,
                    newAddress: venue?.newAddress,
                    newDistrict: venue?.newDistrict,
                    newCity: venue?.newCity,
                    maxLines: 2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _sessionVenueDisplayName(String name, AppLocalizations l10n) {
  final normalized = name.toLowerCase();
  final alreadyHasGenericAffix =
      normalized == 'sân' ||
      normalized.startsWith('sân ') ||
      normalized.startsWith('sân.') ||
      normalized.endsWith(' court') ||
      normalized.endsWith('场');
  return alreadyHasGenericAffix ? name : l10n.venueGenericName(name);
}

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.session,
    required this.onCall,
    required this.onZalo,
    required this.onOpenHost,
    required this.onOpenOriginalPost,
  });

  final Session session;
  final VoidCallback? onCall;
  final VoidCallback? onZalo;
  final VoidCallback? onOpenHost;
  final VoidCallback? onOpenOriginalPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final image = session.displayHostImage;
    final name = session.displayHostName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('session-detail-host-row'),
              // Imported Facebook sessions have no Vmito profile. Their
              // author, avatar and source-group label therefore all lead to
              // the one verified destination we have: the original post.
              onTap: onOpenHost ?? onOpenOriginalPost,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Row(
                children: [
                  UserAvatar(
                    name: name,
                    imageUrl: image,
                    size: 44,
                    borderColor: palette.muted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          session.isCrawled
                              ? (session.externalSource ??
                                    l10n.sessionHostLabel)
                              : l10n.sessionHostLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onZalo != null)
            _ContactButton(
              tooltip: l10n.sessionContactZalo,
              iconWidget: const Image(
                image: AssetImage('assets/icons/zalo.png'),
                width: 20,
                height: 20,
              ),
              onPressed: onZalo!,
            ),
          if (onCall != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _ContactButton(
              tooltip: l10n.sessionCallHost,
              iconWidget: const Icon(AppIcons.phone, size: 18),
              onPressed: onCall!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.tooltip,
    required this.iconWidget,
    required this.onPressed,
  });

  final String tooltip;
  final Widget iconWidget;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IconButton(
      tooltip: tooltip,
      icon: iconWidget,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(38),
        maximumSize: const Size.square(38),
        padding: EdgeInsets.zero,
        foregroundColor: primary,
        backgroundColor: primary.withValues(alpha: 0.12),
        side: BorderSide(color: primary.withValues(alpha: 0.35)),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// The host's note, in the web app's left-accented green panel.
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border(left: BorderSide(color: primary, width: 4)),
      ),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }
}
