import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// One occupied square on the court.
///
/// Ports `vmito-fe/src/components/court/CourtPlayer.tsx`, minus its tooltip:
/// hover has no equivalent here, and the same detail is a tap away in the
/// player list.
class CourtPlayerMarker extends StatelessWidget {
  const CourtPlayerMarker({
    required this.player,
    required this.mode,
    required this.displayMode,
    this.isActive = false,
    this.onTap,
    super.key,
  });

  final SessionPlayer player;
  final CourtViewMode mode;
  final CourtDisplayMode displayMode;

  /// Highlighted because this is the square the host is filling next.
  final bool isActive;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final level = player.level;
    // Levels are the host's working data, not a player's business.
    final levelLabel = mode.isHostView && level != null
        ? levelShortLabel(level)
        : null;

    return Semantics(
      button: onTap != null,
      label: l10n.playerName(player),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isActive
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (levelLabel != null)
                  Text(
                    levelLabel,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `#7` or `An`, depending on what the host asked for.
  ///
  /// A player with no shirt number still needs something to render, so number
  /// mode falls back to the name rather than showing an empty chip.
  String _label(AppLocalizations l10n) {
    if (displayMode.showsName) return l10n.playerName(player);
    final number = player.playerNumber;
    return number == null ? l10n.playerName(player) : '#$number';
  }
}
