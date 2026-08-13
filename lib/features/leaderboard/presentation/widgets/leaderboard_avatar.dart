import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';

class LeaderboardAvatar extends StatelessWidget {
  const LeaderboardAvatar({
    required this.name,
    required this.imageUrl,
    required this.radius,
    this.borderColor,
    this.borderWidth = 0,
    super.key,
  });

  final String? name;
  final String? imageUrl;
  final double radius;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl;
    final placeholder = _AvatarPlaceholder(name: name, radius: radius);
    final avatar = ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: image == null || image.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
    if (borderColor == null || borderWidth == 0) return avatar;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: Padding(padding: EdgeInsets.all(borderWidth), child: avatar),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name, required this.radius});

  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: trimmed.isEmpty
            ? Icon(
                AppIcons.user,
                size: radius,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )
            : Text(
                trimmed.characters.first.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: radius * .8,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
