import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/reference/data/level_description_repository.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The web app's `LevelDescriptionsModal`, as a bottom sheet.
///
/// A sheet rather than a dialog because the list is long enough to scroll,
/// and a scrolling dialog on a phone is the pattern the rest of this app
/// already avoids (see `showLanguageSelector`).
Future<void> showLevelDescriptions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _LevelDescriptionsSheet(),
  );
}

class _LevelDescriptionsSheet extends ConsumerWidget {
  const _LevelDescriptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final descriptions = ref.watch(levelDescriptionsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.levelDescriptionsTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: descriptions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppLoadingView(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(levelDescriptionsProvider),
                  ),
                ),
                data: (descriptions) => _LevelList(
                  descriptions: {
                    for (final item in descriptions)
                      item.level: item.description,
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelList extends StatelessWidget {
  const _LevelList({required this.descriptions});

  /// Level id → prose. Missing ids are expected: the backend only stores rows
  /// an admin has written.
  final Map<int, String> descriptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    // Driven by the static table, not by the response: every level gets a row
    // even when nobody has written its blurb yet.
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: validLevels.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final level = validLevels[index];
        final text = descriptions[level]?.trim() ?? '';

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  l10n.levelName(level),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Text(
                  text.isEmpty ? l10n.levelDescriptionMissing : text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: text.isEmpty ? palette.mutedForeground : null,
                    fontStyle: text.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
