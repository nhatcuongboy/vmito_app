import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/host_detail_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _gold = Color(0xFFFBBF24);
const _emptyStar = Color(0xFFE5E7EB);
const _zaloBlue = Color(0xFF0068FF);
const _cardRadius = 16.0;

/// Everything below the host sheet's gradient hero.
class SessionHostDetailBody extends StatelessWidget {
  const SessionHostDetailBody({
    required this.stats,
    required this.phone,
    required this.allowZaloContact,
    required this.onOpenProfile,
    this.onMessage,
    super.key,
  });

  final AsyncValue<HostDetailStats> stats;
  final String? phone;
  final bool allowZaloContact;
  final VoidCallback onOpenProfile;

  /// In-app chat with the host. Unlike call/Zalo this needs no phone number,
  /// so it can show even when [phone] is null.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final value = stats.asData?.value;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value != null) ...[
            _StatsCard(stats: value),
            const SizedBox(height: AppSpacing.md),
          ],
          _RatingCard(stats: value, isLoading: stats.isLoading),
          if (phone != null || onMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Actions(
              phone: phone,
              allowZaloContact: allowZaloContact,
              onMessage: onMessage,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _ViewProfileButton(onPressed: onOpenProfile),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final HostDetailStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return _Card(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              value: '${stats.hostedSessions}',
              label: AppLocalizations.of(context).sessionHostTotalHosted,
            ),
          ),
          Container(width: 1, height: 56, color: palette.border),
          Expanded(
            child: _StatColumn(
              key: const Key('host-detail-open-sessions'),
              value: '${stats.openSessions}',
              label: AppLocalizations.of(context).sessionHostOpenSessions,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    this.color,
    super.key,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.1,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.stats, required this.isLoading});

  final HostDetailStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 22, color: _gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.sessionHostRating,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (stats?.isTrusted ?? false) const _TrustedBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isLoading)
            const _RatingPlaceholder()
          else if (stats case final stats? when stats.hasRating)
            _RatingValue(stats: stats)
          else
            const _NoRating(),
        ],
      ),
    );
  }
}

class _TrustedBadge extends StatelessWidget {
  const _TrustedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      key: const Key('host-detail-trusted-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        AppLocalizations.of(context).sessionHostTrusted,
        style: theme.textTheme.labelMedium?.copyWith(
          color: primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RatingValue extends StatelessWidget {
  const _RatingValue({required this.stats});

  final HostDetailStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final filled = stats.averageRating.round();

    return Column(
      children: [
        Text(
          stats.averageRating.toStringAsFixed(1),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                Icons.star_rounded,
                size: 22,
                color: star <= filled ? _gold : _emptyStar,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          AppLocalizations.of(
            context,
          ).sessionHostRatingCount(stats.totalRatings),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _NoRating extends StatelessWidget {
  const _NoRating();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: palette.muted,
          child: Icon(
            Icons.star_rounded,
            size: 26,
            color: palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          l10n.sessionHostNoRatingTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.sessionHostNoRatingBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _RatingPlaceholder extends StatelessWidget {
  const _RatingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<AppPalette>()!.muted;

    return Column(
      children: [
        for (final size in const [Size(88, 40), Size(140, 20), Size(180, 16)])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.phone,
    required this.allowZaloContact,
    this.onMessage,
  });

  final String? phone;
  final bool allowZaloContact;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = this.phone;
    final showZalo = allowZaloContact && phone != null;

    return Column(
      children: [
        Row(
          children: [
            if (phone != null)
              Expanded(
                child: _ActionButton(
                  key: const Key('host-detail-call'),
                  icon: const Icon(AppIcons.phone, size: 18),
                  label: l10n.sessionHostCall,
                  background: AppColors.success,
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                ),
              ),
            if (onMessage != null) ...[
              if (phone != null) const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  key: const Key('host-detail-message'),
                  icon: const Icon(AppIcons.send, size: 18),
                  label: l10n.chatMessageButton,
                  background: AppColors.info,
                  onPressed: onMessage!,
                ),
              ),
            ],
          ],
        ),
        if (showZalo) ...[
          const SizedBox(height: 12),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.6,
              child: _ActionButton(
                key: const Key('host-detail-zalo'),
                icon: const Icon(AppIcons.chat, size: 18),
                label: l10n.sessionHostZalo,
                background: _zaloBlue,
                onPressed: () => launchUrl(
                  _zaloUri(phone),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Zalo deep links take the country code, not the leading zero.
Uri _zaloUri(String phone) =>
    Uri.parse('https://zalo.me/${phone.replaceFirst(RegExp('^0'), '84')}');

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('host-detail-view-profile'),
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(AppIcons.chevronRight, size: 18),
      label: Text(AppLocalizations.of(context).sessionViewDetails),
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: Theme.of(context).colorScheme.primary,
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
