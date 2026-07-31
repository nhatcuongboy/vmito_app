import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SessionRatingScreen extends ConsumerWidget {
  const SessionRatingScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));
    final eligibility = ref.watch(ratingEligibilityProvider(sessionId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.socialRateSession)),
      body: session.when(
        data: (sessionValue) => eligibility.when(
          data: (value) {
            if (value.isEmpty) {
              return Center(child: Text(l10n.socialNothingToRate));
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (value.canRateHost && sessionValue.host != null)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.verified_user_outlined),
                      ),
                      title: Text(sessionValue.displayHostName),
                      subtitle: Text(l10n.socialRateHost),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showRatingDialog(
                        context,
                        ref,
                        userId: sessionValue.host!.id,
                        name: sessionValue.displayHostName,
                        type: 'PLAYER_TO_HOST',
                      ),
                    ),
                  ),
                for (final userId in value.canRatePlayers)
                  _RatePlayerTile(sessionId: sessionId, userId: userId),
              ],
            );
          },
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(ratingEligibilityProvider(sessionId)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AppErrorView(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String name,
    required String type,
  }) => showRatingDialog(
    context,
    ref,
    sessionId: sessionId,
    userId: userId,
    name: name,
    type: type,
  );
}

class _RatePlayerTile extends ConsumerWidget {
  const _RatePlayerTile({required this.sessionId, required this.userId});

  final String sessionId;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicUserProvider(userId));
    return profile.when(
      data: (value) => Card(
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person_outline_rounded),
          ),
          title: Text(value.name),
          subtitle: Text(AppLocalizations.of(context).socialRatePlayer),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showRatingDialog(
            context,
            ref,
            sessionId: sessionId,
            userId: userId,
            name: value.name,
            type: 'HOST_TO_PLAYER',
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('…'),
        ),
      ),
    );
  }
}

Future<void> showRatingDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required String userId,
  required String name,
  required String type,
}) async {
  final l10n = AppLocalizations.of(context);
  final commentController = TextEditingController();
  var stars = 5;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.socialRateName(name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  key: Key('rating-star-${index + 1}'),
                  onPressed: () => setState(() => stars = index + 1),
                  icon: Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            ),
            TextField(
              controller: commentController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(hintText: l10n.socialRatingComment),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.socialSendRating),
          ),
        ],
      ),
    ),
  );
  final comment = commentController.text;
  commentController.dispose();
  if (submitted != true || !context.mounted) return;
  await ref
      .read(socialServiceProvider)
      .createRating(
        sessionId: sessionId,
        ratedUserId: userId,
        type: type,
        rating: stars,
        comment: comment,
      );
  ref.invalidate(ratingEligibilityProvider(sessionId));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.socialRatingSent)),
    );
  }
}
