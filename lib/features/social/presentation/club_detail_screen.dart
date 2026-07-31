import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubDetailProvider(clubId));
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).socialClubDetail),
      ),
      body: club.when(
        data: (value) => _ClubDetailBody(club: value),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubDetailProvider(clubId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ClubDetailBody extends ConsumerWidget {
  const _ClubDetailBody({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final announcements = ref.watch(clubAnnouncementsProvider(club.id));
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (club.heroImage != null)
          CachedNetworkImage(
            imageUrl: club.heroImage!,
            height: 220,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox(height: 120),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(club.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Chip(
                    avatar: const Icon(Icons.people_outline_rounded, size: 18),
                    label: Text(l10n.socialMemberCount(club.memberCount)),
                  ),
                  if (club.hostName != null)
                    Chip(
                      avatar: const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                      ),
                      label: Text(club.hostName!),
                    ),
                ],
              ),
              if (club.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.socialAbout,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(club.description!),
              ],
              if (club.defaultVenue case final venue?) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.socialVenue,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(venue.name),
                  subtitle: venue.address.isEmpty ? null : Text(venue.address),
                  trailing: const Icon(Icons.directions_outlined),
                  onTap: () => _openMap(venue),
                ),
              ],
              if (club.schedules.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.socialSchedule,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final schedule in club.schedules)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(_dayLabel(context, schedule.dayOfWeek)),
                    subtitle: Text(
                      '${schedule.startTime} – ${schedule.endTime}',
                    ),
                  ),
              ],
              announcements.when(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.clubAnnouncements,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final item in items.take(3))
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.campaign_outlined),
                                title: Text(item.title),
                                subtitle: Text(
                                  item.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                error: (_, _) => const SizedBox.shrink(),
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: club.isInvitationOnly
                      ? null
                      : () => _requestJoin(context, ref),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    club.isInvitationOnly
                        ? l10n.socialInvitationOnly
                        : l10n.socialJoinClub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMap(ClubVenue venue) async {
    final query = venue.hasCoordinates
        ? '${venue.latitude},${venue.longitude}'
        : '${venue.name} ${venue.address}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _requestJoin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.socialJoinClub),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: l10n.socialJoinMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.socialSendRequest),
          ),
        ],
      ),
    );
    final message = controller.text;
    controller.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      final status = await ref
          .read(socialServiceProvider)
          .joinClub(club.id, message: message);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'joined'
                  ? l10n.socialJoined
                  : l10n.socialRequestPending,
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  String _dayLabel(BuildContext context, int day) {
    final l10n = AppLocalizations.of(context);
    return switch (day) {
      1 => l10n.socialMonday,
      2 => l10n.socialTuesday,
      3 => l10n.socialWednesday,
      4 => l10n.socialThursday,
      5 => l10n.socialFriday,
      6 => l10n.socialSaturday,
      _ => l10n.socialSunday,
    };
  }
}
