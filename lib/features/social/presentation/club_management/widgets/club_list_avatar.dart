import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';

/// A club's rounded-square avatar. Clubs are always square and people are
/// always round (`UserAvatar`), so the shape alone tells the two apart.
///
/// Takes a name + URL rather than a model because it renders both a
/// `ClubSummary` and the slimmer `ClubJoinRequestClub`.
class ClubListAvatar extends StatelessWidget {
  const ClubListAvatar({
    required this.name,
    this.imageUrl,
    this.size = 52,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim();
    final trimmedName = name.trim();
    final fallback = Center(
      child: trimmedName.isEmpty
          ? Icon(
              AppIcons.clubs,
              size: size * 0.45,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : Text(
              trimmedName[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: size * 0.42,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: clubPaletteOf(theme).border),
        color: theme.colorScheme.primaryContainer,
      ),
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
