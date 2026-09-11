import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Loading placeholder with the `HostTournamentCard` footprint. The card frame
/// stays still; only its content pulses.
class HostTournamentCardSkeleton extends StatelessWidget {
  const HostTournamentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.extension<AppPalette>()!.border),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, AppSpacing.md, 12),
        child: AppShimmer(
          child: Row(
            children: [
              AppSkeletonBox(width: 56, height: 56, radius: AppRadius.xl),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(
                      width: 86,
                      height: 20,
                      radius: AppRadius.pill,
                    ),
                    SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: AppSkeletonBox(height: 18),
                    ),
                    SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: AppSkeletonBox(height: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              AppSkeletonBox(width: 20, height: 20, radius: AppRadius.md),
            ],
          ),
        ),
      ),
    );
  }
}
