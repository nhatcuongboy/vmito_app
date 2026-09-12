import 'package:flutter/material.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';

/// An avatar in a medal-coloured ring with the rank chip overlapping its foot.
/// Shared by the podium cards and the top-3 celebration.
class MedalAvatar extends StatelessWidget {
  const MedalAvatar({
    required this.name,
    required this.imageUrl,
    required this.rank,
    required this.radius,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final int rank;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final medal = medalVisualsFor(Theme.of(context).brightness, rank);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        LeaderboardAvatar(
          name: name,
          imageUrl: imageUrl,
          radius: radius,
          borderColor: medal.ring,
          borderWidth: 3,
        ),
        Positioned(
          bottom: -9,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal.solid,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
