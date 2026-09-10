import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Standard bottom sheet header: title (+ optional subtitle/leading icon),
/// an optional close button, and a divider separating it from the body.
///
/// Reused across full-screen and `DraggableScrollableSheet`-based sheets so
/// every sheet reads the same way. See docs/DESIGN_SYSTEM.md.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    required this.title,
    this.subtitle,
    this.titleTrailing,
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingButtonKey,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.showCloseButton = true,
    this.closeButtonEnabled = true,
    this.onClose,
    this.closeButtonKey,
    this.showDivider = false,
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
  final Widget? titleTrailing;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Key? leadingButtonKey;
  final String? leadingTooltip;
  final VoidCallback? onLeadingPressed;
  final bool showCloseButton;

  /// Disables the close button (e.g. while a submit is in flight) instead of
  /// hiding it, so the header doesn't shift.
  final bool closeButtonEnabled;

  /// Defaults to a plain pop when omitted.
  final VoidCallback? onClose;
  final Key? closeButtonKey;

  /// Whether to show a divider line separating the header from the body.
  /// Defaults to `false` so sheets maintain a clean header without a bottom
  /// border (consistent with modal forms like Edit Session).
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  static TextStyle? titleTextStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      );

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
            children: [
              if (leadingIcon != null) ...[
                if (onLeadingPressed != null)
                  IconButton(
                    key: leadingButtonKey,
                    tooltip: leadingTooltip,
                    onPressed: onLeadingPressed,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      leadingIcon,
                      size: 20,
                      color: leadingIconColor,
                    ),
                  )
                else
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleTextStyle(context),
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
              if (titleTrailing case final trailing?) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing,
              ],
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
        if (showDivider) Divider(height: 1, color: palette.border),
      ],
    );
  }
}
