import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Standard bottom sheet header: title (+ optional subtitle/leading icon) and
/// an optional close button.
///
/// Reused across full-screen and `DraggableScrollableSheet`-based sheets so
/// every sheet reads the same way. See docs/DESIGN_SYSTEM.md.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingIconColor,
    this.onLeadingPressed,
    this.leadingButtonKey,
    this.leadingTooltip,
    this.showCloseButton = true,
    this.closeButtonEnabled = true,
    this.onClose,
    this.closeButtonKey,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final VoidCallback? onLeadingPressed;
  final Key? leadingButtonKey;
  final String? leadingTooltip;
  final bool showCloseButton;

  /// Disables the close button (e.g. while a submit is in flight) instead of
  /// hiding it, so the header doesn't shift.
  final bool closeButtonEnabled;

  /// Defaults to a plain pop when omitted.
  final VoidCallback? onClose;
  final Key? closeButtonKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                if (onLeadingPressed case final onPressed?)
                  IconButton(
                    key: leadingButtonKey,
                    tooltip: leadingTooltip,
                    onPressed: onPressed,
                    icon: Icon(
                      leadingIcon,
                      size: 20,
                      color: leadingIconColor,
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Icon(
                      leadingIcon,
                      size: 20,
                      color: leadingIconColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle case final subtitle?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showCloseButton)
                IconButton(
                  key: closeButtonKey,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  icon: const Icon(AppIcons.close),
                  onPressed: closeButtonEnabled
                      ? onClose ?? () => Navigator.of(context).pop()
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
