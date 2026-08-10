import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_settings_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class PaymentSettingsCard extends ConsumerWidget {
  const PaymentSettingsCard({
    required this.sessionId,
    required this.settings,
    super.key,
  });

  final String sessionId;
  final AsyncValue<List<HostPaymentSettings>> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: settings.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(paymentSettingsProvider),
          ),
          data: (items) {
            HostPaymentSettings? current;
            for (final item in items) {
              current ??= item;
              if (item.isDefault) {
                current = item;
                break;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.hostManagePaymentSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (current != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (items.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: current.id,
                      decoration: InputDecoration(
                        labelText: l10n.hostManagePaymentSettings,
                      ),
                      items: [
                        for (final item in items)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.bankName ?? '—'} · '
                              '${item.bankAccountNumber ?? '—'}',
                            ),
                          ),
                      ],
                      onChanged: (id) async {
                        if (id != null && id != current?.id) {
                          await ref
                              .read(
                                hostSessionManagementControllerProvider(
                                  sessionId,
                                ).notifier,
                              )
                              .setDefaultSettings(id);
                        }
                      },
                    ),
                  Text(current.bankName ?? '—'),
                  Text(current.bankAccountNumber ?? '—'),
                  Text(current.accountHolderName ?? '—'),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  children: [
                    if (current != null)
                      IconButton(
                        tooltip: l10n.hostManageAddSettings,
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => PaymentSettingsDialog(
                            sessionId: sessionId,
                          ),
                        ),
                        icon: const Icon(AppIcons.add),
                      ),
                    if (current != null)
                      IconButton(
                        tooltip: l10n.hostManageDeleteSettings,
                        onPressed: () => ref
                            .read(
                              hostSessionManagementControllerProvider(
                                sessionId,
                              ).notifier,
                            )
                            .deleteSettings(current!.id),
                        icon: const Icon(AppIcons.delete),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => PaymentSettingsDialog(
                          sessionId: sessionId,
                          current: current,
                        ),
                      ),
                      icon: const Icon(AppIcons.bank),
                      label: Text(
                        current == null
                            ? l10n.hostManageAddSettings
                            : l10n.hostManageEditSettings,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
