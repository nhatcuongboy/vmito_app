import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/form/player_payment_form.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class PlayerLivePaymentTab extends ConsumerWidget {
  const PlayerLivePaymentTab({required this.session, super.key});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(playerSessionPaymentsProvider(session.id));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(
        error: error,
        onRetry: () =>
            ref.invalidate(playerSessionPaymentsProvider(session.id)),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () =>
            ref.refresh(playerSessionPaymentsProvider(session.id).future),
        child: ListView(
          key: const PageStorageKey('player-live-payments'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _PaymentSummary(value: value),
            if (value.hostSettings != null) ...[
              const SizedBox(height: AppSpacing.md),
              _BankCard(
                settings: value.hostSettings!,
                amount: value.pendingAmount,
                session: session,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (value.records.isEmpty)
              SizedBox(
                height: 240,
                child: Center(child: Text(l10n.playerLiveNoPayments)),
              )
            else
              for (final payment in value.records)
                _PaymentCard(sessionId: session.id, payment: payment),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.value});
  final PlayerSessionPayments value;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final items = [
      (l10n.playerLivePaymentTotal, value.totalAmount),
      (l10n.playerLivePaymentPaid, value.paidAmount),
      (l10n.playerLivePaymentRemaining, value.pendingAmount),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          SizedBox(
            width: 155,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      Money.vnd(item.$2, locale: locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(item.$1),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BankCard extends ConsumerWidget {
  const _BankCard({
    required this.settings,
    required this.amount,
    required this.session,
  });
  final HostPaymentSettings settings;
  final int amount;
  final Session session;

  String? _bankCode(List<VietnamBank> banks) {
    final configured = settings.bankName?.trim().toLowerCase();
    if (configured == null || configured.isEmpty) return null;
    return banks
        .where(
          (bank) =>
              bank.code.toLowerCase() == configured ||
              bank.shortName.toLowerCase() == configured ||
              bank.name.toLowerCase() == configured,
        )
        .firstOrNull
        ?.code;
  }

  Uri? _paymentUri(String? bankCode) {
    final account = settings.bankAccountNumber?.trim();
    if (account == null || account.isEmpty || bankCode == null) {
      return null;
    }
    return Uri.https('dl.vietqr.io', '/pay', {
      'app': bankCode,
      'ba': account,
      if (amount > 0) 'am': '$amount',
      'tn': normalizeTransferMessage('VMITO ${session.name}'),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bankCode = _bankCode(
      ref.watch(vietnamBanksProvider).value ?? const [],
    );
    final uri = _paymentUri(bankCode);
    final account = settings.bankAccountNumber?.trim();
    final generatedQr = bankCode == null || account == null || account.isEmpty
        ? null
        : Uri.https('img.vietqr.io', '/image/$bankCode-$account-compact2.png', {
            if (amount > 0) 'amount': '$amount',
            'addInfo': normalizeTransferMessage('VMITO ${session.name}'),
            if (settings.accountHolderName?.trim().isNotEmpty == true)
              'accountName': settings.accountHolderName!.trim(),
          }).toString();
    final qrUrl = generatedQr ?? settings.qrCodeUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.playerLiveBankInformation,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (qrUrl?.isNotEmpty == true)
              Center(
                child: CachedNetworkImage(
                  imageUrl: qrUrl!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
            Text(settings.bankName ?? ''),
            SelectableText(settings.bankAccountNumber ?? ''),
            Text(settings.accountHolderName ?? ''),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (uri != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _FastTransferSheet.show(
                        context,
                        initialAmount: amount,
                        initialMessage: 'VMITO ${session.name}',
                        initialBankCode: bankCode ?? settings.bankName ?? '',
                        accountNumber: settings.bankAccountNumber!,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.transactionBankTransfer),
                    ),
                  ),
                if (uri != null) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: qrUrl ?? uri?.toString() ?? '',
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(
                      MaterialLocalizations.of(context).shareButtonLabel,
                    ),
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

class _FastTransferSheet extends StatefulWidget {
  const _FastTransferSheet({
    required this.initialAmount,
    required this.initialMessage,
    required this.initialBankCode,
    required this.accountNumber,
  });
  final int initialAmount;
  final String initialMessage;
  final String initialBankCode;
  final String accountNumber;

  static Future<void> show(
    BuildContext context, {
    required int initialAmount,
    required String initialMessage,
    required String initialBankCode,
    required String accountNumber,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FastTransferSheet(
      initialAmount: initialAmount,
      initialMessage: initialMessage,
      initialBankCode: initialBankCode,
      accountNumber: accountNumber,
    ),
  );

  @override
  State<_FastTransferSheet> createState() => _FastTransferSheetState();
}

class _FastTransferSheetState extends State<_FastTransferSheet> {
  late final FormGroup _form = createFastTransferForm(
    amount: widget.initialAmount,
    message: normalizeTransferMessage(widget.initialMessage),
    bankCode: widget.initialBankCode,
  );

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _form.markAllAsTouched();
    if (_form.invalid) return;
    final uri = Uri.https('dl.vietqr.io', '/pay', {
      'app': _form.control(FastTransferControl.bankCode).value as String,
      'ba': widget.accountNumber,
      'am': '${_form.control(FastTransferControl.amount).value as int}',
      'tn': normalizeTransferMessage(
        (_form.control(FastTransferControl.message).value as String?) ?? '',
      ),
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: AppReactiveForm<void>(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.playerLiveFastTransfer,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ReactiveTextField<int>(
              formControlName: FastTransferControl.amount,
              keyboardType: TextInputType.number,
              valueAccessor: IntValueAccessor(),
              decoration: InputDecoration(
                labelText: l10n.playerLiveTransferAmount,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              formControlName: FastTransferControl.bankCode,
              decoration: InputDecoration(labelText: l10n.playerLiveBankCode),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReactiveTextField<String>(
              formControlName: FastTransferControl.message,
              maxLength: 70,
              decoration: InputDecoration(
                labelText: l10n.playerLiveTransferContent,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.playerLiveOpenBankingApp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.sessionId, required this.payment});
  final String sessionId;
  final PaymentRecord payment;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final canSubmit =
        payment.status == PaymentStatus.pending ||
        payment.status == PaymentStatus.rejected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Money.vnd(payment.amount, locale: locale),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_paymentStatus(l10n, payment.status))),
              ],
            ),
            if (payment.hostNotes?.trim().isNotEmpty == true)
              Text(
                payment.hostNotes!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (payment.proofImageUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: CachedNetworkImage(
                  imageUrl: payment.proofImageUrl!,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            if (canSubmit) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => _PaymentSubmitSheet.show(
                  context,
                  sessionId: sessionId,
                  payment: payment,
                ),
                child: Text(
                  payment.status == PaymentStatus.rejected
                      ? l10n.playerLiveResubmitPayment
                      : l10n.playerLiveSubmitPayment,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentSubmitSheet extends ConsumerStatefulWidget {
  const _PaymentSubmitSheet({required this.sessionId, required this.payment});
  final String sessionId;
  final PaymentRecord payment;
  static Future<void> show(
    BuildContext context, {
    required String sessionId,
    required PaymentRecord payment,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PaymentSubmitSheet(sessionId: sessionId, payment: payment),
  );
  @override
  ConsumerState<_PaymentSubmitSheet> createState() =>
      _PaymentSubmitSheetState();
}

class _PaymentSubmitSheetState extends ConsumerState<_PaymentSubmitSheet> {
  late final FormGroup _form = createPlayerPaymentForm();
  final _picker = ImagePicker();
  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image == null) return;
    final result = await ref
        .read(playerSessionPaymentControllerProvider(widget.sessionId).notifier)
        .upload(await image.readAsBytes(), image.name);
    if (result != null && mounted) {
      _form.control(PlayerPaymentControl.proofImageUrl).value = result.url;
    }
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid ||
        ref
            .read(playerSessionPaymentControllerProvider(widget.sessionId))
            .isBusy) {
      return;
    }
    final success = await ref
        .read(playerSessionPaymentControllerProvider(widget.sessionId).notifier)
        .submit(
          widget.payment.id,
          method:
              _form.control(PlayerPaymentControl.method).value as PaymentMethod,
          proofImageUrl:
              _form.control(PlayerPaymentControl.proofImageUrl).value
                  as String?,
          proofNotes:
              _form.control(PlayerPaymentControl.proofNotes).value as String?,
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.playerLivePaymentSubmitted
              : l10n.playerLivePaymentFailed,
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref
        .watch(playerSessionPaymentControllerProvider(widget.sessionId))
        .isBusy;
    return Padding(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.playerLiveSubmitPayment,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveDropdownField<PaymentMethod>(
                formControlName: PlayerPaymentControl.method,
                decoration: InputDecoration(
                  labelText: l10n.transactionReceiveMethod,
                ),
                items: [
                  DropdownMenuItem(
                    value: PaymentMethod.bankTransfer,
                    child: Text(l10n.transactionBankTransfer),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.cash,
                    child: Text(l10n.transactionCash),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveValueListenableBuilder<String>(
                formControlName: PlayerPaymentControl.proofImageUrl,
                builder: (context, control, _) => Column(
                  children: [
                    if (control.value?.isNotEmpty == true)
                      CachedNetworkImage(
                        imageUrl: control.value!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _pick,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l10n.reminderUploadProof),
                    ),
                    if (control.value?.isNotEmpty == true)
                      TextButton(
                        onPressed: busy ? null : () => control.value = null,
                        child: Text(l10n.commonDelete),
                      ),
                  ],
                ),
              ),
              ReactiveTextField<String>(
                formControlName: PlayerPaymentControl.proofNotes,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.reminderProofNotes,
                  hintText: l10n.reminderProofNotesPlaceholder,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paymentStatus(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.pending => l10n.playerLivePaymentPending,
      PaymentStatus.submitted => l10n.playerLivePaymentAwaitingApproval,
      PaymentStatus.approved => l10n.playerLivePaymentApproved,
      PaymentStatus.rejected => l10n.playerLivePaymentRejected,
    };

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
