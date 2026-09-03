import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Floating player tooltip on the badminton court.
///
/// Ports `vmito-fe/src/components/court/PlayerTooltip.tsx`.
class CourtPlayerTooltipOverlay extends StatelessWidget {
  const CourtPlayerTooltipOverlay({
    required this.player,
    required this.pairNumber,
    required this.targetRect,
    required this.onDismiss,
    super.key,
  });

  final SessionPlayer player;
  final int pairNumber;
  final Rect targetRect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);

    const cardWidth = 268.0;
    const cardHeight = 175.0;
    const arrowWidth = 14.0;
    const arrowHeight = 7.0;
    const gap = 6.0;
    const viewportPadding = 12.0;

    final fitsAbove = targetRect.top - (cardHeight + arrowHeight + gap) >=
        viewPadding.top + viewportPadding;

    final double cardTop;
    final bool pointingUp;

    if (fitsAbove) {
      pointingUp = false;
      cardTop = targetRect.top - gap - arrowHeight - cardHeight;
    } else {
      pointingUp = true;
      cardTop = targetRect.bottom + gap;
    }

    final cardLeft = (targetRect.center.dx - cardWidth / 2).clamp(
      viewportPadding,
      screenSize.width - cardWidth - viewportPadding,
    );

    final arrowLeft = (targetRect.center.dx - arrowWidth / 2).clamp(
      cardLeft + 16.0,
      cardLeft + cardWidth - 16.0 - arrowWidth,
    );

    final cardBg = theme.colorScheme.surface;
    final borderColor = palette.border;
    final pairColors = _pairBadgeColors(pairNumber, theme.brightness);
    final playerName = l10n.playerName(player);
    final pairLabel = l10n.courtPair(pairNumber);
    final level = player.level;
    final levelLabel = level != null ? (levelShortLabel(level) ?? 'N/A') : 'N/A';

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: cardWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, animValue, child) {
              final dy = (1.0 - animValue) * 4.0;
              return Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: animValue,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pointingUp)
                    Padding(
                      padding: EdgeInsets.only(left: arrowLeft - cardLeft),
                      child: CustomPaint(
                        size: const Size(arrowWidth, arrowHeight),
                        painter: _TooltipArrowPainter(
                          pointingUp: true,
                          color: cardBg,
                          borderColor: borderColor,
                        ),
                      ),
                    ),
                  Container(
                    key: const Key('court-player-tooltip-card'),
                    width: cardWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: theme.brightness == Brightness.light
                                ? 0.14
                                : 0.4,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: theme.brightness == Brightness.light
                                ? 0.06
                                : 0.2,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (player.playerNumber != null) ...[
                                    Text(
                                      '#${player.playerNumber}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: palette.mutedForeground,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    playerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pairColors.background,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: pairColors.border,
                                ),
                              ),
                              child: Text(
                                pairLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pairColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          color: palette.border,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _TooltipInfoCell(
                                label: l10n.courtTooltipGender.toUpperCase(),
                                value: l10n.playerGender(player.gender),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TooltipInfoCell(
                                label: l10n.courtTooltipLevel.toUpperCase(),
                                value: levelLabel,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TooltipInfoCell(
                                label: l10n.courtTooltipMatchesPlayed
                                    .toUpperCase(),
                                value: '${player.matchesPlayed}',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _TooltipInfoCell(
                                label: l10n.courtTooltipWaitTime
                                    .toUpperCase(),
                                value: l10n.formatWaitTime(
                                  player.currentWaitTime,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!pointingUp)
                    Padding(
                      padding: EdgeInsets.only(left: arrowLeft - cardLeft),
                      child: CustomPaint(
                        size: const Size(arrowWidth, arrowHeight),
                        painter: _TooltipArrowPainter(
                          pointingUp: false,
                          color: cardBg,
                          borderColor: borderColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TooltipInfoCell extends StatelessWidget {
  const _TooltipInfoCell({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.mutedForeground,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PairBadgeColors {
  const _PairBadgeColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

_PairBadgeColors _pairBadgeColors(int pairNumber, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  if (pairNumber == 1) {
    return isLight
        ? const _PairBadgeColors(
            background: Color(0xFFEFF6FF),
            border: Color(0xFF3B82F6),
            text: Color(0xFF1D4ED8),
          )
        : const _PairBadgeColors(
            background: Color(0xFF172554),
            border: Color(0xFF3B82F6),
            text: Color(0xFF93C5FD),
          );
  } else {
    return isLight
        ? const _PairBadgeColors(
            background: Color(0xFFFFF7ED),
            border: Color(0xFFF97316),
            text: Color(0xFFC2410C),
          )
        : const _PairBadgeColors(
            background: Color(0xFF431407),
            border: Color(0xFFF97316),
            text: Color(0xFFFDBA74),
          );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter({
    required this.pointingUp,
    required this.color,
    required this.borderColor,
  });

  final bool pointingUp;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    if (pointingUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, fillPaint);

      final borderPath = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
      canvas.drawPath(borderPath, borderPaint);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
      canvas.drawPath(path, fillPaint);

      final borderPath = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) =>
      oldDelegate.pointingUp != pointingUp ||
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor;
}
