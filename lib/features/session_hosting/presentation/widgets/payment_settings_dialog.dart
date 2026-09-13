import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/form/host_payment_forms.dart';
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
  late final FormGroup _form = createPaymentSettingsForm(widget.current);
  bool _saving = false;
  bool _uploading = false;
  bool _removedExistingQr = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final banks =
        ref.watch(vietnamBanksProvider).value ?? const <VietnamBank>[];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: AppReactiveForm(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.current == null
                      ? l10n.hostManageAddSettings
                      : l10n.hostManageEditSettings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ReactiveTextField<String>(
                        formControlName: PaymentSettingsControl.bankName,
                        decoration: InputDecoration(
                          labelText: l10n.hostManageBank,
                          prefixIcon: const Icon(AppIcons.building),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton.outlined(
                      key: const Key('payment-bank-picker'),
                      tooltip: l10n.hostManageBank,
                      onPressed: banks.isEmpty
                          ? null
                          : () => _pickBank(context, banks),
                      icon: const Icon(AppIcons.chevronDown),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: PaymentSettingsControl.accountNumber,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.hostManageAccountNumber,
                    prefixIcon: const Icon(AppIcons.creditCard),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: PaymentSettingsControl.accountHolder,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.hostManageAccountHolder,
                    prefixIcon: const Icon(AppIcons.user),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ReactiveFormConsumer(
                  builder: (context, form, _) {
                    final customQr =
                        form.control(PaymentSettingsControl.qrCodeUrl).value
                            as String?;
                    final preview = customQr?.isNotEmpty ?? false
                        ? customQr
                        : _autoQrUrl(form, banks);
                    return _QrEditor(
                      url: preview,
                      isCustom: customQr?.isNotEmpty ?? false,
                      uploading: _uploading,
                      onPick: _pickQr,
                      onRemove: customQr?.isNotEmpty ?? false
                          ? () {
                              form
                                      .control(PaymentSettingsControl.qrCodeUrl)
                                      .value =
                                  null;
                              setState(() => _removedExistingQr = true);
                            }
                          : null,
                    );
                  },
                ),
                ReactiveFormConsumer(
                  builder: (context, form, _) => form.touched && form.invalid
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            l10n.hostManagePaymentMethodRequired,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const Key('payment-settings-save'),
                        onPressed: _saving || _uploading ? null : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(AppIcons.save),
                        label: Text(l10n.hostManageSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBank(
    BuildContext context,
    List<VietnamBank> banks,
  ) async {
    final bank = await showSearch<VietnamBank?>(
      context: context,
      delegate: _BankSearchDelegate(banks),
    );
    if (bank == null) return;
    _form.control(PaymentSettingsControl.bankName).value = bank.shortName;
  }

  Future<void> _pickQr() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    setState(() => _uploading = true);
    final url = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .uploadQrCode(await image.readAsBytes(), image.name);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (url != null) {
      _form.control(PaymentSettingsControl.qrCodeUrl).value = url;
      _removedExistingQr = false;
    }
  }

  String? _autoQrUrl(FormGroup form, List<VietnamBank> banks) {
    final bankName =
        (form.control(PaymentSettingsControl.bankName).value as String? ?? '')
            .trim();
    final account =
        (form.control(PaymentSettingsControl.accountNumber).value as String? ??
                '')
            .trim();
    if (bankName.isEmpty || account.isEmpty) return null;
    var code = bankName;
    for (final bank in banks) {
      if (bank.shortName.toLowerCase() == bankName.toLowerCase() ||
          bank.code.toLowerCase() == bankName.toLowerCase()) {
        code = bank.code;
        break;
      }
    }
    final holder =
        (form.control(PaymentSettingsControl.accountHolder).value as String? ??
                '')
            .trim();
    return Uri.https(
      'img.vietqr.io',
      '/image/${code.toLowerCase()}-$account-compact.png',
      holder.isEmpty ? null : {'accountName': holder},
    ).toString();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _saving) return;
    setState(() => _saving = true);
    String? value(String name) =>
        (_form.control(name).value as String?)?.trim();
    final saved = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .saveSettings(
          id: widget.current?.id,
          bankName: value(PaymentSettingsControl.bankName),
          accountNumber: value(PaymentSettingsControl.accountNumber),
          accountHolder: value(PaymentSettingsControl.accountHolder),
          qrCodeUrl: value(PaymentSettingsControl.qrCodeUrl),
          clearQrCode: _removedExistingQr,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }
}

class _QrEditor extends StatelessWidget {
  const _QrEditor({
    required this.url,
    required this.isCustom,
    required this.uploading,
    required this.onPick,
    this.onRemove,
  });

  final String? url;
  final bool isCustom;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(AppIcons.image, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(l10n.hostManageQrCode)),
                if (isCustom && onRemove != null)
                  IconButton(
                    tooltip: l10n.commonDelete,
                    onPressed: onRemove,
                    icon: const Icon(AppIcons.delete),
                  ),
              ],
            ),
            if (url != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: url!,
                  height: 160,
                  width: 160,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const SizedBox(
                    height: 120,
                    child: Center(child: Icon(AppIcons.imageOff)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.upload),
              label: Text(l10n.hostManageUploadQr),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankSearchDelegate extends SearchDelegate<VietnamBank?> {
  _BankSearchDelegate(this.banks);
  final List<VietnamBank> banks;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(AppIcons.close)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(AppIcons.arrowBack),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = banks.where(
      (bank) =>
          normalized.isEmpty ||
          bank.name.toLowerCase().contains(normalized) ||
          bank.shortName.toLowerCase().contains(normalized) ||
          bank.code.toLowerCase().contains(normalized),
    );
    return ListView(
      children: [
        for (final bank in matches)
          ListTile(
            leading: bank.logo == null
                ? const Icon(AppIcons.bank)
                : CachedNetworkImage(
                    imageUrl: bank.logo!,
                    width: 32,
                    height: 32,
                  ),
            title: Text(bank.shortName),
            subtitle: Text(bank.name),
            onTap: () => close(context, bank),
          ),
      ],
    );
  }
}
