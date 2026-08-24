import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Detailed, read-only fee view opened from the sticky session action bar.
Future<void> showSessionFeeDetailDialog(
  BuildContext context, {
  required SessionFeeConfig feeConfig,
}) => showDialog<void>(
  context: context,
  builder: (context) => _SessionFeeDetailDialog(feeConfig: feeConfig),
);

class _SessionFeeDetailDialog extends StatelessWidget {
  const _SessionFeeDetailDialog({required this.feeConfig});

  final SessionFeeConfig feeConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final isFixed = !feeConfig.isSplitEvenly;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.feeTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(AppIcons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _FeeTypeBadge(isFixed: isFixed),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: palette.border),
              ),
              if (isFixed)
                _FixedFeeRow(feeConfig: feeConfig)
              else
                _SplitFeeCard(feeConfig: feeConfig),
              if (feeConfig.notes case final notes?
                  when notes.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _NotesCard(notes: notes.trim()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeTypeBadge extends StatelessWidget {
  const _FeeTypeBadge({required this.isFixed});

  final bool isFixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = isFixed ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFixed ? AppIcons.dollarCircle : AppIcons.calculator,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            (isFixed ? l10n.feeFixed : l10n.feeSplitLater).toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedFeeRow extends StatelessWidget {
  const _FixedFeeRow({required this.feeConfig});

  final SessionFeeConfig feeConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (feeConfig.isUnpriced) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            l10n.feeNotSet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ),
      );
    }

    final maleCard = _FeeAmountCard(
      icon: AppIcons.male,
      label: l10n.feeMale,
      amount: feeConfig.maleFee,
      color: const Color(0xFF2563EB),
      background: const Color(0xFFEFF6FF),
      borderColor: const Color(0xFFDBEAFE),
      priceColor: const Color(0xFF0F172A),
    );

    final femaleCard = _FeeAmountCard(
      icon: AppIcons.female,
      label: l10n.feeFemale,
      amount: feeConfig.femaleFee,
      color: const Color(0xFFDB2777),
      background: const Color(0xFFFDF2F8),
      borderColor: const Color(0xFFFCE7F3),
      priceColor: const Color(0xFF4A044E),
    );

    if (feeConfig.maleFee != null && feeConfig.femaleFee != null) {
      return Row(
        children: [
          Expanded(child: maleCard),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: femaleCard),
        ],
      );
    }

    if (feeConfig.maleFee != null) {
      return maleCard;
    }

    return femaleCard;
  }
}

class _FeeAmountCard extends StatelessWidget {
  const _FeeAmountCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    required this.background,
    required this.borderColor,
    required this.priceColor,
  });

  final IconData icon;
  final String label;
  final int? amount;
  final Color color;
  final Color background;
  final Color borderColor;
  final Color priceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            amount == null ? l10n.feeNotSet : Money.vnd(amount!),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: priceColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitFeeCard extends StatelessWidget {
  const _SplitFeeCard({required this.feeConfig});

  final SessionFeeConfig feeConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    if (feeConfig.isUnpriced) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            l10n.feeSplitLater,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.calculator, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.feeSplitLater,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (feeConfig.splitPerPlayer case final perPlayer?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('${l10n.feePerPerson}: ${Money.vnd(perPlayer)}'),
                ],
                if (feeConfig.splitTotal case final total?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('${l10n.feeTotal}: ${Money.vnd(total)}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: const Color(0xFF16A34A),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md - 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.notes,
                          size: 16,
                          color: palette.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.xs + 4),
                        Text(
                          l10n.feeNotes.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.mutedForeground,
                            fontWeight: FontWeight.bold,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
