import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.role,
    this.actions,
  });

  final PaymentReminder reminder;
  final String role; // 'creator' or 'recipient'
  final Widget? actions;

  void _showProofImageDialog(BuildContext context, String imageUrl) {
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    final counterparty =
        role == 'creator' ? reminder.recipient : reminder.creator;
    final counterpartyName =
        counterparty?.name.isNotEmpty == true
            ? counterparty!.name
            : l10n.reminderUnknownUser;

    final statusColor = switch (reminder.status) {
      PaymentReminderStatus.resolved => Colors.green,
      PaymentReminderStatus.awaitingConfirmation => Colors.orange,
      PaymentReminderStatus.pending => Colors.amber,
    };

    final statusLabel = switch (reminder.status) {
      PaymentReminderStatus.resolved => l10n.reminderResolved,
      PaymentReminderStatus.awaitingConfirmation =>
        l10n.reminderAwaitingConfirmation,
      PaymentReminderStatus.pending => l10n.reminderPending,
    };

    final typeLabel = switch (reminder.type) {
      PaymentReminderType.singlePayment => l10n.reminderTypeSingle,
      PaymentReminderType.aggregate => l10n.reminderTypeAggregate,
      PaymentReminderType.custom => l10n.reminderTypeCustom,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: User Avatar, Name, Type Tag, and Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: counterpartyName,
                  imageUrl: counterparty?.image,
                  gender: counterparty?.gender,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counterpartyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (reminder.session?.name.isNotEmpty == true)
                            Text(
                              reminder.session!.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Note & Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reminder.note != null &&
                          reminder.note!.trim().isNotEmpty) ...[
                        Text(
                          reminder.note!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (reminder.lastRemindedAt != null)
                        Text(
                          '${l10n.reminderLastRemindedAt}: ${Dates.dayAndTime(reminder.lastRemindedAt!, locale: locale)}'
                          '${reminder.reminderCount > 1 ? ' · ${l10n.reminderCount(reminder.reminderCount)}' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  Money.vnd(reminder.amount, locale: locale),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Proof section if AWAITING_CONFIRMATION
            if (reminder.status ==
                    PaymentReminderStatus.awaitingConfirmation &&
                (reminder.proofImageUrl != null ||
                    reminder.proofNotes != null)) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reminder.proofNotes != null &&
                        reminder.proofNotes!.trim().isNotEmpty)
                      Text(
                        reminder.proofNotes!.trim(),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (reminder.proofImageUrl != null &&
                        reminder.proofImageUrl!.trim().isNotEmpty) ...[
                      if (reminder.proofNotes != null &&
                          reminder.proofNotes!.trim().isNotEmpty)
                        const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showProofImageDialog(
                          context,
                          reminder.proofImageUrl!.trim(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.reminderViewProof,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.sm),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}
