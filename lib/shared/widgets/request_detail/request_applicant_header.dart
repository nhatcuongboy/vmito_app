import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';

/// Avatar, name, status and a submitted-at line for the person who sent a
/// join request. Shared by the club and session join-request detail screens
/// so both read as one system, the way web's `AppRequestApplicantCard` does.
class RequestApplicantHeader extends StatelessWidget {
  const RequestApplicantHeader({
    required this.name,
    this.imageUrl,
    this.gender,
    this.onTapName,
    this.statusBadge,
    this.submittedLabel,
    this.summary = const [],
    super.key,
  });

  final String name;
  final String? imageUrl;
  final String? gender;
  final VoidCallback? onTapName;
  final Widget? statusBadge;
  final String? submittedLabel;
  final List<Widget> summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTapName,
            child: UserAvatar(
              name: name,
              imageUrl: imageUrl,
              gender: gender,
              size: 56,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onTapName,
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (statusBadge != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      statusBadge!,
                    ],
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(spacing: 6, runSpacing: 4, children: summary),
                ],
                if (submittedLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    submittedLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
