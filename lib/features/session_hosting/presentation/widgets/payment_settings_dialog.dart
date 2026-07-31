import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class PaymentSettingsDialog extends ConsumerStatefulWidget {
  const PaymentSettingsDialog({
    required this.sessionId,
    this.current,
    super.key,
  });

  final String sessionId;
  final HostPaymentSettings? current;

  @override
  ConsumerState<PaymentSettingsDialog> createState() =>
      _PaymentSettingsDialogState();
}

class _PaymentSettingsDialogState extends ConsumerState<PaymentSettingsDialog> {
  late final _bank = TextEditingController(text: widget.current?.bankName);
  late final _number = TextEditingController(
    text: widget.current?.bankAccountNumber,
  );
  late final _holder = TextEditingController(
    text: widget.current?.accountHolderName,
  );

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.hostManagePaymentSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bank,
            decoration: InputDecoration(labelText: l10n.hostManageBank),
          ),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.hostManageAccountNumber,
            ),
          ),
          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.hostManageAccountHolder,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final saved = await ref
                .read(
                  hostSessionManagementControllerProvider(
                    widget.sessionId,
                  ).notifier,
                )
                .saveSettings(
                  id: widget.current?.id,
                  bankName: _bank.text.trim(),
                  accountNumber: _number.text.trim(),
                  accountHolder: _holder.text.trim(),
                );
            if (saved && context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.hostManageSave),
        ),
      ],
    );
  }
}
