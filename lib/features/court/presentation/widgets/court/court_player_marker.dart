import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';
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
    this.onRemove,
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
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isNameMode = displayMode.showsName;
    final level = player.level;
    // Levels are the host's working data, not a player's business. The
    // selection sheet is also a host view, so keep its court markers as
    // informative as the live host board.
    final levelLabel = (mode.isHostView || mode.isSelection) && level != null
        ? levelShortLabel(level)
        : null;
    final isDark = theme.brightness == Brightness.dark;
    final pair = _pairColorsFor(pairNumber, isDark: isDark);
    final borderColor = isActive ? theme.colorScheme.primary : pair.border;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Semantics(
          button: onTap != null,
          label: l10n.playerName(player),
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _Marker(
                  isNameMode: isNameMode,
                  background: pair.background,
                  border: borderColor,
                  borderWidth: isActive ? 3.0 : 2.0,
                  isDark: isDark,
                  child: Text(
                    _label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: isNameMode
                        ? TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: pair.text,
                            height: 1.2,
                          )
                        : TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: pair.text,
                            height: 1,
                          ),
                  ),
                ),
                Positioned(
                  top: isNameMode ? -10 : -8,
                  left: isNameMode ? -10 : -8,
                  child: _GenderBadge(gender: player.gender, isDark: isDark),
                ),
                if (levelLabel != null)
                  Positioned(
                    top: isNameMode ? -12 : -10,
                    right: isNameMode ? -10 : -12,
                    child: _LevelBadge(
                      label: levelLabel,
                      color: pair.border,
                      isDark: isDark,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (mode.isSelection && onRemove != null)
          Positioned(
            right: -6,
            bottom: -6,
            child: _RemoveSelectionButton(onPressed: onRemove!),
          ),
      ],
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
    required this.isDark,
    required this.child,
  });

  final bool isNameMode;
  final Color background;
  final Color border;
  final double borderWidth;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: background,
      shape: isNameMode ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: isNameMode ? BorderRadius.circular(8) : null,
      border: Border.all(color: border, width: borderWidth),
      boxShadow: [
        BoxShadow(
          blurRadius: isDark ? 10 : 4,
          offset: const Offset(0, 3),
          color: isDark ? const Color(0x99000000) : const Color(0x26000000),
        ),
      ],
    );

    if (!isNameMode) {
      return Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: decoration,
        child: child,
      );
    }

    return Container(
      width: 96,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.center,
      decoration: decoration,
      child: child,
    );
  }
}

/// Top-left circle carrying the player's gender, shown in every mode — the
/// web renders it as decorative (`aria-hidden`), never gated on host view.
class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender, this.isDark = false});

  final Gender? gender;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = switch (gender) {
      Gender.male => const Color(0xFF3182CE),
      Gender.female => const Color(0xFFD53F8C),
      Gender.other => const Color(0xFF805AD5),
      null => const Color(0xFF718096),
    };
    final icon = genderIcon(gender);

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xE6FFFFFF) : Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 2,
            offset: Offset(0, 1),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

/// Top-right pill carrying the player's level, coloured to match their pair.
/// Host view only — a level is the host's working data, not a player's.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.label,
    required this.color,
    this.isDark = false,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xE6FFFFFF) : Colors.white,
          width: 2,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Explicitly removes this player from a seat in the pairing sheet.
class _RemoveSelectionButton extends StatelessWidget {
  const _RemoveSelectionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).hostAddPlayerRemove;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: const Color(0xFFEF4444),
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('remove-selected-court-player'),
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const SizedBox.square(
              dimension: 22,
              child: Icon(AppIcons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blue for the left-column team, orange for the right with dark mode support.
///
/// Dark fills are fully opaque tailwind-900 tones, not a translucent black
/// tinted with the pair colour. A translucent fill lets the court's own green
/// bleed through and desaturate it, which is what made markers look sunken
/// into the surface instead of sitting on top of it.
({Color background, Color border, Color text}) _pairColorsFor(
  int pairNumber, {
  bool isDark = false,
}) {
  if (pairNumber == 2) {
    return isDark
        ? (
            background: const Color(0xFF7C2D12), // orange.900
            border: const Color(0xFFFB923C),
            text: const Color(0xFFFED7AA),
          )
        : (
            background: const Color(0xFFFFF7ED),
            border: const Color(0xFFF97316),
            text: const Color(0xFFF97316),
          );
  }
  return isDark
      ? (
          background: const Color(0xFF1E3A8A), // blue.900
          border: const Color(0xFF60A5FA),
          text: const Color(0xFFBFDBFE),
        )
      : (
          background: const Color(0xFFEFF6FF),
          border: const Color(0xFF3B82F6),
          text: const Color(0xFF3B82F6),
        );
}
