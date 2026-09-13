import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/payment/domain/form/player_payment_form.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// Ported from `vmito-fe`'s `PaymentInfoTab`/`SubmitPaymentModal`
/// (`/player/sessions/[id]?tab=4`), condensed for a single mobile column.
class PlayerLivePaymentTab extends ConsumerWidget {
  const PlayerLivePaymentTab({required this.session, super.key});
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feeConfig = session.feeConfig;
    // Mirrors the web tab: with no fee configured there is nothing to fetch
    // or show beyond this message.
    if (feeConfig == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.feeNotConfigured, textAlign: TextAlign.center),
        ),
      );
    }
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
            _PaymentSummary(value: value, feeConfig: feeConfig),
            if (value.hostSettings != null) ...[
              const SizedBox(height: AppSpacing.md),
              _BankCard(
                settings: value.hostSettings!,
                amount: value.pendingAmount,
                session: session,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (value.records.isEmpty)
              SizedBox(
                height: 240,
                child: Center(child: Text(l10n.playerLiveNoPayments)),
              )
            else ...[
              Text(
                l10n.playerLivePaymentDetailsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < value.records.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PaymentCard(
                    sessionId: session.id,
                    payment: value.records[i],
                    slotLabel: _slotLabel(
                      l10n,
                      index: i,
                      total: value.records.length,
                      playerName: value.records[i].player?.displayName,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

String _slotLabel(
  AppLocalizations l10n, {
  required int index,
  required int total,
  String? playerName,
}) {
  final base = total > 1
      ? l10n.playerLiveSlotNumber(index + 1)
      : l10n.playerLiveYourSlot;
  final name = playerName?.trim();
  return name?.isNotEmpty == true ? '$base ($name)' : base;
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.value, required this.feeConfig});
  final PlayerSessionPayments value;
  final SessionFeeConfig feeConfig;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final locale = Localizations.localeOf(context).languageCode;
    final rows = [
      (l10n.playerLivePaymentTotal, value.totalAmount, null),
      (l10n.playerLivePaymentPaid, value.paidAmount, palette.success),
      (l10n.playerLivePaymentRemaining, value.pendingAmount, palette.warning),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.playerLivePaymentSummaryTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.brandSurface,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                border: Border.all(
                  color: palette.success.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                feeConfig.isSplitEvenly ? l10n.feeSplitLater : l10n.feeFixed,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                    Text(
                      Money.vnd(row.$2, locale: locale),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: row.$3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Color-coded status pill, matching the session registration status badge's
/// pattern (`registration_status_badge.dart`).
class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PaymentStatus.pending => (
        l10n.playerLivePaymentPending,
        palette.mutedForeground,
      ),
      PaymentStatus.submitted => (
        l10n.playerLivePaymentAwaitingApproval,
        palette.info,
      ),
      PaymentStatus.approved => (
        l10n.playerLivePaymentApproved,
        palette.success,
      ),
      PaymentStatus.rejected => (
        l10n.playerLivePaymentRejected,
        theme.colorScheme.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
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
                    onPressed: () {
                      final box = context.findRenderObject();
                      SharePlus.instance.share(
                        ShareParams(
                          text: qrUrl ?? uri?.toString() ?? '',
                          // iPad anchors the share sheet to the tapped rect;
                          // without it the sheet throws rather than opening.
                          sharePositionOrigin: box is RenderBox
                              ? box.localToGlobal(Offset.zero) & box.size
                              : null,
                        ),
                      );
                    },
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
              textInputAction: TextInputAction.done,
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
  const _PaymentCard({
    required this.sessionId,
    required this.payment,
    required this.slotLabel,
  });
  final String sessionId;
  final PaymentRecord payment;
  final String slotLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
                    slotLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _PaymentStatusBadge(status: payment.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Money.vnd(payment.amount, locale: locale),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.success,
              ),
            ),
            if (payment.status == PaymentStatus.submitted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.playerLiveWaitingForApproval,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.success,
                  ),
                ),
              ),
            if (payment.status == PaymentStatus.rejected &&
                payment.hostNotes?.trim().isNotEmpty == true)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: Text(
                  l10n.playerLiveRejectionReason(payment.hostNotes!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (payment.proofImageUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: CachedNetworkImage(
                    imageUrl: payment.proofImageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
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

/// A two-state toggle button (bank transfer / cash). Sets an explicit
/// foreground color rather than relying on `OutlinedButton`'s default
/// (`colorScheme.primary`), which reads invisible once the background swaps
/// to `colorScheme.primary` on selection — this app's theme never pins
/// `primaryContainer`/`onPrimaryContainer`, so Material 3 falls back to an
/// unrelated baseline pair that doesn't guarantee contrast against it.
class _MethodToggleButton extends StatelessWidget {
  const _MethodToggleButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? theme.colorScheme.primary : null,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      onPressed: onPressed,
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

  Future<void> _pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
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

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final locale = Localizations.localeOf(context).languageCode;
    final actionState = ref.watch(
      playerSessionPaymentControllerProvider(widget.sessionId),
    );
    final busy = actionState.isBusy;
    final isRejected = widget.payment.status == PaymentStatus.rejected;

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
              AppSheetHeader(
                title: isRejected
                    ? l10n.playerLiveResubmitPayment
                    : l10n.playerLiveSubmitPayment,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.brandSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(
                    color: palette.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.playerLiveYourFee),
                        Text(
                          Money.vnd(widget.payment.amount, locale: locale),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.playerLiveCurrentStatus),
                        _PaymentStatusBadge(status: widget.payment.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.transactionReceiveMethod,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveValueListenableBuilder<PaymentMethod>(
                formControlName: PlayerPaymentControl.method,
                builder: (context, control, _) {
                  final method = control.value ?? PaymentMethod.bankTransfer;
                  return Row(
                    children: [
                      Expanded(
                        child: _MethodToggleButton(
                          icon: Icons.account_balance,
                          label: l10n.transactionBankTransfer,
                          selected: method == PaymentMethod.bankTransfer,
                          onPressed: busy
                              ? null
                              : () =>
                                    control.value = PaymentMethod.bankTransfer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _MethodToggleButton(
                          icon: Icons.money,
                          label: l10n.transactionCash,
                          selected: method == PaymentMethod.cash,
                          onPressed: busy
                              ? null
                              : () => control.value = PaymentMethod.cash,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveValueListenableBuilder<PaymentMethod>(
                formControlName: PlayerPaymentControl.method,
                builder: (context, methodControl, _) {
                  if (methodControl.value != PaymentMethod.bankTransfer) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reminderUploadProof,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ReactiveValueListenableBuilder<String>(
                        formControlName: PlayerPaymentControl.proofImageUrl,
                        builder: (context, control, _) {
                          final imageUrl = control.value;
                          if (actionState.uploading) {
                            return Container(
                              height: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.xs,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 8),
                                  Text(l10n.reminderUploading),
                                ],
                              ),
                            );
                          }
                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.xs,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => control.value = null,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return InkWell(
                            onTap: busy ? null : _showImageSourceSheet,
                            borderRadius: BorderRadius.circular(AppSpacing.xs),
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.xs,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.reminderClickToUpload,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
              ),
              Text(
                l10n.reminderProofNotes,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveTextField<String>(
                formControlName: PlayerPaymentControl.proofNotes,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.reminderProofNotesPlaceholder,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSheetActionBar(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                applySafeArea: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.commonSubmit),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
