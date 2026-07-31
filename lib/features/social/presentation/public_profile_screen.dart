import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(publicProfileProvider(userId));
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).socialProfile)),
      body: bundle.when(
        data: (value) => _ProfileBody(bundle: value),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.bundle});

  final PublicProfileBundle bundle;

  @override
  Widget build(BuildContext context) {
    final profile = bundle.profile;
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (profile.coverPhoto != null)
                CachedNetworkImage(
                  imageUrl: profile.coverPhoto!,
                  fit: BoxFit.cover,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundImage: profile.image == null
                        ? null
                        : CachedNetworkImageProvider(profile.image!),
                    child: profile.image == null
                        ? const Icon(Icons.person_rounded, size: 54)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  Chip(label: Text(profile.role)),
                  if (profile.levelDescription != null)
                    Chip(label: Text(profile.levelDescription!)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(
                    value: profile.joinedSessionsCount.toString(),
                    label: l10n.socialSessions,
                  ),
                  _Stat(
                    value: bundle.stats.average.toStringAsFixed(1),
                    label: l10n.socialRating,
                    icon: Icons.star_rounded,
                  ),
                  _Stat(
                    value: bundle.stats.total.toString(),
                    label: l10n.socialReviews,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.socialReviews,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (bundle.ratings.isEmpty)
                Text(l10n.socialNoReviews)
              else
                for (final rating in bundle.ratings)
                  _RatingTile(rating: rating),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18, color: Colors.amber.shade700),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final PlayerRating rating;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: rating.raterImage == null
            ? null
            : CachedNetworkImageProvider(rating.raterImage!),
        child: rating.raterImage == null
            ? const Icon(Icons.person_outline_rounded)
            : null,
      ),
      title: Text(rating.raterName ?? 'Vmito'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 18,
                color: Colors.amber.shade700,
              ),
            ),
          ),
          if (rating.comment?.trim().isNotEmpty ?? false) Text(rating.comment!),
          Text(
            Dates.dateOnly(
              rating.createdAt,
              locale: Localizations.localeOf(context).languageCode,
            ),
          ),
        ],
      ),
    ),
  );
}
