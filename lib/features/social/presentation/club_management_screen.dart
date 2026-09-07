import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class ClubManagementScreen extends ConsumerStatefulWidget {
  const ClubManagementScreen({this.initialTab = 'managing', super.key});

  final String initialTab;

  @override
  ConsumerState<ClubManagementScreen> createState() =>
      _ClubManagementScreenState();
}

class _ClubManagementScreenState extends ConsumerState<ClubManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _lastIndex;

  int get _requestedIndex => widget.initialTab == 'member' ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: _requestedIndex,
    )..addListener(_onTabChanged);
    _lastIndex = _requestedIndex;
  }

  @override
  void didUpdateWidget(covariant ClubManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != _requestedIndex) {
      _lastIndex = _requestedIndex;
      _tabs.index = _requestedIndex;
    }
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _tabs.index == _lastIndex || !mounted) return;
    _lastIndex = _tabs.index;
    setState(() {});
    context.replace(
      AppRoutes.manageClubsForTab(
        _tabs.index == 1 ? 'member' : 'managing',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs.index == 1 ? l10n.clubJoinedTitle : l10n.clubManageTitle,
        ),
        bottom: AppTabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.clubManagingTab),
            Tab(text: l10n.clubMemberTab),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0 && ref.watch(canCreateClubProvider)
          ? FloatingActionButton.extended(
              heroTag: 'club-management-create-fab',
              onPressed: () => context.push(AppRoutes.createClub),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.clubCreate),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [_ManagingTab(), _MemberTab()],
      ),
    );
  }
}

