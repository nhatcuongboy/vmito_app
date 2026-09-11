import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/club_management_helpers.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

enum _ClubMenuAction { viewPublic, edit, fees, delete }

/// The "..." menu of a managed club card. "Manage" is not listed — tapping
/// the card already does that — and "Delete" is set apart in the error color.
/// "View club page" is the only way from this tab to the public club page
/// (about/gallery/schedule) that every member sees; the management screen
/// itself never links out to it either.
class ManagedClubMoreMenu extends ConsumerWidget {
  const ManagedClubMoreMenu({required this.club, super.key});

  final ClubSummary club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final isBusy = ref.watch(clubManagementControllerProvider).isLoading;

    PopupMenuItem<_ClubMenuAction> item(
      _ClubMenuAction value,
      IconData icon,
      String label, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: color == null ? null : TextStyle(color: color)),
        ],
      ),
    );

    return PopupMenuButton<_ClubMenuAction>(
      key: ValueKey('managed-club-more-${club.id}'),
      enabled: !isBusy,
      tooltip: l10n.clubMoreActions,
      icon: const Icon(AppIcons.moreHorizontal, size: 18),
      // `under` keeps the "..." visible while the menu is open.
      position: PopupMenuPosition.under,
      onSelected: (action) => _handleAction(context, ref, action),
      itemBuilder: (_) => [
        item(_ClubMenuAction.viewPublic, AppIcons.eye, l10n.clubViewPublicPage),
        item(_ClubMenuAction.edit, AppIcons.edit, l10n.commonEdit),
        item(
          _ClubMenuAction.fees,
          AppIcons.banknote,
          l10n.clubFeeConfiguration,
        ),
        const PopupMenuDivider(),
        item(
          _ClubMenuAction.delete,
          AppIcons.delete,
          l10n.commonDelete,
          color: error,
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _ClubMenuAction action,
  ) async {
    switch (action) {
      case _ClubMenuAction.viewPublic:
        await context.push(AppRoutes.clubDetail(club.slug ?? club.id));
      case _ClubMenuAction.edit:
        await context.push(AppRoutes.editClub(club.id));
      case _ClubMenuAction.fees:
        await context.push(AppRoutes.clubFees(club.id));
      case _ClubMenuAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubDeleteTitle,
      content: l10n.clubDeleteConfirm(club.name),
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await runClubAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .deleteClub(club.id),
      l10n.clubActionFailed,
    );
  }
}
