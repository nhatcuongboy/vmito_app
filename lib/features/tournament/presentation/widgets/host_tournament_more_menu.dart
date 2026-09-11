import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// An entry in a host tournament card's overflow menu.
class HostTournamentCardAction {
  const HostTournamentCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;
}

/// The "..." button of a host tournament card. Swaps to a spinner while that
/// row is being deleted, as on web.
class HostTournamentMoreMenu extends StatelessWidget {
  const HostTournamentMoreMenu({
    required this.tournamentId,
    required this.actions,
    required this.isDeleting,
    super.key,
  });

  final String tournamentId;
  final List<HostTournamentCardAction> actions;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const SizedBox.square(
        dimension: AppSizes.minTapTarget,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<HostTournamentCardAction>(
      key: ValueKey('host-tournament-more-$tournamentId'),
      tooltip: AppLocalizations.of(context).hostTournamentsMoreActions,
      icon: const Icon(AppIcons.moreHorizontal, size: 18),
      // Default `over` centres the menu's first item on the button, hiding
      // it behind the panel; `under` drops the menu below so the "..." stays
      // visible while it's open.
      position: PopupMenuPosition.under,
      onSelected: (action) => action.onPressed(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 18,
                  color: action.isDestructive ? error : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  action.label,
                  style: action.isDestructive ? TextStyle(color: error) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