class _ManagingTab extends ConsumerWidget {
  const _ManagingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(managedClubsProvider);
    final incoming = ref.watch(incomingClubRequestsProvider);
    final pending = ref.watch(pendingClubsProvider);
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);

    Future<void> refresh() async {
      ref
        ..invalidate(managedClubsProvider)
        ..invalidate(incomingClubRequestsProvider)
        ..invalidate(pendingClubsProvider);
      await Future.wait([
        ref.read(managedClubsProvider.future),
        ref.read(incomingClubRequestsProvider.future),
        if (user?.isAdmin ?? false) ref.read(pendingClubsProvider.future),
      ]);
    }

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: const PageStorageKey('club-managing-tab'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.lg,
            AppSpacing.screenPadding,
            96,
          ),
          children: [
            _SectionHeader(
              icon: AppIcons.shield,
              title: user?.isAdmin ?? false
                  ? l10n.clubAdminManagingGroups
                  : l10n.clubManagingGroups,
              count: clubs.asData?.value.length,
              color: Colors.green,
            ),
            const SizedBox(height: AppSpacing.md),
            clubs.when(
              data: (items) => items.isEmpty
                  ? _EmptyPanel(
                      icon: AppIcons.shield,
                      message: user?.isAdmin ?? false
                          ? l10n.clubNoSystemGroups
                          : l10n.clubManageEmpty,
                      action: ref.watch(canCreateClubProvider)
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(AppRoutes.createClub),
                              icon: const Icon(AppIcons.add),
                              label: Text(l10n.clubCreate),
                            )
                          : null,
                    )
                  : _AdaptiveGrid(
                      width: constraints.maxWidth,
                      itemCount: items.length,
                      itemBuilder: (_, index) => _ClubCard(
                        club: items[index],
                        showActions: true,
                      ),
                    ),
              loading: () => _CardSkeletonGrid(width: constraints.maxWidth),
              error: (error, _) => _InlineError(
                error: error,
                onRetry: () => ref.invalidate(managedClubsProvider),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(
              icon: AppIcons.clipboardList,
              title: l10n.clubIncomingRequests,
              count: incoming.asData?.value.length,
              color: Colors.orange,
            ),
            const SizedBox(height: AppSpacing.md),
            incoming.when(
              data: (items) => items.isEmpty
                  ? _EmptyPanel(message: l10n.clubRequestsEmpty)
                  : Column(
                      children: [
                        for (final request in items) ...[
                          _IncomingRequestCard(request: request),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
              loading: () => const _ListSkeleton(),
              error: (error, _) => _InlineError(
                error: error,
                onRetry: () => ref.invalidate(incomingClubRequestsProvider),
              ),
            ),
            if (user?.isAdmin ?? false) ...[
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: AppIcons.shieldCheck,
                title: l10n.clubAdminApprovalTitle,
                count: pending.asData?.value.length,
                color: Colors.amber,
              ),
              const SizedBox(height: AppSpacing.md),
              pending.when(
                data: (items) => items.isEmpty
                    ? _EmptyPanel(
                        icon: AppIcons.shieldCheck,
                        message: l10n.clubAdminApprovalEmpty,
                      )
                    : _AdaptiveGrid(
                        width: constraints.maxWidth,
                        maxExtent: 540,
                        itemCount: items.length,
                        itemBuilder: (_, index) =>
                            _PendingClubCard(club: items[index]),
                      ),
                loading: () => _CardSkeletonGrid(width: constraints.maxWidth),
                error: (error, _) => _InlineError(
                  error: error,
                  onRetry: () => ref.invalidate(pendingClubsProvider),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberTab extends ConsumerWidget {
  const _MemberTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allClubs = ref.watch(myClubsProvider);
    final outgoing = ref.watch(myClubRequestsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final l10n = AppLocalizations.of(context);
    final memberCount = allClubs.asData == null
        ? null
        : memberOnlyClubs(
            allClubs.requireValue,
            currentUserId: userId,
          ).length;

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(myClubsProvider)
            ..invalidate(myClubRequestsProvider);
          await Future.wait([
            ref.read(myClubsProvider.future),
            ref.read(myClubRequestsProvider.future),
          ]);
        },
        child: ListView(
          key: const PageStorageKey('club-member-tab'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.lg,
            AppSpacing.screenPadding,
            96,
          ),
          children: [
            _SectionHeader(
              icon: AppIcons.users,
              title: l10n.clubJoinedGroups,
              count: memberCount,
              color: Colors.blue,
            ),
            const SizedBox(height: AppSpacing.md),
            allClubs.when(
              data: (items) {
                final memberClubs = memberOnlyClubs(
                  items,
                  currentUserId: userId,
                );
                return memberClubs.isEmpty
                    ? _EmptyPanel(
                        icon: AppIcons.users,
                        message: l10n.clubJoinedEmpty,
                        action: OutlinedButton(
                          onPressed: () => context.go(
                            AppRoutes.homeForDiscoveryTab('clubs'),
                          ),
                          child: Text(l10n.clubBrowse),
                        ),
                      )
                    : _AdaptiveGrid(
                        width: constraints.maxWidth,
                        itemCount: memberClubs.length,
                        itemBuilder: (_, index) => _ClubCard(
                          club: memberClubs[index],
                          showActions: false,
                        ),
                      );
              },
              loading: () => _CardSkeletonGrid(width: constraints.maxWidth),
              error: (error, _) => _InlineError(
                error: error,
                onRetry: () => ref.invalidate(myClubsProvider),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(
              icon: AppIcons.clock,
              title: l10n.clubAwaitingApproval,
              count: outgoing.asData?.value.length,
              color: Colors.orange,
            ),
            const SizedBox(height: AppSpacing.md),
            outgoing.when(
              data: (items) => items.isEmpty
                  ? _EmptyPanel(message: l10n.clubAwaitingApprovalEmpty)
                  : Column(
                      children: [
                        for (final request in items) ...[
                          _OutgoingRequestCard(request: request),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
              loading: () => const _ListSkeleton(),
              error: (error, _) => _InlineError(
                error: error,
                onRetry: () => ref.invalidate(myClubRequestsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.count,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (count != null)
        Badge(
          backgroundColor: color.withValues(alpha: .12),
          textColor: color,
          label: Text('$count'),
        ),
    ],
  );
}

class _ClubTag extends StatelessWidget {
  const _ClubTag({
    required this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final fg = textColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({
    required this.width,
    required this.itemCount,
    required this.itemBuilder,
    this.maxExtent = 440,
  });

  final double width;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxExtent;

  @override
  Widget build(BuildContext context) {
    if (width < 600) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            itemBuilder(context, i),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = (availableWidth / maxExtent).ceil().clamp(1, 4);
        final itemWidth =
            (availableWidth - ((columns - 1) * AppSpacing.md)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(
                width: itemWidth,
                child: itemBuilder(context, i),
              ),
          ],
        );
      },
    );
  }
}

class _ClubCard extends ConsumerWidget {
  const _ClubCard({required this.club, required this.showActions});

  final ClubSummary club;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final busy = ref.watch(clubManagementControllerProvider).isLoading;
    final pending = club.status == 'PENDING';
    final contextText =
        club.defaultVenue?.name ??
        (club.schedules.isEmpty
            ? null
            : '${club.schedules.first.startTime}-${club.schedules.first.endTime}');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: pending
            ? null
            : () => context.push(
                showActions
                    ? AppRoutes.manageClub(club.id)
                    : AppRoutes.clubDetail(club.slug ?? club.id),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClubAvatar(club: club, size: 54),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                club.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (showActions)
                              PopupMenuButton<String>(
                                enabled: !busy,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  AppIcons.moreHorizontal,
                                  size: 20,
                                  color: palette?.mutedForeground,
                                ),
                                onSelected: (value) =>
                                    _handleAction(context, ref, value),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'manage',
                                    child: Text(l10n.clubManageAction),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.commonEdit),
                                  ),
                                  PopupMenuItem(
                                    value: 'fees',
                                    child: Text(l10n.clubFeeConfiguration),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.commonDelete),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildRoleTag(context, l10n, palette),
                            _ClubTag(
                              icon: AppIcons.users,
                              label: l10n.socialMemberCount(club.memberCount),
                            ),
                            if (pending)
                              _ClubTag(
                                label: l10n.clubStatusPending,
                                backgroundColor: palette?.warning.withValues(
                                  alpha: 0.12,
                                ),
                                textColor: palette?.warning,
                              ),
                          ],
                        ),
                        if (contextText != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                club.defaultVenue == null
                                    ? AppIcons.clock
                                    : AppIcons.mapPin,
                                size: 13,
                                color: palette?.mutedForeground,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  contextText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette?.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color:
                  palette?.border.withValues(alpha: 0.6) ?? theme.dividerColor,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              color: theme.colorScheme.surfaceContainerLowest,
              child: Row(
                children: [
                  Icon(
                    AppIcons.user,
                    size: 14,
                    color: palette?.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.clubHostedBy(club.hostName ?? l10n.clubNotSpecified),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette?.mutedForeground,
                      ),
                    ),
                  ),
                  if (pending)
                    _ClubTag(
                      label: l10n.clubStatusPending,
                      backgroundColor: palette?.warning.withValues(alpha: 0.12),
                      textColor: palette?.warning,
                    )
                  else ...[
                    Text(
                      showActions ? l10n.clubManageAction : l10n.clubView,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTag(
    BuildContext context,
    AppLocalizations l10n,
    AppPalette? palette,
  ) {
    final theme = Theme.of(context);
    return switch (club.role) {
      'ADMIN' => _ClubTag(
        icon: AppIcons.shield,
        label: l10n.clubRoleAdmin,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        textColor: theme.colorScheme.primary,
      ),
      'MODERATOR' => _ClubTag(
        icon: AppIcons.shield,
        label: l10n.clubRoleModerator,
        backgroundColor: (palette?.info ?? Colors.blue).withValues(alpha: 0.1),
        textColor: palette?.info ?? Colors.blue,
      ),
      _ => _ClubTag(
        label: l10n.clubRoleMember,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        textColor: theme.colorScheme.onSurfaceVariant,
      ),
    };
  }

  String _roleLabel(AppLocalizations l10n, String role) => switch (role) {
    'ADMIN' => l10n.clubRoleAdmin,
    'MODERATOR' => l10n.clubRoleModerator,
    _ => l10n.clubRoleMember,
  };

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'manage':
        await context.push(AppRoutes.manageClub(club.id));
      case 'edit':
        await context.push(AppRoutes.editClub(club.id));
      case 'fees':
        await context.push(AppRoutes.clubFees(club.id));
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubDeleteTitle,
      content: l10n.clubDeleteConfirm(club.name),
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .deleteClub(club.id),
      l10n.clubActionFailed,
    );
  }
}

class _IncomingRequestCard extends ConsumerWidget {
  const _IncomingRequestCard({required this.request});

  final ClubJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final busy = ref.watch(clubManagementControllerProvider).isLoading;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserAvatar(
                  name: request.userName,
                  image: request.userImage,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (request.club?.name.isNotEmpty ?? false)
                            request.club!.name,
                          _submitted(context, request.createdAt),
                          if ((request.sessionsPlayedCount ?? 0) > 0)
                            l10n.clubSessionsPlayed(
                              request.sessionsPlayedCount!,
                            ),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette?.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color:
                        palette?.border.withValues(alpha: 0.5) ??
                        theme.dividerColor,
                  ),
                ),
                child: Text(
                  '“${request.message!.trim()}”',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: palette?.mutedForeground,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final reason = await _rejectionReason(context);
                          if (reason == null || !context.mounted) return;
                          await _runAction(
                            context,
                            () => ref
                                .read(clubManagementControllerProvider.notifier)
                                .rejectRequest(
                                  request.clubId,
                                  request.id,
                                  response: reason,
                                ),
                            l10n.clubActionFailed,
                            success: l10n.clubRejectSuccess,
                          );
                        },
                  child: Text(l10n.clubReject),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _runAction(
                          context,
                          () => ref
                              .read(clubManagementControllerProvider.notifier)
                              .approveRequest(request.clubId, request.id),
                          l10n.clubActionFailed,
                          success: l10n.clubApproveSuccess,
                        ),
                  child: Text(l10n.clubApprove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequestCard extends ConsumerWidget {
  const _OutgoingRequestCard({required this.request});

  final ClubJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final busy = ref.watch(clubManagementControllerProvider).isLoading;
    final club = request.club;
    final name = club?.name ?? '';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserAvatar(name: name, image: club?.image),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _ClubTag(
                            label: l10n.clubStatusPending,
                            backgroundColor: palette?.warning.withValues(
                              alpha: 0.12,
                            ),
                            textColor: palette?.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.clubHostedBy(
                          club?.hostName ?? l10n.clubNotSpecified,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette?.mutedForeground,
                        ),
                      ),
                      if (request.message?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          '“${request.message!.trim()}”',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _submitted(context, request.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette?.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: palette?.border.withValues(alpha: 0.6) ?? theme.dividerColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: club == null
                      ? null
                      : () => context.push(
                          AppRoutes.clubDetail(club.slug ?? club.id),
                        ),
                  icon: const Icon(AppIcons.chevronRight, size: 16),
                  label: Text(l10n.clubView),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: busy ? null : () => _withdraw(context, ref, name),
                  icon: const Icon(AppIcons.undo, size: 16),
                  label: Text(l10n.clubWithdrawRequest),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubWithdrawTitle,
      content: l10n.clubWithdrawConfirm(name),
      confirmLabel: l10n.clubWithdrawRequest,
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(
      context,
      () => ref
          .read(clubManagementControllerProvider.notifier)
          .cancelJoinRequest(request.clubId),
      l10n.clubActionFailed,
      success: l10n.clubWithdrawSuccess,
    );
  }
}

class _PendingClubCard extends ConsumerWidget {
  const _PendingClubCard({required this.club});

  final ClubSummary club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final busy = ref.watch(clubManagementControllerProvider).isLoading;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ClubAvatar(club: club, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (club.location?.isNotEmpty ?? false)
                        Row(
                          children: [
                            Icon(
                              AppIcons.mapPin,
                              size: 14,
                              color: palette?.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                club.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette?.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        l10n.clubHostedBy(
                          club.hostName ?? l10n.clubNotSpecified,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette?.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            context,
                            () => ref
                                .read(clubManagementControllerProvider.notifier)
                                .approveClub(club.id),
                            l10n.clubActionFailed,
                            success: l10n.clubApproveSuccess,
                          ),
                    child: Text(l10n.clubApprove),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final reason = await _rejectionReason(context);
                            if (reason == null || !context.mounted) return;
                            await _runAction(
                              context,
                              () => ref
                                  .read(
                                    clubManagementControllerProvider.notifier,
                                  )
                                  .rejectClub(club.id, reason),
                              l10n.clubActionFailed,
                              success: l10n.clubRejectSuccess,
                            );
                          },
                    child: Text(l10n.clubReject),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubAvatar extends StatelessWidget {
  const _ClubAvatar({required this.club, this.size = 54});

  final ClubSummary club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final hasImage = club.heroImage?.trim().isNotEmpty ?? false;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: palette?.border.withValues(alpha: 0.8) ?? theme.dividerColor,
        ),
        color: theme.colorScheme.primaryContainer,
      ),
      child: !hasImage
          ? Center(
              child: Text(
                club.name.trim().isEmpty
                    ? '?'
                    : club.name.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: club.heroImage!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Center(
                child: Icon(
                  AppIcons.clubs,
                  size: size * 0.45,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, this.image});

  final String name;
  final String? image;

  @override
  Widget build(BuildContext context) => UserAvatar(
    name: name,
    imageUrl: image,
    size: 40,
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message, this.icon, this.action});

  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 44),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.md),
          action!,
        ],
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: AppErrorView(error: error, onRetry: onRetry),
  );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      3,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: Card(child: SizedBox(height: 108)),
      ),
    ),
  );
}

class _CardSkeletonGrid extends StatelessWidget {
  const _CardSkeletonGrid({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => _AdaptiveGrid(
    width: width,
    itemCount: 3,
    itemBuilder: (_, _) => const Card(child: SizedBox(height: 140)),
  );
}

String _submitted(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return AppLocalizations.of(context).clubRequestSubmitted(
    DateFormat.yMMMd(locale).format(date.toLocal()),
  );
}

Future<String?> _rejectionReason(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final form = FormGroup({
    'reason': FormControl<String>(validators: [Validators.required]),
  });
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.clubReject),
      content: AppReactiveForm(
        formGroup: form,
        child: ReactiveTextField<String>(
          key: const Key('club-rejection-reason'),
          formControlName: 'reason',
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.clubRejectionReason),
          validationMessages: {
            ValidationMessage.required: (_) => l10n.clubRejectionReasonRequired,
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            form.markAllAsTouched();
            if (form.invalid || form.pending) return;
            Navigator.pop(
              dialogContext,
              (form.control('reason').value as String).trim(),
            );
          },
          child: Text(l10n.clubReject),
        ),
      ],
    ),
  );
  form.dispose();
  return result;
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
  String failure, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
    }
  }
}
