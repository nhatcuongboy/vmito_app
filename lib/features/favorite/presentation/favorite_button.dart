import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
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
    this.overlay = true,
    this.showCount = true,
    super.key,
  });

  final FavoriteType type;
  final String targetId;
  final bool overlay;
  final bool showCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final target = (type: type, id: targetId);
    final summary =
        ref.watch(favoriteControllerProvider(target)).value ??
        const FavoriteSummary();

    final foregroundColor = overlay
        ? Colors.white
        : theme.colorScheme.onSurface;
    final dividerColor = overlay
        ? Colors.white.withValues(alpha: 0.2)
        : theme.dividerColor;
    final displayCount = showCount && summary.favoriteCount > 0;

    return Material(
      color: overlay ? Colors.black.withValues(alpha: 0.6) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(context, ref, target),
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: displayCount ? 34 : (overlay ? 32 : 28),
                height: 32,
                child: Center(
                  child: Icon(
                    summary.isFavorite
                        ? AppIcons.favoriteFilled
                        : AppIcons.favorite,
                    size: 18,
                    semanticLabel: summary.isFavorite
                        ? l10n.favoriteRemove
                        : l10n.favoriteAdd,
                    color: summary.isFavorite
                        ? AppColors.destructive
                        : foregroundColor,
                  ),
                ),
              ),
              if (displayCount) ...[
                Container(
                  width: 1,
                  height: 32,
                  color: dividerColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${summary.favoriteCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
