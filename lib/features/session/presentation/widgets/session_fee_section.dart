import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Session pricing.
///
/// Every amount goes through [Money.vnd]: VND is an integer currency with no
/// minor unit, and interpolating the raw value renders `90000` or `90000.0`.
class SessionFeeSection extends StatelessWidget {
  const SessionFeeSection({required this.feeConfig, super.key});

  final SessionFeeConfig feeConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.feeTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (feeConfig.isUnpriced)
          Text(
            feeConfig.isSplitEvenly ? l10n.feeSplitLater : l10n.feeNotSet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.mutedForeground,
            ),
          )
        else if (feeConfig.isSplitEvenly) ...[
          if (feeConfig.splitPerPlayer case final perPlayer?)
            _FeeRow(label: l10n.feePerPerson, amount: perPlayer),
          if (feeConfig.splitTotal case final total?)
            _FeeRow(label: l10n.feeTotal, amount: total),
        ] else if (feeConfig.hasSingleFixedPrice)
          // Both genders pay the same — showing two identical rows reads as a
          // mistake.
          _FeeRow(label: l10n.feePerPerson, amount: feeConfig.maleFee!)
        else ...[
          if (feeConfig.maleFee case final fee?)
            _FeeRow(label: l10n.feeMale, amount: fee),
          if (feeConfig.femaleFee case final fee?)
            _FeeRow(label: l10n.feeFemale, amount: fee),
        ],
        if (feeConfig.notes case final notes? when notes.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              notes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
          Text(
            Money.vnd(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
