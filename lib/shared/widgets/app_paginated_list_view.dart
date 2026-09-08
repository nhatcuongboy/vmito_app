import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A separated, paginated list with consistent loading and end-of-results UI.
///
/// The end label is based on the height allocated to this scroll view, rather
/// than the device type or screen size. This keeps it hidden for short lists
/// that are still always scrollable to support pull-to-refresh.
class AppPaginatedListView extends StatelessWidget {
  const AppPaginatedListView.separated({
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.physics = const AlwaysScrollableScrollPhysics(),
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController? controller;
  final EdgeInsets padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final listPadding = EdgeInsets.fromLTRB(
      padding.left,
      padding.top,
      padding.right,
      0,
    );

    return CustomScrollView(
      controller: controller,
      physics: physics,
      slivers: [
        SliverPadding(
          padding: listPadding,
          sliver: SliverList.separated(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            separatorBuilder: separatorBuilder,
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final contentOverflowsViewport =
                constraints.precedingScrollExtent >
                constraints.viewportMainAxisExtent;
            final showEndOfResults =
                itemCount > 0 &&
                !hasMore &&
                !isLoading &&
                !isLoadingMore &&
                contentOverflowsViewport;

            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                0,
                padding.right,
                padding.bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _PaginationFooter(
                  isLoadingMore: isLoadingMore,
                  showEndOfResults: showEndOfResults,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.isLoadingMore,
    required this.showEndOfResults,
  });

  final bool isLoadingMore;
  final bool showEndOfResults;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!showEndOfResults) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      key: const Key('app-pagination-end-of-results'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        AppLocalizations.of(context).commonEndOfResults,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.extension<AppPalette>()!.mutedForeground,
        ),
      ),
    );
  }
}
