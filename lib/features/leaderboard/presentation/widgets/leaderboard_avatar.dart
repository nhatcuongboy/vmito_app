import 'package:flutter/material.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';

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
  Widget build(BuildContext context) => UserAvatar(
    name: name,
    imageUrl: imageUrl,
    size: radius * 2,
    borderColor: borderColor,
    borderWidth: borderWidth,
  );
}
