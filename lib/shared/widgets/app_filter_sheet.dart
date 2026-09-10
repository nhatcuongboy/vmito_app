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
    final bgColor =
        isRed ? scheme.error : scheme.primary.withValues(alpha: .12);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
                titleTrailing: activeCount > 0
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
                child: Row(
                  children: [
                    Flexible(
                      child: OutlinedButton.icon(
                        key: resetButtonKey,
                        onPressed: actionsEnabled ? onReset : null,
                        icon: const Icon(AppIcons.history, size: 18),
                        label: Text(resetLabel),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          foregroundColor: palette.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: applyButtonKey,
                        onPressed: actionsEnabled ? onApply : null,
                        icon: const Icon(AppIcons.search, size: 18),
                        label: Text(applyLabel),
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
    final header = Row(
      children: [
        if (widget.icon case final icon?) ...[
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            widget.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
        if (count > 0) ...[
          const SizedBox(width: AppSpacing.xs),
          AppFilterCountBadge(label: '$count', isRed: true),
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

              final hasLeading = avatar != null;

              return FilterChip(
                key: itemKey?.call(value),
                avatar: avatar,
                label: Text(label(value)),
                labelStyle: TextStyle(
                  color: isSelected ? scheme.primary : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.0,
                ),
                labelPadding: EdgeInsets.only(
                  left: hasLeading ? 2.0 : 4.0,
                  right: 4.0,
                ),
                selected: isSelected,
                showCheckmark: false,
                backgroundColor: theme.colorScheme.surface,
                selectedColor: scheme.primary.withValues(alpha: .12),
                side: BorderSide(
                  color: isSelected ? scheme.primary : palette.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                onSelected: enabled ? (_) => onSelected(value) : null,
              );
            },
          ),
        ],
      ],
    );
  }
}
