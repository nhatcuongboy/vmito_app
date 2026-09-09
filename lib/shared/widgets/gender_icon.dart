import 'package:flutter/material.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Icon for a player's gender.
///
/// Silhouettes rather than the Mars/Venus glyphs, which read as ambiguous at
/// the small sizes these badges are drawn at.
IconData genderIcon(Gender? gender) => switch (gender) {
  Gender.male => Icons.man,
  Gender.female => Icons.woman,
  _ => Icons.person,
};
