import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Ported from `vmito-fe`'s `CourtCallModal.tsx`: a pulsing map-pin badge,
/// the court name, a short description, and a single acknowledge CTA.
///
/// Non-dismissible by design — the web version blocks backdrop-tap only
/// (`closeOnOverlayClick={false}`); this also blocks the Android back button
/// via [PopScope], since a hardware back button has no web equivalent and
/// the whole point of the call is that it must be acted on.
class CourtCallDialog extends StatefulWidget {
  const CourtCallDialog({
    required this.courtDisplayName,
    required this.onAcknowledge,
    super.key,
  });

  final String courtDisplayName;
  final VoidCallback onAcknowledge;

  static Future<void> show(
    BuildContext context, {
    required String courtDisplayName,
    required VoidCallback onAcknowledge,
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
        ),
      ),
    );
  }

  @override
  State<CourtCallDialog> createState() => _CourtCallDialogState();
}

class _CourtCallDialogState extends State<CourtCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    // Two 900ms half-cycles ease-in-out = the web's 1.8s courtCallPulse
    // keyframe (0% -> 50% -> 100%).
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_pulseController.repeat(reverse: true));
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final brandSurface = isDark
        ? const Color(0xFF183028)
        : const Color(0xFFE2F3E8);

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
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = _pulse.value;
                  return Transform.scale(
                    scale: 1 + 0.04 * t,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: brandSurface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: 0.18 * (1 - t),
                            ),
                            spreadRadius: 12 * t,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  AppIcons.mapPin,
                  size: 44,
                  color: isDark ? AppColors.brandDark : colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.courtCallGoToCourt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.brandDark : colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.courtDisplayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.brandDark : colorScheme.primary,
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
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onAcknowledge();
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
