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
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: _FeeTypeBadge(isFixed: isFixed),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Divider(color: palette.border),
              ),
              if (isFixed)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _FeeAmountCard(
                        icon: AppIcons.male,
                        label: l10n.feeMale,
                        amount: feeConfig.maleFee,
                        color: const Color(0xFF2563EB),
                        background: const Color(0xFFEFF6FF),
                      ),
                      _FeeAmountCard(
                        icon: AppIcons.female,
                        label: l10n.feeFemale,
                        amount: feeConfig.femaleFee,
                        color: const Color(0xFFEC4899),
                        background: const Color(0xFFFDF2F8),
                      ),
                    ];
                    if (constraints.maxWidth >= 440) {
                      return Row(
                        children: [
                          Expanded(child: cards.first),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: cards.last),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        cards.first,
                        const SizedBox(height: AppSpacing.md),
                        cards.last,
                      ],
                    );
                  },
                )
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
    final color = isFixed ? const Color(0xFF15803D) : const Color(0xFF2563EB);
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
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            isFixed ? l10n.feeFixed : l10n.feeSplitLater,
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

class _FeeAmountCard extends StatelessWidget {
  const _FeeAmountCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final int? amount;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            amount == null ? l10n.feeNotSet : Money.vnd(amount!),
            style: theme.textTheme.titleLarge?.copyWith(
              color: color.withValues(alpha: .9),
              fontWeight: FontWeight.w800,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                if (feeConfig.splitPerPlayer case final perPlayer?)
                  Text('${l10n.feePerPerson}: ${Money.vnd(perPlayer)}'),
                if (feeConfig.splitTotal case final total?)
                  Text('${l10n.feeTotal}: ${Money.vnd(total)}'),
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
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: theme.colorScheme.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.notes,
                          size: 18,
                          color: palette.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Text(
                          l10n.feeNotes.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.mutedForeground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(notes, style: theme.textTheme.bodyMedium),
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
