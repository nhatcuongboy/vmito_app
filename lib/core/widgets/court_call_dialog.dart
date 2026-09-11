import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/court_call_info_card.dart';
import 'package:vmito_app/core/widgets/court_call_pulse_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Ported from `vmito-fe`'s `CourtCallModal.tsx`: a pulsing map-pin badge,
/// the court name, a short description, and a single acknowledge CTA.
///
/// [sessionName], [venueAddress], and [hostName] are a mobile-only addition
/// (the web modal omits them) so a player who isn't currently looking at
/// that session can tell which one it is without leaving the dialog.
///
/// Non-dismissible by design — the web version blocks backdrop-tap only
/// (`closeOnOverlayClick={false}`); this also blocks the Android back button
/// via [PopScope], since a hardware back button has no web equivalent and
/// the whole point of the call is that it must be acted on.
class CourtCallDialog extends StatelessWidget {
  const CourtCallDialog({
    required this.courtDisplayName,
    required this.onAcknowledge,
    this.sessionName,
    this.venueAddress,
    this.hostName,
    super.key,
  });

  final String courtDisplayName;
  final VoidCallback onAcknowledge;
  final String? sessionName;
  final String? venueAddress;
  final String? hostName;

  static Future<void> show(
    BuildContext context, {
    required String courtDisplayName,
    required VoidCallback onAcknowledge,
    String? sessionName,
    String? venueAddress,
    String? hostName,
  }) {
    unawaited(HapticFeedback.mediumImpact());
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: CourtCallDialog(
          courtDisplayName: courtDisplayName,
          onAcknowledge: onAcknowledge,
          sessionName: sessionName,
          venueAddress: venueAddress,
          hostName: hostName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.brandDark : colorScheme.primary;
    final hasInfo =
        sessionName != null || venueAddress != null || hostName != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.courtCallTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const CourtCallPulseBadge(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.courtCallGoToCourt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                courtDisplayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  l10n.courtCallDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              if (hasInfo) ...[
                const SizedBox(height: AppSpacing.md),
                CourtCallInfoCard(
                  sessionName: sessionName,
                  venueAddress: venueAddress,
                  hostName: hostName == null
                      ? null
                      : '${l10n.sessionHostLabel}: $hostName',
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAcknowledge();
                  },
                  icon: const Icon(AppIcons.navigation, size: 18),
                  label: Text(l10n.courtCallAcknowledge),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md - 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
