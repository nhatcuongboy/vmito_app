import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/constants/image_constants.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_address_text.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/widgets/public_club_members_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';
import 'package:vmito_app/shared/widgets/detail_hero_header.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';
import 'package:vmito_app/shared/widgets/skill_level_badge.dart';
import 'package:vmito_domain/vmito_domain.dart';

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
  static const _heroHeight = 220.0;

  late final TabController _tabs = TabController(
    length: widget.club.images.isEmpty ? 4 : 5,
    vsync: this,
  );
  final _scrollController = ScrollController();
  double _pinnedThreshold = 0;
  bool _isPinned = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final threshold =
        _heroHeight -
        AppSizes.appBarHeight -
        MediaQuery.paddingOf(context).top -
        AppSpacing.md;
    _pinnedThreshold = threshold < 0 ? 0 : threshold;
    if (_scrollController.hasClients) {
      _isPinned = _scrollController.offset >= _pinnedThreshold;
    }
  }

  void _handleScroll() {
    final pinned = _scrollController.offset >= _pinnedThreshold;
    if (pinned != _isPinned && mounted) setState(() => _isPinned = pinned);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tabs = <Tab>[
      Tab(text: l10n.socialAbout),
      const Tab(text: 'Thành viên'),
      const Tab(text: 'Lịch sinh hoạt'),
      const Tab(text: 'Thông báo'),
      if (club.images.isNotEmpty) const Tab(text: 'Ảnh'),
    ];
    final user = ref.watch(currentUserProvider);
    final isMember = club.members.any((member) => member.userId == user?.id);
    final isUserAdmin =
        user != null &&
        (user.isAdmin ||
            club.hostUserId == user.id ||
            club.members.any(
              (member) => member.userId == user.id && member.role == 'ADMIN',
            ));
    final canJoin = !isMember && !club.isInvitationOnly;
    return Scaffold(
      bottomNavigationBar: canJoin
          ? _ClubMembershipBottomBar(
              busy: _busy,
              onPressed: () => _join(club),
            )
          : null,
      body: NestedScrollView(
        key: const Key('club-detail-scroll'),
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            key: const Key('club-detail-app-bar'),
            pinned: true,
            stretch: true,
            expandedHeight: _heroHeight,
            backgroundColor: _isPinned
                ? theme.colorScheme.surface
                : Colors.transparent,
            foregroundColor: _isPinned
                ? theme.colorScheme.onSurface
                : Colors.white,
            surfaceTintColor: theme.colorScheme.surface,
            shadowColor: Colors.black26,
            elevation: _isPinned ? 2 : 0,
            leadingWidth: DetailHeroHeader.leadingWidth,
            leading: Padding(
              padding: DetailHeroHeader.leadingPadding,
              child: DetailHeroHeaderButton(
                key: const Key('club-back-button'),
                icon: AppIcons.chevronLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                pinned: _isPinned,
                size: DetailHeroHeader.backButtonSize,
                hitTargetSize: AppSizes.minTapTarget,
                iconSize: DetailHeroHeader.backIconSize,
                onPressed: _back,
              ),
            ),
            title: AnimatedOpacity(
              key: const Key('club-sticky-title'),
              opacity: _isPinned ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DetailHeroHeader.titleStyle(theme.textTheme),
              ),
            ),
            actionsPadding: DetailHeroHeader.actionsPadding,
            actions: [
              if (!_isPinned)
                FavoriteButton(
                  key: const Key('club-favorite-button'),
                  type: FavoriteType.club,
                  targetId: club.id,
                  overlayColor: DetailHeroHeader.coverActionBackground,
                  size: FavoriteButton.detailControlSize,
                ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: DetailHeroHeaderButton(
                  key: const Key('club-share-button'),
                  icon: AppIcons.share,
                  tooltip: l10n.commonShare,
                  pinned: _isPinned,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'https://vmito.com/clubs/${club.slug ?? club.id}',
                    ),
                  ),
                ),
              ),
              if (isMember)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: _ClubMoreButton(
                    key: const Key('club-more-button'),
                    pinned: _isPinned,
                    onLeave: () => _confirmLeave(club),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ClubHero(club: club),
            ),
          ),
          SliverToBoxAdapter(child: _identity(club)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ClubTabBarDelegate(
              child: _ClubTabBar(controller: _tabs, tabs: tabs),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _about(club),
            PublicClubMembersTab(club: club, isAdmin: isUserAdmin),
            _schedule(club),
            _announcements(club),
            if (club.images.isNotEmpty) _photos(club),
          ],
        ),
      ),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.clubs);
    }
  }

  Widget _identity(ClubSummary club) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isMember = club.members.any((m) => m.userId == user?.id);
    final logo = _ClubIdentityLogo(club: club);
    final copy = Column(
      key: const Key('club-identity-copy'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          club.name,
          key: const Key('club-identity-name'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          key: const Key('club-identity-meta'),
          children: [
            Icon(
              AppIcons.users,
              size: 16,
              color: palette.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                _identityMeta(l10n, club),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        if (isMember) ...[
          const SizedBox(height: AppSpacing.xs),
          const _ClubMemberBadge(key: Key('club-member-badge')),
        ],
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaledBodySize = MediaQuery.textScalerOf(context).scale(16);
            final compact = constraints.maxWidth < 380 || scaledBodySize > 20;
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                key: Key(
                  compact ? 'club-identity-compact' : 'club-identity-regular',
                ),
                // Keep a short name and its member count visually centered
                // against the avatar; long names can still grow to two lines.
                children: [
                  logo,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: copy),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _about(ClubSummary club) {
    final l10n = AppLocalizations.of(context);
    final socialLinks = club.socialLinks.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList(growable: false);
    final sections = <Widget>[
      _card(
        l10n.clubAboutTitle,
        _ClubRichDescription(description: club.description),
      ),
      if (club.requiredLevels.isNotEmpty)
        _card(
          l10n.clubRequiredLevels,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: sortByRank(club.requiredLevels.toSet())
                .map((level) => SkillLevelBadge(level: level))
                .toList(growable: false),
          ),
        ),
      if (club.defaultVenue != null || club.location != null)
        _card(
          l10n.clubAboutLocation,
          club.defaultVenue != null
              ? _VenueCard(
                  venue: club.defaultVenue!,
                  onTap: club.defaultVenue!.id == null
                      ? () => _openMap(club.defaultVenue!)
                      : () => context.push(
                          AppRoutes.venueDetail(club.defaultVenue!.id!),
                        ),
                  onOpenMap: () => _openMap(club.defaultVenue!),
                )
              : _SimpleLocationRow(location: club.location!),
        ),
      if (club.hostName != null)
        _card(
          l10n.clubHostName,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(
              name: club.hostName,
              imageUrl: club.hostImage,
              size: 40,
            ),
            title: Text(
              club.hostName!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: club.hostId == null
                ? null
                : () => context.push(AppRoutes.publicProfile(club.hostId!)),
          ),
        ),
      if (socialLinks.isNotEmpty)
        _card(
          l10n.clubSocialLinksTitle,
          Column(
            children: [
              for (final entry in socialLinks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.link),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  onTap: () => _launchSafeUrl(entry.value),
                ),
            ],
          ),
        ),
    ];

    return ListView(
      key: const Key('club-about-list'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < sections.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  sections[index],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

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
  Widget _card(
    String title,
    Widget body, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
  }) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          body,
        ],
      ),
    ),
  );
  Future<void> _join(ClubSummary club) async {
    // A guest session has no JWT, so the club endpoints will always reject it.
    // Prompt before opening the request form rather than surfacing that failure.
    if (ref.read(currentUserProvider)?.isGuest ?? true) {
      await showLoginPromptDialog(
        context,
        featureName: AppLocalizations.of(context).socialJoinClub,
      );
      return;
    }

    final message = await _messageDialog();
    // `null` is an explicit dismissal. An empty string is still a valid request
    // without a message, so it must remain distinguishable from cancellation.
    if (!mounted || message == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(socialServiceProvider)
          .joinClub(club.id, message: message);
      _toast(
        result == 'joined'
            ? 'Bạn đã tham gia nhóm.'
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
      _toast('Đã rời nhóm.');
      ref.invalidate(clubDetailProvider(club.id));
    } on Object catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _messageDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _JoinClubDialog(),
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

  Future<void> _confirmLeave(ClubSummary club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Rời nhóm'),
          content: Text(
            'Bạn có chắc muốn rời khỏi nhóm "${club.name}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Rời nhóm'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) await _leave(club);
  }
}

abstract final class _JoinClubFormControl {
  static const message = 'message';
}

class _JoinClubDialog extends StatefulWidget {
  const _JoinClubDialog();

  @override
  State<_JoinClubDialog> createState() => _JoinClubDialogState();
}

class _JoinClubDialogState extends State<_JoinClubDialog> {
  final _form = FormGroup({
    _JoinClubFormControl.message: FormControl<String>(),
  });

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final message =
        _form.control(_JoinClubFormControl.message).value as String?;
    Navigator.of(context).pop(message?.trim() ?? '');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('club-join-dialog'),
    // The Material default leaves 40 px on each side. This dialog contains a
    // multi-line field, so use the app's normal screen gutter instead.
    insetPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenPadding,
    ),
    title: const Text('Tham gia nhóm'),
    content: SizedBox(
      width: double.maxFinite,
      child: AppReactiveForm<String>(
        formGroup: _form,
        child: ReactiveTextField<String>(
          key: const Key('club-join-message-field'),
          formControlName: _JoinClubFormControl.message,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Lời nhắn (không bắt buộc)',
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Gửi')),
    ],
  );
}

class _ClubIdentityLogo extends StatelessWidget {
  const _ClubIdentityLogo({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = club.logo?.trim();
    if (logo == null || logo.isEmpty) return _ClubInitialLogo(club: club);
    return Container(
      key: const Key('club-identity-logo'),
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: .14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: logo,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => ColoredBox(
            color: theme.colorScheme.primary,
            child: Text(
              _clubInitial(club.name),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubInitialLogo extends StatelessWidget {
  const _ClubInitialLogo({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Semantics(
      label: 'Logo ${club.name}',
      child: Container(
        key: const Key('club-identity-logo'),
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: .08),
          shape: BoxShape.circle,
          border: Border.all(color: primary.withValues(alpha: .2)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: .14),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          _clubInitial(club.name),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _clubInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

class _ClubMoreButton extends StatelessWidget {
  const _ClubMoreButton({
    required this.pinned,
    required this.onLeave,
    super.key,
  });

  final bool pinned;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_ClubMoreAction>(
      tooltip: 'Thêm',
      position: PopupMenuPosition.under,
      icon: SizedBox.square(
        dimension: DetailHeroHeader.actionButtonSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pinned
                ? Colors.transparent
                : DetailHeroHeader.coverActionBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.more_vert,
              size: DetailHeroHeader.actionIconSize,
              color: pinned ? null : Colors.white,
            ),
          ),
        ),
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(DetailHeroHeader.actionButtonSize),
        maximumSize: const Size.square(DetailHeroHeader.actionButtonSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (action) {
        if (action == _ClubMoreAction.leave) onLeave();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ClubMoreAction.leave,
          child: Row(
            children: [
              Icon(Icons.logout, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Text(
                'Rời nhóm',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ClubMoreAction { leave }

class _ClubMemberBadge extends StatelessWidget {
  const _ClubMemberBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.checkCircle, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          'Thành viên',
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ClubMembershipBottomBar extends StatelessWidget {
  const _ClubMembershipBottomBar({
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      key: const Key('club-membership-bottom-bar'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('club-join-button'),
                  onPressed: busy ? null : onPressed,
                  icon: const Icon(AppIcons.userPlus),
                  label: Text(
                    busy ? l10n.feedbackSubmitting : 'Tham gia nhóm',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubHero extends StatefulWidget {
  const _ClubHero({required this.club});

  final ClubSummary club;

  @override
  State<_ClubHero> createState() => _ClubHeroState();
}

class _ClubHeroState extends State<_ClubHero> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.club.gallery;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isEmpty)
          CachedNetworkImage(
            key: const Key('club-default-cover'),
            imageUrl: kDefaultCoverPhoto,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(AppIcons.imageOff),
            ),
          )
        else
          PageView.builder(
            key: const Key('club-hero-carousel'),
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Colors.black12),
              errorWidget: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Icon(AppIcons.imageOff),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black54],
            ),
          ),
        ),
        // Transparent tap overlay — lets PageView handle horizontal swipes
        // while still firing the lightbox on a clean tap.
        if (images.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => unawaited(
                showAppLightbox(
                  context,
                  images: images,
                  initialIndex: _index,
                ),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            bottom: AppSpacing.md,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < images.length; index++)
                  AnimatedContainer(
                    key: ValueKey('club-hero-dot-$index'),
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: index == _index ? 1 : .6,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ClubTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ClubTabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => kTextTabBarHeight;

  @override
  double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_ClubTabBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

class _ClubTabBar extends StatelessWidget {
  const _ClubTabBar({required this.controller, required this.tabs});

  final TabController controller;
  final List<Tab> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const ValueKey('club-tab-bar'),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: .5),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: tabs,
      ),
    );
  }
}

String _policy(AppLocalizations l10n, String value) => switch (value) {
  'OPEN' => l10n.clubJoinOpen,
  'INVITATION_ONLY' => l10n.clubJoinInvitation,
  _ => '',
};

String _identityMeta(AppLocalizations l10n, ClubSummary club) {
  final policy = _policy(l10n, club.joinPolicy);
  final members = l10n.socialMemberCount(club.memberCount);
  return policy.isEmpty ? members : '$members · $policy';
}

String _weekday(int value) => switch (value) {
  1 => 'Thứ Hai',
  2 => 'Thứ Ba',
  3 => 'Thứ Tư',
  4 => 'Thứ Năm',
  5 => 'Thứ Sáu',
  6 => 'Thứ Bảy',
  _ => 'Chủ Nhật',
};

class _ClubRichDescription extends StatelessWidget {
  const _ClubRichDescription({required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final html = _displayableHtml(description);
    if (html == null) {
      return Text(
        AppLocalizations.of(context).clubNoDescription,
        key: const Key('club-about-empty'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: palette.mutedForeground,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return SelectionArea(
      child: HtmlWidget(
        html,
        key: const Key('club-about-rich-description'),
        customStylesBuilder: (element) => _descriptionStyles(theme, element),
        customWidgetBuilder: (element) {
          if (element.localName != 'img') return null;
          final source = element.attributes['src']?.trim();
          final uri = source == null ? null : Uri.tryParse(source);
          if (!_isSafeNetworkUri(uri)) {
            final alt = element.attributes['alt']?.trim();
            return alt == null || alt.isEmpty
                ? const SizedBox.shrink()
                : Text(alt);
          }
          return _ClubDescriptionImage(
            url: uri!.toString(),
            alt: element.attributes['alt']?.trim(),
          );
        },
        onTapUrl: _launchSafeUrl,
        textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
    );
  }
}

class _ClubDescriptionImage extends StatelessWidget {
  const _ClubDescriptionImage({required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (_, _) => AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        errorWidget: (_, _, _) => SizedBox(
          height: 120,
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      image: true,
      label: alt?.isNotEmpty ?? false ? alt : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => unawaited(showAppLightbox(context, images: [url])),
        child: image,
      ),
    );
  }
}

String? _displayableHtml(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final fragment = html_parser.parseFragment(raw);
  for (final element in fragment.querySelectorAll('script, style')) {
    element.remove();
  }
  final text = (fragment.text ?? '').replaceAll('\u00a0', ' ').trim();
  final hasSafeImage = fragment.querySelectorAll('img').any((element) {
    final source = element.attributes['src']?.trim();
    return _isSafeNetworkUri(source == null ? null : Uri.tryParse(source));
  });
  final hasVisualBlock = fragment.querySelector('table, hr') != null;
  if (text.isEmpty && !hasSafeImage && !hasVisualBlock) return null;
  return fragment.outerHtml;
}

Map<String, String>? _descriptionStyles(
  ThemeData theme,
  html_dom.Element element,
) => switch (element.localName) {
  'h1' => {
    'font-size': '1.75em',
    'font-weight': '700',
    'margin': '0.8em 0 0.4em',
  },
  'h2' => {
    'font-size': '1.4em',
    'font-weight': '700',
    'margin': '0.8em 0 0.4em',
  },
  'h3' => {
    'font-size': '1.2em',
    'font-weight': '700',
    'margin': '0.75em 0 0.35em',
  },
  'p' => {'margin': '0 0 0.6em'},
  'ul' || 'ol' => {'margin': '0.5em 0 0.75em 1.25em'},
  'li' => {'margin': '0 0 0.25em'},
  'a' => {
    'color': _cssColor(theme.colorScheme.primary),
    'text-decoration': 'underline',
  },
  'table' => {'margin': '0.75em 0'},
  'th' => {
    'background-color': _cssColor(theme.colorScheme.surfaceContainerHighest),
    'font-weight': '700',
    'padding': '0.5em',
  },
  'td' => {'padding': '0.5em'},
  'pre' => {
    'background-color': _cssColor(theme.colorScheme.surfaceContainerHighest),
    'border-radius': '6px',
    'padding': '0.75em',
    'margin': '0.75em 0',
  },
  'code' => {
    'background-color': _cssColor(theme.colorScheme.surfaceContainerHighest),
    'border-radius': '4px',
    'padding': '0.125em 0.25em',
  },
  _ => null,
};

String _cssColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

bool _isSafeNetworkUri(Uri? uri) =>
    uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

Future<bool> _launchSafeUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      !const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme)) {
    return false;
  }
  try {
    return await launchUrl(
      uri,
      mode: uri.scheme == 'http' || uri.scheme == 'https'
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
  } on Object {
    return false;
  }
}

/// A visual card for a linked venue with a map-placeholder banner,
/// venue name, formatted address, and a quick "Open in Maps" button.
class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.onTap,
    required this.onOpenMap,
  });

  final ClubVenue venue;
  final VoidCallback onTap;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map placeholder banner
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 96,
              color: palette.muted,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative background dots
                  Positioned.fill(
                    child: CustomPaint(painter: _MapDotsPainter(palette)),
                  ),
                  // Pin icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      AppIcons.location,
                      color: theme.colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Venue name + chevron
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (venue.hasAddressData) ...[
                      const SizedBox(height: 2),
                      AppAddressText(
                        address: venue.address,
                        district: venue.district,
                        city: venue.city,
                        newAddress: venue.newAddress,
                        newDistrict: venue.newDistrict,
                        newCity: venue.newCity,
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: palette.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Open in Maps button
          OutlinedButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(AppIcons.location, size: 16),
            label: const Text('Mở bản đồ'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback row for a plain text location (no linked venue).
class _SimpleLocationRow extends StatelessWidget {
  const _SimpleLocationRow({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            AppIcons.location,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              location,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a subtle grid/dot pattern to simulate a map tile.
class _MapDotsPainter extends CustomPainter {
  _MapDotsPainter(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.mutedForeground.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const step = 18.0;
    const radius = 2.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MapDotsPainter oldDelegate) => false;
}
