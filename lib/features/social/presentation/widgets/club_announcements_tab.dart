import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubAnnouncementsTab extends ConsumerWidget {
  const ClubAnnouncementsTab({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(clubAnnouncementsProvider(clubId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAnnouncementDialog(context, ref, clubId: clubId),
        icon: const Icon(Icons.campaign_outlined),
        label: Text(l10n.clubAnnouncementCreate),
      ),
      body: announcements.when(
        data: (items) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(clubAnnouncementsProvider(clubId).future),
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .5,
                      child: Center(child: Text(l10n.clubAnnouncementsEmpty)),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _AnnouncementCard(
                    clubId: clubId,
                    announcement: items[index],
                  ),
                ),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubAnnouncementsProvider(clubId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({
    required this.clubId,
    required this.announcement,
  });

  final String clubId;
  final ClubAnnouncement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final pinned = announcement.pinnedUntil?.isAfter(DateTime.now()) ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pinned) ...[
                  const Icon(Icons.push_pin_rounded, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await showAnnouncementDialog(
                        context,
                        ref,
                        clubId: clubId,
                        announcement: announcement,
                      );
                    } else {
                      await _delete(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.commonDelete),
                    ),
                  ],
                ),
              ],
            ),
            Text(announcement.content),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (announcement.authorName != null) announcement.authorName!,
                Dates.dateOnly(announcement.createdAt, locale: locale),
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clubAnnouncementDelete),
        content: Text(l10n.clubAnnouncementDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .deleteAnnouncement(clubId, announcement.id);
    }
  }
}

Future<void> showAnnouncementDialog(
  BuildContext context,
  WidgetRef ref, {
  required String clubId,
  ClubAnnouncement? announcement,
}) async {
  final l10n = AppLocalizations.of(context);
  final titleController = TextEditingController(text: announcement?.title);
  final contentController = TextEditingController(text: announcement?.content);
  var pinned = announcement?.pinnedUntil?.isAfter(DateTime.now()) ?? false;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          announcement == null
              ? l10n.clubAnnouncementCreate
              : l10n.clubAnnouncementEdit,
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('announcement-title-field'),
                  controller: titleController,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l10n.commonTitle),
                ),
                TextField(
                  controller: contentController,
                  maxLength: 5000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: l10n.commonContent),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.clubAnnouncementPin),
                  value: pinned,
                  onChanged: (value) => setState(() => pinned = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  contentController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ),
  );
  final title = titleController.text;
  final content = contentController.text;
  titleController.dispose();
  contentController.dispose();
  if (submitted != true) return;
  await ref
      .read(clubManagementControllerProvider.notifier)
      .saveAnnouncement(
        clubId,
        announcementId: announcement?.id,
        title: title,
        content: content,
        pinnedUntil: pinned
            ? DateTime.now().add(const Duration(days: 30))
            : null,
      );
}
