import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/welcome_popup/application/welcome_popup_controller.dart';
import 'package:vmito_app/features/welcome_popup/domain/welcome_popup.dart';

/// Mobile-redesigned welcome popup: a full-bleed hero image with a
/// translucent close overlay (the `app_lightbox.dart` pattern) rather than
/// the web modal's separate header bar, since a small screen has no room to
/// spare for chrome around the image.
class WelcomePopupDialog extends ConsumerWidget {
  const WelcomePopupDialog({required this.popup, super.key});

  final WelcomePopup popup;

  static Future<void> show(
    BuildContext context, {
    required WelcomePopup popup,
  }) => showDialog<void>(
    context: context,
    builder: (context) => WelcomePopupDialog(popup: popup),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final hasImage = popup.imageUrl?.isNotEmpty ?? false;
    final hasCta =
        (popup.ctaLabel?.isNotEmpty ?? false) &&
        (popup.ctaUrl?.isNotEmpty ?? false);

    // Every path out of this dialog — the X, the barrier, the system back
    // gesture, the CTA — counts as "dismissed" for this version, so a single
    // [PopScope] callback is the one place that persists it. `close()`/
    // `openCta()` below only ever call `Navigator.pop`, never dismiss
    // directly, so it can never fire twice.
    void close() => Navigator.of(context).pop();

    Future<void> openCta() async {
      final ctaUrl = popup.ctaUrl!;
      Navigator.of(context).pop();
      final uri = Uri.tryParse(ctaUrl);
      final isExternal =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      if (isExternal) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        await context.push(ctaUrl);
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref.read(welcomePopupControllerProvider.notifier).dismiss(),
          );
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasImage)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: popup.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              ColoredBox(color: palette.muted),
                          errorWidget: (context, url, error) =>
                              ColoredBox(color: palette.muted),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: IconButton(
                          key: const Key('welcome-popup-close-button'),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: const Icon(AppIcons.close, color: Colors.white),
                          onPressed: close,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: const Key('welcome-popup-close-button'),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: const Icon(AppIcons.close),
                          onPressed: close,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    hasImage ? AppSpacing.lg : 0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        popup.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        popup.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                      if (hasCta) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('welcome-popup-cta-button'),
                            onPressed: () => unawaited(openCta()),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md - 2,
                              ),
                            ),
                            child: Text(
                              popup.ctaLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
