import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Title, schedule, place and host — the top of the web app's
/// `SessionDetailBody`.
class SessionDetailInfo extends StatelessWidget {
  const SessionDetailInfo({
    required this.session,
    required this.onOpenMap,
    required this.onCallHost,
    required this.onZaloHost,
    super.key,
  });

  final Session session;
  final VoidCallback? onOpenMap;
  final VoidCallback? onCallHost;
  final VoidCallback? onZaloHost;

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
          session.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        if (time != null || date != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ScheduleRow(time: time, date: date),
        ],
        if (session.displayPlace.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _LocationRow(session: session, onOpenMap: onOpenMap),
        ],
        Divider(height: AppSpacing.lg * 2, color: palette.border),
        _HostRow(
          session: session,
          onCall: onCallHost,
          onZalo: onZaloHost,
        ),
        if (session.description case final text? when text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _DescriptionCard(text: text.trim()),
          ),
      ],
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

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.session, required this.onOpenMap});

  final Session session;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    final venueName = session.venue?.name?.trim();
    final title = venueName == null || venueName.isEmpty
        ? session.displayPlace
        : venueName;
    final address = session.venue?.displayAddress;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.location, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Suppress an address that just repeats the venue name.
              if (address != null && address != title)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (onOpenMap != null)
          IconButton(
            tooltip: l10n.sessionGetDirections,
            icon: const Icon(AppIcons.navigation, size: 20),
            color: theme.colorScheme.primary,
            onPressed: onOpenMap,
          ),
      ],
    );
  }
}

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.session,
    required this.onCall,
    required this.onZalo,
  });

  final Session session;
  final VoidCallback? onCall;
  final VoidCallback? onZalo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final image = session.host?.image;
    final name = session.displayHostName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: palette.muted,
            foregroundImage: image == null || image.trim().isEmpty
                ? null
                : CachedNetworkImageProvider(image),
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge,
            ),
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
                      ? (session.externalSource ?? l10n.sessionHostLabel)
                      : l10n.sessionHostLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (onZalo != null)
            _ContactButton(
              tooltip: l10n.sessionContactZalo,
              icon: AppIcons.chat,
              onPressed: onZalo!,
            ),
          if (onCall != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _ContactButton(
              tooltip: l10n.sessionCallHost,
              icon: AppIcons.phone,
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
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(52),
        foregroundColor: primary,
        backgroundColor: primary.withValues(alpha: 0.1),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
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
