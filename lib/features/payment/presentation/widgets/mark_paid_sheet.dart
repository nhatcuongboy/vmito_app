import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/domain/form/reminder_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class MarkPaidSheet extends ConsumerStatefulWidget {
  const MarkPaidSheet({
    super.key,
    required this.reminder,
  });

  final PaymentReminder reminder;

  static Future<bool?> show(
    BuildContext context, {
    required PaymentReminder reminder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => MarkPaidSheet(reminder: reminder),
    );
  }

  @override
  ConsumerState<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<MarkPaidSheet> {
  late final FormGroup _form = createMarkPaidForm();
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final result = await ref
          .read(paymentRemindersControllerProvider.notifier)
          .uploadProof(bytes, picked.name);
      if (result != null && mounted) {
        _form.control(MarkPaidControl.proofImageUrl).value = result.url;
        _form.control(MarkPaidControl.proofImagePublicId).value =
            result.publicId;
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeProofImage() {
    setState(() {
      _form.control(MarkPaidControl.proofImageUrl).value = null;
      _form.control(MarkPaidControl.proofImagePublicId).value = null;
    });
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _isUploading) return;

    final method =
        _form.control(MarkPaidControl.paymentMethod).value as PaymentMethod;
    final proofImageUrl =
        _form.control(MarkPaidControl.proofImageUrl).value as String?;
    final proofImagePublicId =
        _form.control(MarkPaidControl.proofImagePublicId).value as String?;
    final proofNotes =
        _form.control(MarkPaidControl.proofNotes).value as String?;

    final success = await ref
        .read(paymentRemindersControllerProvider.notifier)
        .markPaid(
          widget.reminder.id,
          paymentMethod: method,
          proofImageUrl: proofImageUrl,
          proofImagePublicId: proofImagePublicId,
          proofNotes: proofNotes,
        );

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isBusy = ref.watch(paymentRemindersControllerProvider).isLoading;

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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: l10n.reminderMarkPaid,
                showCloseButton: false,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount summary card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.reminderAmount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      Money.vnd(widget.reminder.amount, locale: locale),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Payment Method
              Text(
                l10n.transactionReceiveMethod,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveValueListenableBuilder<PaymentMethod>(
                formControlName: MarkPaidControl.paymentMethod,
                builder: (context, control, _) {
                  final currentMethod =
                      control.value ?? PaymentMethod.bankTransfer;
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.account_balance, size: 18),
                          label: Text(l10n.transactionBankTransfer),
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                currentMethod == PaymentMethod.bankTransfer
                                ? theme.colorScheme.primaryContainer
                                : null,
                            side: BorderSide(
                              color: currentMethod == PaymentMethod.bankTransfer
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          onPressed: () =>
                              control.value = PaymentMethod.bankTransfer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.money, size: 18),
                          label: Text(l10n.transactionCash),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: currentMethod == PaymentMethod.cash
                                ? theme.colorScheme.primaryContainer
                                : null,
                            side: BorderSide(
                              color: currentMethod == PaymentMethod.cash
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          onPressed: () => control.value = PaymentMethod.cash,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Payment Proof Upload (when bank transfer)
              ReactiveValueListenableBuilder<PaymentMethod>(
                formControlName: MarkPaidControl.paymentMethod,
                builder: (context, methodControl, _) {
                  if (methodControl.value != PaymentMethod.bankTransfer) {
                    return const SizedBox.shrink();
                  }

                  return ReactiveValueListenableBuilder<String>(
                    formControlName: MarkPaidControl.proofImageUrl,
                    builder: (context, imageControl, _) {
                      final imageUrl = imageControl.value;
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
                          if (_isUploading)
                            Container(
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
                            )
                          else if (imageUrl != null && imageUrl.isNotEmpty)
                            Stack(
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
                                      onPressed: _removeProofImage,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: () =>
                                  _showImagePickerSourceDialog(context),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.xs,
                              ),
                              child: Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    style: BorderStyle.solid,
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
                            ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
                  );
                },
              ),

              // Proof Notes
              Text(
                l10n.reminderProofNotes,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveTextField<String>(
                formControlName: MarkPaidControl.proofNotes,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.reminderProofNotesPlaceholder,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              AppSheetActionBar(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                applySafeArea: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (isBusy || _isUploading)
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: (isBusy || _isUploading) ? null : _submit,
                        child: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
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

  void _showImagePickerSourceDialog(BuildContext context) {
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
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
