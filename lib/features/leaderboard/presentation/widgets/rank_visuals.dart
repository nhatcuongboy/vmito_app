import 'package:flutter/material.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

/// Podium medal colours for ranks 1-3.
///
/// Deliberately unrelated to the account tier colours (a rank-3 player can hold
/// a GOLD tier), mirroring the same note in `vmito-fe/PodiumCard.tsx`.
class MedalVisuals {
  const MedalVisuals({
    required this.solid,
    required this.ring,
    required this.glow,
  });

  /// Medal fill: the rank chip and the champion border.
  final Color solid;

  /// The avatar ring — a lighter (light mode) or darker (dark mode) shade.
  final Color ring;

  /// Card gradient start behind the champion. Barely tinted on purpose.
  final Color glow;
}

/// Account tier colours, ported from `vmito-fe/TierBadge.tsx`'s `TIER_COLORS`.
class TierVisuals {
  const TierVisuals({
    required this.background,
    required this.foreground,
    required this.solid,
    required this.emoji,
  });

  final Color background;
  final Color foreground;
  final Color solid;
  final String emoji;
}

const _lightMedals = <int, MedalVisuals>{
  1: MedalVisuals(
    solid: Color(0xFFF5B301),
    ring: Color(0xFFFDE68A),
    glow: Color(0xFFFFF8E1),
  ),
  2: MedalVisuals(
    solid: Color(0xFFA8ADB8),
    ring: Color(0xFFE2E5EA),
    glow: Color(0xFFF4F5F7),
  ),
  3: MedalVisuals(
    solid: Color(0xFFC1783C),
    ring: Color(0xFFECCAA8),
    glow: Color(0xFFFBF1E7),
  ),
};

const _darkMedals = <int, MedalVisuals>{
  1: MedalVisuals(
    solid: Color(0xFFF5C445),
    ring: Color(0xFF8A6A12),
    glow: Color(0xFF3A2F0C),
  ),
  2: MedalVisuals(
    solid: Color(0xFFC2C7D1),
    ring: Color(0xFF5A5F6B),
    glow: Color(0xFF2B2E33),
  ),
  3: MedalVisuals(
    solid: Color(0xFFD8945A),
    ring: Color(0xFF7A4D24),
    glow: Color(0xFF33241A),
  ),
};

const _lightTiers = <RankingTier, TierVisuals>{
  RankingTier.bronze: TierVisuals(
    background: Color(0xFFF5E0D0),
    foreground: Color(0xFF8D5524),
    solid: Color(0xFFCD7F32),
    emoji: '🥉',
  ),
  RankingTier.silver: TierVisuals(
    background: Color(0xFFE8E8EE),
    foreground: Color(0xFF5A5A6E),
    solid: Color(0xFF9EA3B0),
    emoji: '🥈',
  ),
  RankingTier.gold: TierVisuals(
    background: Color(0xFFFDF0C8),
    foreground: Color(0xFF8A6D00),
    solid: Color(0xFFE6B800),
    emoji: '🥇',
  ),
  RankingTier.platinum: TierVisuals(
    background: Color(0xFFD9F4F0),
    foreground: Color(0xFF0E6E63),
    solid: Color(0xFF2EC4B6),
    emoji: '💠',
  ),
  RankingTier.diamond: TierVisuals(
    background: Color(0xFFE0ECFF),
    foreground: Color(0xFF1D4FD7),
    solid: Color(0xFF5B8DEF),
    emoji: '💎',
  ),
};

// Backgrounds are the tier `solid` at 20% so the badge tints whatever dark
// surface it lands on; foregrounds are lightened to clear 4.5:1 against it.
const _darkTiers = <RankingTier, TierVisuals>{
  RankingTier.bronze: TierVisuals(
    background: Color(0x33CD7F32),
    foreground: Color(0xFFE0A268),
    solid: Color(0xFFCD7F32),
    emoji: '🥉',
  ),
  RankingTier.silver: TierVisuals(
    background: Color(0x339EA3B0),
    foreground: Color(0xFFC8CCD6),
    solid: Color(0xFF9EA3B0),
    emoji: '🥈',
  ),
  RankingTier.gold: TierVisuals(
    background: Color(0x33E6B800),
    foreground: Color(0xFFF5D454),
    solid: Color(0xFFE6B800),
    emoji: '🥇',
  ),
  RankingTier.platinum: TierVisuals(
    background: Color(0x332EC4B6),
    foreground: Color(0xFF5FE0D4),
    solid: Color(0xFF2EC4B6),
    emoji: '💠',
  ),
  RankingTier.diamond: TierVisuals(
    background: Color(0x335B8DEF),
    foreground: Color(0xFF93B4F7),
    solid: Color(0xFF5B8DEF),
    emoji: '💎',
  ),
};

/// Ranks outside 1-3 fall back to bronze, matching the web podium.
MedalVisuals medalVisualsFor(Brightness brightness, int rank) {
  final medals = brightness == Brightness.dark ? _darkMedals : _lightMedals;
  return medals[rank] ?? medals[3]!;
}

TierVisuals tierVisualsFor(Brightness brightness, RankingTier tier) =>
    (brightness == Brightness.dark ? _darkTiers : _lightTiers)[tier]!;

/// The medal palette the celebration confetti draws from.
List<Color> medalConfettiColors(Brightness brightness) => [
  for (var rank = 1; rank <= 3; rank++) medalVisualsFor(brightness, rank).solid,
  medalVisualsFor(brightness, 1).ring,
];
