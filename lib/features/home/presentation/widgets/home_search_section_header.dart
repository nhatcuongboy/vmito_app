import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Title row for a search screen section, with an optional trailing action.
class HomeSearchSectionHeader extends StatelessWidget {
  const HomeSearchSectionHeader({
    required this.title,
    this.action,
    super.key,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      action == null ? AppSpacing.screenPadding : AppSpacing.xs,
      0,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}
