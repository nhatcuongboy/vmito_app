import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_adaptive_grid.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_card_parts.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Empty state for a primary section (managed / joined clubs). Secondary
/// sections (requests, approvals) hide when empty instead.
class ClubEmptyView extends StatelessWidget {
  const ClubEmptyView({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = clubPaletteOf(theme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ClubCardShell.radius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.brandSurface,
              borderRadius: BorderRadius.circular(ClubCardShell.radius),
            ),
            child: Icon(icon, size: 28, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A section that exists only while it has something to show: hidden while
/// loading and when empty, rendered with its header on data or error.
List<Widget> clubWaitingSection<T>({
  required AsyncValue<List<T>> value,
  required Widget Function(int? count) header,
  required Widget Function(List<T> items) body,
  required VoidCallback onRetry,
}) {
  final content = value.when<Widget?>(
    data: (items) => items.isEmpty ? null : body(items),
    loading: () => null,
    error: (error, _) => ClubInlineError(error: error, onRetry: onRetry),
  );
  if (content == null) return const [];
  return [
    header(value.asData?.value.length),
    const SizedBox(height: 12),
    content,
    const SizedBox(height: AppSpacing.lg),
  ];
}

class ClubInlineError extends StatelessWidget {
  const ClubInlineError({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: AppErrorView(error: error, onRetry: onRetry),
  );
}

/// Placeholders shaped like `ClubListCard`: square avatar + three text lines.
class ClubCardSkeletonList extends StatelessWidget {
  const ClubCardSkeletonList({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).commonLoading,
    child: ExcludeSemantics(
      child: ClubAdaptiveGrid(
        itemCount: count,
        itemBuilder: (_, _) => const _ClubCardSkeleton(),
      ),
    ),
  );
}

class _ClubCardSkeleton extends StatelessWidget {
  const _ClubCardSkeleton();

  @override
  Widget build(BuildContext context) => const ClubCardShell(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: AppShimmer(
        child: Row(
          children: [
            AppSkeletonBox(width: 52, height: 52, radius: AppRadius.xl),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.65,
                    child: AppSkeletonBox(height: 16),
                  ),
                  SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.45,
                    child: AppSkeletonBox(height: 12),
                  ),
                  SizedBox(height: 6),
                  FractionallySizedBox(
                    widthFactor: 0.55,
                    child: AppSkeletonBox(height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
