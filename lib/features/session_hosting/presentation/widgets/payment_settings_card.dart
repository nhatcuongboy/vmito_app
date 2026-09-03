import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_settings_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

class PaymentSettingsCard extends ConsumerWidget {
  const PaymentSettingsCard({
    required this.sessionId,
    required this.settings,
    super.key,
  });

  final String sessionId;
  final AsyncValue<List<HostPaymentSettings>> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => settings.when(
    loading: () => const _SettingsSkeleton(),
    error: (error, _) => Card(
      child: AppErrorView(
        error: error,
        onRetry: () => ref.invalidate(paymentSettingsProvider),
      ),
    ),
    data: (items) {
      HostPaymentSettings? current;
      for (final item in items) {
        current ??= item;
        if (item.isDefault) current = item;
      }
      return current == null
          ? _EmptySettingsCard(sessionId: sessionId)
          : _ConfiguredSettingsCard(
              sessionId: sessionId,
              current: current,
              items: items,
            );
    },
  );
}

class _EmptySettingsCard extends StatelessWidget {
  const _EmptySettingsCard({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warning = Theme.of(context).extension<AppPalette>()!.warning;
    return Card(
      color: warning.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.warning, color: warning, size: 34),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.hostManageNoPaymentSettings,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.hostManageNoPaymentSettingsDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => _showSettingsSheet(context, sessionId, null),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.hostManageAddSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfiguredSettingsCard extends ConsumerWidget {
  const _ConfiguredSettingsCard({
    required this.sessionId,
    required this.current,
    required this.items,
  });

  final String sessionId;
  final HostPaymentSettings current;
  final List<HostPaymentSettings> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final banks =
        ref.watch(vietnamBanksProvider).value ?? const <VietnamBank>[];
    final qrUrl = _settingsQrUrl(current, banks);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.hostManageCurrentSettings,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('payment-settings-manage'),
                  tooltip: l10n.hostManageManageAccounts,
                  onPressed: () => _showAccountManager(
                    context,
                    ref,
                    sessionId,
                    items,
                  ),
                  icon: const Icon(AppIcons.settings),
                ),
                IconButton(
                  tooltip: l10n.commonEdit,
                  onPressed: () =>
                      _showSettingsSheet(context, sessionId, current),
                  icon: const Icon(AppIcons.edit),
                ),
              ],
            ),
            if (items.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: current.id,
                decoration: InputDecoration(
                  labelText: l10n.hostManageSavedAccounts,
                ),
                items: [
                  for (final item in items)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.bankName ?? '—'} · '
                        '${item.bankAccountNumber ?? '—'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null && id != current.id) {
                    unawaited(
                      ref
                          .read(
                            hostSessionManagementControllerProvider(
                              sessionId,
                            ).notifier,
                          )
                          .setDefaultSettings(id),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (qrUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CachedNetworkImage(
                      imageUrl: qrUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const SizedBox.square(
                        dimension: 96,
                        child: Icon(AppIcons.imageOff),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoLine(
                        icon: AppIcons.building,
                        label: l10n.hostManageBank,
                        value: current.bankName,
                      ),
                      _InfoLine(
                        icon: AppIcons.creditCard,
                        label: l10n.hostManageAccountNumber,
                        value: current.bankAccountNumber,
                      ),
                      _InfoLine(
                        icon: AppIcons.user,
                        label: l10n.hostManageAccountHolder,
                        value: current.accountHolderName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _settingsQrUrl(
  HostPaymentSettings settings,
  List<VietnamBank> banks,
) {
  if (settings.qrCodeUrl?.isNotEmpty ?? false) return settings.qrCodeUrl;
  final bankName = settings.bankName?.trim() ?? '';
  final account = settings.bankAccountNumber?.trim() ?? '';
  if (bankName.isEmpty || account.isEmpty) return null;
  var code = bankName;
  for (final bank in banks) {
    if (bank.shortName.toLowerCase() == bankName.toLowerCase() ||
        bank.code.toLowerCase() == bankName.toLowerCase()) {
      code = bank.code;
      break;
    }
  }
  final holder = settings.accountHolderName?.trim() ?? '';
  return Uri.https(
    'img.vietqr.io',
    '/image/${code.toLowerCase()}-$account-compact.png',
    holder.isEmpty ? null : {'accountName': holder},
  ).toString();
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value?.isNotEmpty != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                SelectableText(value!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showSettingsSheet(
  BuildContext context,
  String sessionId,
  HostPaymentSettings? current,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => PaymentSettingsDialog(
    sessionId: sessionId,
    current: current,
  ),
);

Future<void> _showAccountManager(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
  List<HostPaymentSettings> items,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final l10n = AppLocalizations.of(sheetContext);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.hostManageManageAccounts,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.isDefault ? AppIcons.checkCircle : AppIcons.bank,
              ),
              title: Text(item.bankName ?? l10n.hostManagePaymentSettings),
              subtitle: Text(item.bankAccountNumber ?? '—'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.commonEdit,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(_showSettingsSheet(context, sessionId, item));
                    },
                    icon: const Icon(AppIcons.edit),
                  ),
                  IconButton(
                    tooltip: l10n.commonDelete,
                    onPressed: () async {
                      final confirmed = await showAppConfirmDialog(
                        sheetContext,
                        type: AppConfirmDialogType.destructive,
                        title: l10n.hostManageDeleteSettings,
                        content:
                            '${item.bankName ?? l10n.hostManagePaymentSettings} · '
                            '${item.bankAccountNumber ?? '—'}',
                        confirmLabel: l10n.commonDelete,
                      );
                      if (confirmed != true) return;
                      await ref
                          .read(
                            hostSessionManagementControllerProvider(
                              sessionId,
                            ).notifier,
                          )
                          .deleteSettings(item.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(AppIcons.delete),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              unawaited(_showSettingsSheet(context, sessionId, null));
            },
            icon: const Icon(AppIcons.add),
            label: Text(l10n.hostManageAddSettings),
          ),
        ],
      ),
    );
  },
);
