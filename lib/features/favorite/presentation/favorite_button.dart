import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/application/favorite_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

enum FavoriteButtonVariant { overlayDark, card, surface }

/// Heart plus count, ported from the web app's `FavoriteEngagementControl`
/// in its `overlay-dark` variant.
///
/// Sits on a photo, so it carries its own dark pill rather than relying on
/// the surrounding surface for contrast.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.type,
    required this.targetId,
    this.initialIsFavorite = false,
    this.variant,
    this.overlay = true,
    this.overlayColor,
    this.showCount = true,
    this.size = controlHeight,
    super.key,
  });

  static const controlHeight = 32.0;
  static const detailControlSize = 36.0;

  final FavoriteType type;
  final String targetId;
  final bool initialIsFavorite;
  final FavoriteButtonVariant? variant;
  final bool overlay;
  final Color? overlayColor;
  final bool showCount;
  final double size;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.75,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.75,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.35,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isSignedInProvider)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final target = (
      type: widget.type,
      id: widget.targetId,
      initialIsFavorite: widget.initialIsFavorite,
    );

    ref.listen(favoriteControllerProvider(target), (previous, next) {
      final prevFav = previous?.value?.isFavorite;
      final nextFav = next.value?.isFavorite;
      if (prevFav != null && nextFav != null && prevFav != nextFav) {
        unawaited(_animController.forward(from: 0));
      }
    });

    final favoriteState = ref.watch(favoriteControllerProvider(target));
    final summary =
        favoriteState.value ??
        FavoriteSummary(isFavorite: widget.initialIsFavorite);
    final variant =
        widget.variant ??
        (widget.overlay
            ? FavoriteButtonVariant.overlayDark
            : FavoriteButtonVariant.surface);
    final isCard = variant == FavoriteButtonVariant.card;
    final isDark = variant == FavoriteButtonVariant.overlayDark;

    final foregroundColor = isDark
        ? Colors.white
        : isCard
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : theme.dividerColor;
    final displayCount = widget.showCount && summary.favoriteCount > 0;

    return Material(
      color: switch (variant) {
        FavoriteButtonVariant.overlayDark =>
          widget.overlayColor ?? Colors.black.withValues(alpha: 0.6),
        FavoriteButtonVariant.card => Colors.white.withValues(alpha: 0.92),
        FavoriteButtonVariant.surface => Colors.transparent,
      },
      elevation: isCard ? 2 : 0,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: favoriteState.isLoading || _isMutating
            ? null
            : () => _toggle(context, ref, target),
        child: SizedBox(
          height: widget.size,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: displayCount
                    ? widget.size + 2
                    : widget.size == FavoriteButton.controlHeight &&
                          variant == FavoriteButtonVariant.surface
                    ? widget.size - 4
                    : widget.size,
                height: widget.size,
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
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
              ),
              if (displayCount) ...[
                Container(
                  width: 1,
                  height: widget.size,
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
    if (_isMutating) return;
    final l10n = AppLocalizations.of(context);
    final wasFavorite =
        ref.read(favoriteControllerProvider(target)).value?.isFavorite ??
        widget.initialIsFavorite;
    setState(() => _isMutating = true);
    try {
      if (wasFavorite) {
        final confirmed = await showAppConfirmDialog(
          context,
          type: AppConfirmDialogType.destructive,
          title: l10n.favoriteRemoveConfirmTitle,
          content: l10n.favoriteRemoveConfirmMessage,
          confirmLabel: l10n.favoriteRemoveConfirmAction,
        );
        if (confirmed != true || !context.mounted) return;
      }

      final signedIn = await ref
          .read(favoriteControllerProvider(target).notifier)
          .toggle(fallbackIsFavorite: widget.initialIsFavorite);
      if (signedIn && context.mounted) {
        if (wasFavorite) {
          _showRemovedToast(context, l10n, target);
        } else {
          _showSavedToast(context, l10n, GoRouter.of(context), target.type);
        }
      }
    } on ApiException {
      if (context.mounted) {
        _showErrorToast(
          context,
          wasFavorite ? l10n.favoriteRemoveFailed : l10n.favoriteAddFailed,
        );
      }
    } on Object {
      if (context.mounted) {
        _showErrorToast(
          context,
          wasFavorite ? l10n.favoriteRemoveFailed : l10n.favoriteAddFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showSavedToast(
    BuildContext context,
    AppLocalizations l10n,
    GoRouter router,
    FavoriteType type,
  ) {
    _showFavoriteToast(
      context,
      icon: AppIcons.favoriteFilled,
      iconColor: AppColors.destructive,
      message: l10n.favoriteSaved,
      actionLabel: l10n.favoriteViewList,
      onAction: () => router.go(AppRoutes.favoritesFor(type.wireValue)),
      isSaved: true,
    );
  }

  void _showRemovedToast(
    BuildContext context,
    AppLocalizations l10n,
    FavoriteTarget target,
  ) {
    _showFavoriteToast(
      context,
      icon: AppIcons.favorite,
      message: l10n.favoriteRemoved,
      actionLabel: l10n.favoriteUndo,
      onAction: () => unawaited(_undo(l10n, target)),
    );
  }

  Future<void> _undo(
    AppLocalizations l10n,
    FavoriteTarget target,
  ) async {
    if (_isMutating) return;
    if (mounted) setState(() => _isMutating = true);
    try {
      await ref
          .read(favoriteControllerProvider(target).notifier)
          .setFavorite(isFavorite: true);
      if (mounted) {
        _showSavedToast(context, l10n, GoRouter.of(context), target.type);
      }
    } on Object {
      if (mounted) _showErrorToast(context, l10n.favoriteAddFailed);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showErrorToast(BuildContext context, String message) {
    _showFavoriteToast(
      context,
      icon: AppIcons.error,
      iconColor: AppColors.warning,
      message: message,
      isError: true,
    );
  }

  void _showFavoriteToast(
    BuildContext context, {
    required IconData icon,
    required String message,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    bool isSaved = false,
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final messenger = ScaffoldMessenger.of(context);

    final resolvedIconColor =
        iconColor ??
        (isSaved
            ? AppColors.destructive
            : isError
            ? AppColors.warning
            : palette.mutedForeground);

    final badgeColor = isSaved
        ? AppColors.destructive.withValues(alpha: 0.16)
        : isError
        ? AppColors.warning.withValues(alpha: 0.18)
        : theme.colorScheme.onInverseSurface.withValues(alpha: 0.1);

    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.sm + AppSpacing.xs,
            0,
            AppSpacing.sm + AppSpacing.xs,
            AppSpacing.sm + AppSpacing.xs,
          ),
          padding: EdgeInsets.zero,
          content: Container(
            key: const Key('favorite-toast-surface'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm + AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  key: const Key('favorite-toast-badge'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      key: const Key('favorite-toast-icon'),
                      size: 17,
                      color: resolvedIconColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 18 / 14,
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 1,
                    height: 20,
                    color: theme.colorScheme.onInverseSurface.withValues(
                      alpha: 0.16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    key: const Key('favorite-toast-action'),
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: palette.success,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.success,
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
}
