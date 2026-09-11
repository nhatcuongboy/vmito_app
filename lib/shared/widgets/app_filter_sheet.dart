import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

Future<T?> showAppFilterSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: builder,
);

class AppFilterCountBadge extends StatelessWidget {
  const AppFilterCountBadge({
    required this.label,
    this.isRed = false,
    super.key,
  });

  final String label;
  final bool isRed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = isRed
        ? scheme.error
        : scheme.primary.withValues(alpha: .12);
    final textColor = isRed ? scheme.onError : scheme.primary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// A single selectable filter chip, shared by [AppFilterOptionGroup] and any
/// standalone toggle chip (e.g. the "Còn chỗ trống" / "Gần tôi" quick
/// filters) so every chip in a filter sheet renders with identical padding
/// and label styling instead of each call site re-declaring its own
/// [FilterChip] parameters.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;

  /// Symmetric padding around the chip content.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm + 4,
    vertical: AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final scheme = theme.colorScheme;

    final leading = avatar == null
        ? null
        : SizedBox.square(
            dimension: 16,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 16,
                  color: selected ? scheme.primary : palette.mutedForeground,
                ),
                child: avatar!,
              ),
            ),
          );

    final textStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: selected ? scheme.primary : scheme.onSurface,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      height: 20 / 14,
      leadingDistribution: TextLeadingDistribution.even,
    );

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(
            label,
            style: textStyle,
            strutStyle: const StrutStyle(
              fontSize: 14,
              height: 20 / 14,
              forceStrutHeight: true,
            ),
          ),
        ],
      ),
      labelStyle: textStyle,
      labelPadding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: selected,
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surface,
      selectedColor: scheme.primary.withValues(alpha: .12),
      side: BorderSide(
        color: selected ? scheme.primary : palette.border,
        width: 1.0,
      ),
      padding: padding,
      onSelected: onSelected,
    );
  }
}

