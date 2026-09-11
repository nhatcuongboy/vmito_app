import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Icon-led row primitive used inside `SessionInfoCard`.
class SessionInfoRow extends StatelessWidget {
  const SessionInfoRow({
    required this.icon,
    this.label,
    this.child,
    this.textStyle,
    this.alignCenter = false,
    this.topPadding = 12,
    super.key,
  }) : assert(
         label != null || child != null,
         'Either label or child must be provided.',
       );
  final IconData icon;
  final String? label;
  final Widget? child;
  final TextStyle? textStyle;
  final bool alignCenter;
  final double topPadding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Row(
      crossAxisAlignment: alignCenter
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          // Keeps a single line of text optically centred against the 28 px
          // icon while multi-line content still starts at the icon's top.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child:
                  child ??
                  Text(
                    label!,
                    style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
                  ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Divider inserted between logical groups of [SessionInfoRow]s.
class SessionInfoGroupDivider extends StatelessWidget {
  const SessionInfoGroupDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: AppSpacing.md),
    child: Divider(),
  );
}
