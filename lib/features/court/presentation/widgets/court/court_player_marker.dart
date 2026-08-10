import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// One occupied square on the court.
///
/// Ports `vmito-fe/src/components/court/CourtPlayer.tsx`, minus its tooltip
/// and hover pulse: hover has no equivalent here, and the same detail is a
/// tap away in the player list.
class CourtPlayerMarker extends StatelessWidget {
  const CourtPlayerMarker({
    required this.player,
    required this.mode,
    required this.displayMode,
    required this.pairNumber,
    this.isActive = false,
    this.onTap,
    super.key,
  });

  final SessionPlayer player;
  final CourtViewMode mode;
  final CourtDisplayMode displayMode;

  /// 1 for the left-column team (blue), 2 for the right-column team (orange).
  /// Mirrors `getPairColor`'s column rule in `CourtPlayer.tsx`.
  final int pairNumber;

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
    final pair = _pairColorsFor(pairNumber);
    final borderColor = isActive ? theme.colorScheme.primary : pair.border;

    return Semantics(
      button: onTap != null,
      label: l10n.playerName(player),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _Marker(
              isNameMode: displayMode.showsName,
              background: pair.background,
              border: borderColor,
              borderWidth: isActive ? 3 : 2.5,
              child: Text(
                _label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pair.border,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              top: -8,
              left: -8,
              child: _GenderBadge(gender: player.gender),
            ),
            if (levelLabel != null)
              Positioned(
                top: -10,
                right: -12,
                child: _LevelBadge(label: levelLabel, color: pair.border),
              ),
          ],
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

/// The pill or circle itself: pair-coloured, never plain white.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.isNameMode,
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.child,
  });

  final bool isNameMode;
  final Color background;
  final Color border;
  final double borderWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: background,
      shape: isNameMode ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: isNameMode ? BorderRadius.circular(8) : null,
      border: Border.all(color: border, width: borderWidth),
      boxShadow: const [
        BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26),
      ],
    );

    if (!isNameMode) {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: decoration,
        child: FittedBox(
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 56, minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: decoration,
      child: child,
    );
  }
}

/// Top-left circle carrying the player's gender, shown in every mode — the
/// web renders it as decorative (`aria-hidden`), never gated on host view.
class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender});

  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (gender) {
      Gender.male => (const Color(0xFF3182CE), Icons.male),
      Gender.female => (const Color(0xFFD53F8C), Icons.female),
      Gender.other => (const Color(0xFF805AD5), Icons.person),
      null => (const Color(0xFF718096), Icons.person),
    };

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(icon, size: 11, color: Colors.white),
    );
  }
}

/// Top-right pill carrying the player's level, coloured to match their pair.
/// Host view only — a level is the host's working data, not a player's.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 16),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Blue for the left-column team, orange for the right — fixed hues, not
/// theme-derived: `CourtPlayer.tsx` never varies these by brightness either.
({Color background, Color border}) _pairColorsFor(int pairNumber) =>
    pairNumber == 2
    ? (background: const Color(0xFFFFF7ED), border: const Color(0xFFF97316))
    : (background: const Color(0xFFEFF6FF), border: const Color(0xFF3B82F6));
