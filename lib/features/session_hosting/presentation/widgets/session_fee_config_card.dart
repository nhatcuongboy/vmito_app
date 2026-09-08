import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/form/host_payment_forms.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_section_header_style.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class SessionFeeConfigCard extends ConsumerWidget {
  const SessionFeeConfigCard({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(sessionFeeConfigProvider(sessionId));
    return value.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, _) => Card(
        child: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(sessionFeeConfigProvider(sessionId)),
        ),
      ),
      data: (config) => config == null
          ? _EmptyFeeCard(sessionId: sessionId)
          : _ConfiguredFeeCard(sessionId: sessionId, config: config),
    );
  }
}

class _EmptyFeeCard extends StatelessWidget {
  const _EmptyFeeCard({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.calculator, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.hostManageFeeConfig),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => _showFeeSheet(context, sessionId, null),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.hostManageConfigureFee),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfiguredFeeCard extends ConsumerWidget {
  const _ConfiguredFeeCard({required this.sessionId, required this.config});
  final String sessionId;
  final SessionFeeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final success = Theme.of(context).extension<AppPalette>()!.success;
    return Card(
      color: success.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: success.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeeConfigHeader(
              title: l10n.hostManageFeeConfig,
              feeType: config.isSplitEvenly
                  ? l10n.hostManageSplitEvenly
                  : l10n.hostManageFixedFee,
              editTooltip: l10n.commonEdit,
              recalculateTooltip: l10n.hostManageRecalculate,
              onEdit: () => _showFeeSheet(context, sessionId, config),
              onRecalculate: () async {
                final updated = await ref
                    .read(
                      hostSessionManagementControllerProvider(
                        sessionId,
                      ).notifier,
                    )
                    .recalculatePayments();
                if (updated == null || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.hostManageRecalculated(updated)),
                  ),
                );
              },
            ),
            if (!config.isSplitEvenly) ...[
              if (config.maleFee != null)
                _FeeLine(
                  label: l10n.createSessionFeeMale,
                  amount: Money.vnd(config.maleFee!, locale: locale),
                ),
              if (config.femaleFee != null)
                _FeeLine(
                  label: l10n.createSessionFeeFemale,
                  amount: Money.vnd(config.femaleFee!, locale: locale),
                ),
            ],
            if (config.notes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(config.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeeConfigHeader extends StatelessWidget {
  const _FeeConfigHeader({
    required this.title,
    required this.feeType,
    required this.editTooltip,
    required this.recalculateTooltip,
    required this.onEdit,
    required this.onRecalculate,
  });

  final String title;
  final String feeType;
  final String editTooltip;
  final String recalculateTooltip;
  final VoidCallback onEdit;
  final VoidCallback onRecalculate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleRow = Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      );
      final feeTypeChip = Chip(
        visualDensity: VisualDensity.compact,
        label: Text(feeType, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: editTooltip,
            onPressed: onEdit,
            constraints: PaymentSectionHeaderStyle.actionIconButtonConstraints,
            iconSize: PaymentSectionHeaderStyle.actionIconSize,
            icon: const Icon(AppIcons.edit),
          ),
          IconButton(
            tooltip: recalculateTooltip,
            onPressed: onRecalculate,
            constraints: PaymentSectionHeaderStyle.actionIconButtonConstraints,
            iconSize: PaymentSectionHeaderStyle.actionIconSize,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      );

      if (constraints.maxWidth < 360) {
        return Column(
          key: const Key('fee-config-header-compact'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleRow,
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: feeTypeChip,
                  ),
                ),
                actions,
              ],
            ),
          ],
        );
      }

      return Row(
        key: const Key('fee-config-header-wide'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleRow,
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: feeTypeChip,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          actions,
        ],
      );
    },
  );
}

class _FeeLine extends StatelessWidget {
  const _FeeLine({required this.label, required this.amount});
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Future<void> _showFeeSheet(
  BuildContext context,
  String sessionId,
  SessionFeeConfig? config,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _FeeConfigSheet(
    sessionId: sessionId,
    current: config,
  ),
);

class _FeeConfigSheet extends ConsumerStatefulWidget {
  const _FeeConfigSheet({required this.sessionId, required this.current});
  final String sessionId;
  final SessionFeeConfig? current;

  @override
  ConsumerState<_FeeConfigSheet> createState() => _FeeConfigSheetState();
}

class _FeeConfigSheetState extends ConsumerState<_FeeConfigSheet> {
  late final FormGroup _form = createSessionFeeForm(widget.current);
  bool _saving = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: AppReactiveForm<void>(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.hostManageFeeConfig,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveSwitchListTile(
                  formControlName: SessionFeeControl.enabled,
                  title: Text(l10n.hostManageEnableFee),
                  contentPadding: EdgeInsets.zero,
                ),
                ReactiveDropdownField<FeeType>(
                  formControlName: SessionFeeControl.feeType,
                  decoration: InputDecoration(
                    labelText: l10n.hostManageFeeType,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: FeeType.fixed,
                      child: Text(
                        l10n.hostManageFixedFee,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                    DropdownMenuItem(
                      value: FeeType.splitEvenly,
                      child: Text(
                        l10n.hostManageSplitEvenly,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveValueListenableBuilder<FeeType>(
                  formControlName: SessionFeeControl.feeType,
                  builder: (context, control, _) =>
                      control.value == FeeType.fixed
                      ? Row(
                          children: [
                            Expanded(
                              child: ReactiveTextField<int>(
                                formControlName: SessionFeeControl.maleFee,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.createSessionFeeMale,
                                  suffixText: '₫',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ReactiveTextField<int>(
                                formControlName: SessionFeeControl.femaleFee,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.createSessionFeeFemale,
                                  suffixText: '₫',
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(l10n.hostManageSplitDescription),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: SessionFeeControl.notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.transactionHostNotes,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.save),
                  label: Text(l10n.hostManageSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _saving) return;
    setState(() => _saving = true);
    final enabled =
        _form.control(SessionFeeControl.enabled).value as bool? ?? false;
    final controller = ref.read(
      hostSessionManagementControllerProvider(widget.sessionId).notifier,
    );
    final saved = enabled
        ? await controller.saveFeeConfig(
            SessionFeeConfig(
              feeType:
                  _form.control(SessionFeeControl.feeType).value as FeeType? ??
                  FeeType.fixed,
              maleFee: _form.control(SessionFeeControl.maleFee).value as int?,
              femaleFee:
                  _form.control(SessionFeeControl.femaleFee).value as int?,
              notes: (_form.control(SessionFeeControl.notes).value as String?)
                  ?.trim(),
            ),
          )
        : widget.current == null || await controller.deleteFeeConfig();
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }
}
