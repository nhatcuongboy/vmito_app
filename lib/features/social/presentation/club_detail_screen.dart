import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({required this.clubId, super.key});
  final String clubId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubDetailProvider(clubId));
    return club.when(
      data: (data) => _ClubDetail(club: data),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubDetailProvider(clubId)),
        ),
      ),
    );
  }
}

class _ClubDetail extends ConsumerStatefulWidget {
  const _ClubDetail({required this.club});
  final ClubSummary club;
  @override
  ConsumerState<_ClubDetail> createState() => _ClubDetailState();
}

class _ClubDetailState extends ConsumerState<_ClubDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.club.images.isEmpty ? 4 : 5,
    vsync: this,
  );
  bool _busy = false;
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final tabs = <Tab>[
      const Tab(text: 'Giới thiệu'),
      Tab(text: 'Thành viên (${club.memberCount})'),
      const Tab(text: 'Lịch chơi'),
      const Tab(text: 'Tin tức'),
      if (club.images.isNotEmpty) const Tab(text: 'Ảnh'),
    ];
    return Scaffold(
      body: Column(
        children: [
          _hero(club),
          _identity(club),
          Material(
            child: TabBar(controller: _tabs, isScrollable: true, tabs: tabs),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _about(club),
                _members(club),
                _schedule(club),
                _announcements(club),
                if (club.images.isNotEmpty) _photos(club),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(ClubSummary club) => SizedBox(
    height: 220 + MediaQuery.paddingOf(context).top,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (club.heroImage != null)
          GestureDetector(
            onTap: () =>
                unawaited(showAppLightbox(context, images: club.gallery)),
            child: CachedNetworkImage(
              imageUrl: club.heroImage!,
              fit: BoxFit.cover,
            ),
          )
        else
          ColoredBox(color: Theme.of(context).colorScheme.primaryContainer),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Colors.transparent,
                Color(0x66000000),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          child: IconButton.filledTonal(
            onPressed: () => context.pop(),
            icon: const Icon(AppIcons.arrowBack),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 8,
          child: Row(
            children: [
              FavoriteButton(
                type: FavoriteType.club,
                targetId: club.id,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: 'https://vmito.com/clubs/${club.slug ?? club.id}',
                  ),
                ),
                icon: const Icon(AppIcons.share),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _identity(ClubSummary club) => Padding(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: club.logo == null
              ? null
              : CachedNetworkImageProvider(club.logo!),
          child: club.logo == null ? const Icon(AppIcons.clubs) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(club.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                '${club.memberCount} thành viên · ${_policy(club.joinPolicy)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _joinButton(club),
      ],
    ),
  );
  Widget _joinButton(ClubSummary club) {
    final user = ref.watch(currentUserProvider);
    final isMember = club.members.any((member) => member.userId == user?.id);
    if (isMember) {
      return OutlinedButton(
        onPressed: _busy ? null : () => _leave(club),
        child: const Text('Rời CLB'),
      );
    }
    if (club.isInvitationOnly) return const Chip(label: Text('Chỉ mời'));
    return FilledButton(
      onPressed: _busy ? null : () => _join(club),
      child: Text(_busy ? 'Đang gửi...' : 'Tham gia'),
    );
  }

  Widget _about(ClubSummary club) => ListView(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    children: [
      _card(
        'Giới thiệu',
        Text(
          _strip(club.description).isEmpty
              ? 'Chưa có mô tả.'
              : _strip(club.description),
        ),
      ),
      if (club.requiredLevels.isNotEmpty)
        _card(
          AppLocalizations.of(context).clubRequiredLevels,
          Wrap(
            spacing: 8,
            children: club.requiredLevels
                .map((level) => Chip(label: Text('Trình độ $level')))
                .toList(),
          ),
        ),
      if (club.defaultVenue != null || club.location != null)
        _card(
          'Địa điểm',
          Column(
            children: [
              if (club.defaultVenue case final venue?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.location),
                  title: Text(venue.name),
                  subtitle: Text(venue.address),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: venue.id == null
                      ? () => _openMap(venue)
                      : () => context.push(AppRoutes.venueDetail(venue.id!)),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.location),
                  title: Text(club.location!),
                ),
            ],
          ),
        ),
      if (club.hostName != null)
        _card(
          'Trưởng nhóm',
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: club.hostImage == null
                  ? null
                  : CachedNetworkImageProvider(club.hostImage!),
              child: club.hostImage == null
                  ? const Icon(AppIcons.profile)
                  : null,
            ),
            title: Text(club.hostName!),
            onTap: club.hostId == null
                ? null
                : () => context.push(AppRoutes.publicProfile(club.hostId!)),
          ),
        ),
      if (club.socialLinks.isNotEmpty)
        _card(
          'Liên kết',
          Column(
            children: [
              for (final entry in club.socialLinks.entries.where(
                (entry) => entry.value.trim().isNotEmpty,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.link),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  onTap: () => launchUrl(
                    Uri.parse(entry.value),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
  Widget _members(ClubSummary club) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    itemCount: club.members.length,
    separatorBuilder: (_, _) => const Divider(),
    itemBuilder: (_, index) {
      final member = club.members[index];
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: member.image == null
              ? null
              : CachedNetworkImageProvider(member.image!),
          child: member.image == null ? const Icon(AppIcons.profile) : null,
        ),
        title: Text(member.name),
        subtitle: Text(
          member.level == null
              ? member.role
              : '${member.role} · Trình độ ${member.level}',
        ),
        onTap: member.userId.isEmpty
            ? null
            : () => context.push(AppRoutes.publicProfile(member.userId)),
      );
    },
  );
  Widget _schedule(ClubSummary club) => ListView(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    children: [
      if (club.schedules.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Chưa có lịch chơi.'),
          ),
        )
      else
        for (final item in club.schedules)
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.clock),
              title: Text(_weekday(item.dayOfWeek)),
              subtitle: Text('${item.startTime} – ${item.endTime}'),
            ),
          ),
    ],
  );
  Widget _announcements(ClubSummary club) => Consumer(
    builder: (context, ref, _) {
      final values = ref.watch(clubAnnouncementsProvider(club.id));
      return values.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: items.isEmpty
              ? const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Chưa có thông báo.'),
                    ),
                  ),
                ]
              : [
                  for (final item in items)
                    Card(
                      child: ListTile(
                        leading: const Icon(AppIcons.campaign),
                        title: Text(item.title),
                        subtitle: Text(item.content),
                        isThreeLine: true,
                      ),
                    ),
                ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Không thể tải thông báo.')),
      );
    },
  );
  Widget _photos(ClubSummary club) => GridView.builder(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    itemCount: club.images.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemBuilder: (_, index) => InkWell(
      onTap: () => unawaited(
        showAppLightbox(context, images: club.images, initialIndex: index),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CachedNetworkImage(
          imageUrl: club.images[index],
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
  Widget _card(String title, Widget body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          body,
        ],
      ),
    ),
  );
  Future<void> _join(ClubSummary club) async {
    final message = await _messageDialog();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(socialServiceProvider)
          .joinClub(club.id, message: message);
      _toast(
        result == 'joined'
            ? 'Bạn đã tham gia CLB.'
            : 'Yêu cầu tham gia đang chờ duyệt.',
      );
      ref.invalidate(clubDetailProvider(club.id));
    } on Object catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(ClubSummary club) async {
    setState(() => _busy = true);
    try {
      await ref.read(socialServiceProvider).leaveClub(club.id);
      _toast('Đã rời câu lạc bộ.');
      ref.invalidate(clubDetailProvider(club.id));
    } on Object catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _messageDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tham gia câu lạc bộ'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Lời nhắn (không bắt buộc)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(ClubVenue venue) => launchUrl(
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': venue.hasCoordinates
          ? '${venue.latitude},${venue.longitude}'
          : '${venue.name} ${venue.address}',
    }),
    mode: LaunchMode.externalApplication,
  );
  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String _policy(String value) => switch (value) {
  'OPEN' => 'Mở',
  'INVITATION_ONLY' => 'Chỉ mời',
  _ => 'Cần duyệt',
};
String _weekday(int value) => switch (value) {
  1 => 'Thứ Hai',
  2 => 'Thứ Ba',
  3 => 'Thứ Tư',
  4 => 'Thứ Năm',
  5 => 'Thứ Sáu',
  6 => 'Thứ Bảy',
  _ => 'Chủ Nhật',
};
String _strip(String? value) => (value ?? '')
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