/// The reset/apply (or cancel/done) button pair used at the bottom of every
/// filter sheet and picker. A [LayoutBuilder] — rather than Flexible/
/// Expanded flex ratios — lets the secondary button hug its own content
/// width and the primary button claim exactly what's left: Flutter's Row
/// flex algorithm pre-allocates each flex child's share in a single pass, so
/// an Expanded sibling can't reclaim space a smaller Flexible one didn't
/// use, which used to strand the primary button short of the trailing edge.
/// The [ConstrainedBox] still caps the secondary button's width (with a
/// [FittedBox] scale-down fallback) so it can't push the primary button
/// below a usable width at very large text scales.
class AppSheetFooterButtons extends StatelessWidget {
  const AppSheetFooterButtons({
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryKey,
    this.primaryKey,
    this.secondaryIsDestructive = false,
    super.key,
  });

  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final Key? secondaryKey;
  final Key? primaryKey;
  final bool secondaryIsDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryStyle = secondaryIsDestructive
        ? OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: theme.colorScheme.error.withValues(alpha: .08),
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: .3),
            ),
            foregroundColor: theme.colorScheme.error,
          )
        : OutlinedButton.styleFrom(minimumSize: const Size(0, 48));

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: secondaryKey,
                onPressed: onSecondary,
                icon: Icon(secondaryIcon, size: 18),
                label: Text(secondaryLabel),
                style: secondaryStyle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.icon(
              key: primaryKey,
              onPressed: onPrimary,
              icon: Icon(primaryIcon, size: 18),
              label: Text(primaryLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppFilterSheetScaffold extends StatelessWidget {
  const AppFilterSheetScaffold({
    required this.title,
    required this.body,
    required this.resetLabel,
    required this.applyLabel,
    required this.onReset,
    required this.onApply,
    this.activeCount = 0,
    this.activeCountLabel,
    this.onClose,
    this.resetButtonKey,
    this.applyButtonKey,
    this.closeButtonKey,
    this.actionsEnabled = true,
    this.showActiveCount = true,
    super.key,
  });

  final String title;
  final Widget body;
  final String resetLabel;
  final String applyLabel;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final int activeCount;
  final String? activeCountLabel;
  final VoidCallback? onClose;
  final Key? resetButtonKey;
  final Key? applyButtonKey;
  final Key? closeButtonKey;
  final bool actionsEnabled;
  final bool showActiveCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        child: SizedBox(
          width: double.infinity,
          height: size.height * (size.width < 600 ? .92 : .86),
          child: Column(
            children: [
              AppSheetHeader(
                title: title,
                titleTrailing: showActiveCount && activeCount > 0
                    ? AppFilterCountBadge(
                        label: activeCountLabel ?? '$activeCount',
                        isRed: true,
                      )
                    : null,
                closeButtonKey: closeButtonKey,
                onClose: onClose,
                showDivider: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: body,
                ),
              ),
              AppSheetActionBar(
                child: AppSheetFooterButtons(
                  secondaryKey: resetButtonKey,
                  secondaryLabel: resetLabel,
                  secondaryIcon: AppIcons.history,
                  secondaryIsDestructive: true,
                  onSecondary: actionsEnabled ? onReset : null,
                  primaryKey: applyButtonKey,
                  primaryLabel: applyLabel,
                  primaryIcon: AppIcons.search,
                  onPrimary: actionsEnabled ? onApply : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFilterSection extends StatefulWidget {
  const AppFilterSection({
    required this.title,
    required this.child,
    this.icon,
    this.summary,
    this.selectedCount,
    this.collapsible = false,
    this.initiallyExpanded = false,
    this.showDivider = true,
    super.key,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? summary;
  final int? selectedCount;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showDivider;

  @override
  State<AppFilterSection> createState() => _AppFilterSectionState();
}

class _AppFilterSectionState extends State<AppFilterSection> {
  late bool _expanded = !widget.collapsible || widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final count = widget.selectedCount ?? 0;
    // The badge sits directly against the title (not pinned to the far
    // right of the row) — Flexible, not Expanded, so title+badge cluster
    // together and any leftover width trails after them instead of
    // stranding the badge far from its label. A trailing Spacer only
    // appears when there's a summary or chevron to push to the row's edge.
    final hasTrailing =
        (count == 0 && widget.summary != null) || widget.collapsible;
    final header = Row(
      children: [
        if (widget.icon case final icon?) ...[
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: AppSpacing.xs),
          AppFilterCountBadge(label: '$count', isRed: true),
        ],
        if (hasTrailing) const Spacer(),
        if (count == 0)
          if (widget.summary case final summary?)
            Flexible(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
        if (widget.collapsible) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(_expanded ? AppIcons.chevronUp : AppIcons.chevronDown, size: 20),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.collapsible)
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: header,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: header,
          ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(
              top: widget.collapsible ? AppSpacing.xs : 0,
              bottom: AppSpacing.md,
            ),
            child: widget.child,
          ),
        if (widget.showDivider)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Divider(color: palette.border),
          ),
      ],
    );
  }
}

class AppFilterOptionGroup<T> extends StatelessWidget {
  const AppFilterOptionGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
    this.avatarBuilder,
    this.itemKey,
    this.enabled = true,
    super.key,
  });

  final Iterable<T> values;
  final Set<T> selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final IconData? Function(T value)? icon;
  final Widget? Function(BuildContext context, T value, bool isSelected)?
  avatarBuilder;
  final Key? Function(T value)? itemKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final scheme = theme.colorScheme;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values) ...[
          Builder(
            builder: (context) {
              final isSelected = selected.contains(value);
              final customAvatar = avatarBuilder?.call(
                context,
                value,
                isSelected,
              );
              final iconData = icon?.call(value);

              final Widget? avatar =
                  customAvatar ??
                  (iconData != null
                      ? Icon(
                          iconData,
                          size: 16,
                          color: isSelected
                              ? scheme.primary
                              : palette.mutedForeground,
                        )
                      : null);

              return AppFilterChip(
                key: itemKey?.call(value),
                label: label(value),
                selected: isSelected,
                avatar: avatar,
                onSelected: enabled ? (_) => onSelected(value) : null,
              );
            },
          ),
        ],
      ],
    );
  }
}
