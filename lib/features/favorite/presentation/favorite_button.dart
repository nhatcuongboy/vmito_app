import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/favorite/application/favorite_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';

/// Heart plus count, ported from the web app's `FavoriteEngagementControl`
/// in its `overlay-dark` variant.
///
/// Sits on a photo, so it carries its own dark pill rather than relying on
/// the surrounding surface for contrast.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    required this.type,
    required this.targetId,
    super.key,
  });

  final FavoriteType type;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final target = (type: type, id: targetId);
    final summary =
        ref.watch(favoriteControllerProvider(target)).value ??
        const FavoriteSummary();

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(context, ref, target),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.sm + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                summary.isFavorite
                    ? AppIcons.favorite
                    : AppIcons.favorite,
                size: 20,
                semanticLabel: summary.isFavorite
                    ? l10n.favoriteRemove
                    : l10n.favoriteAdd,
                color: summary.isFavorite ? theme.colorScheme.error : Colors
                    .white,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '${summary.favoriteCount}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    FavoriteTarget target,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final signedIn = await ref
          .read(favoriteControllerProvider(target).notifier)
          .toggle();
      if (!signedIn && context.mounted) {
        unawaited(
          showLoginPromptDialog(
            context,
            featureName: l10n.loginRequiredFavorite,
          ),
        );
      }
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
    }
  }
}
