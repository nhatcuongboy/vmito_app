import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/skill_level_badge.dart';

class PublicClubMembersTab extends ConsumerStatefulWidget {
  const PublicClubMembersTab({
    required this.club,
    required this.isAdmin,
    super.key,
  });

  final ClubSummary club;
  final bool isAdmin;

  @override
  ConsumerState<PublicClubMembersTab> createState() =>
      _PublicClubMembersTabState();
}

class _PublicClubMembersTabState extends ConsumerState<PublicClubMembersTab> {
  static const _pageSize = 8;
  static const _wideBreakpoint = 600.0;

  int _visibleCount = _pageSize;
  String? _removingMemberId;

  @override
  void didUpdateWidget(covariant PublicClubMembersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.club.id != widget.club.id) {
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.club.members.take(_visibleCount).toList();
    final hasMore = widget.club.members.length > members.length;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _wideBreakpoint ? 2 : 1;
        return ListView(
          key: const Key('public-club-members-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            96,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Card(
                  key: const Key('public-club-members-card'),
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context),
                        if (members.isEmpty)
                          _emptyState(context)
                        else ...[
                          GridView.builder(
                            key: Key('club-members-grid-$columns'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: members.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: AppSpacing.sm,
                                  mainAxisSpacing: AppSpacing.xs,
                                  mainAxisExtent: 64,
                                ),
                            itemBuilder: (context, index) => _memberCard(
                              context,
                              members[index],
                              palette,
                            ),
                          ),
                          if (hasMore) ...[
                            const SizedBox(height: AppSpacing.md),
                            Center(
                              child: OutlinedButton(
                                key: const Key('club-members-view-more'),
                                onPressed: () => setState(
                                  () => _visibleCount += _pageSize,
                                ),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).clubViewMoreMembers,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.clubMembers,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Container(
              key: const Key('club-members-count'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: palette.muted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                l10n.clubMembersCount(widget.club.memberCount),
                style: theme.textTheme.labelSmall,
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('club-members-add'),
                onPressed: _showAddMemberSheet,
                icon: const Icon(AppIcons.userPlus, size: 18),
                label: Text(l10n.clubAddMember),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('club-members-empty'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl * 2),
      child: Column(
        children: [
          Icon(
            AppIcons.users,
            size: 44,
            color: palette.mutedForeground,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.clubMembersEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.mutedForeground,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (widget.isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('club-members-add-first'),
              onPressed: _showAddMemberSheet,
              icon: const Icon(AppIcons.userPlus, size: 18),
              label: Text(l10n.clubAddFirstMember),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberCard(
    BuildContext context,
    ClubMember member,
    AppPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final removing = _removingMemberId == member.userId;
    return Material(
      key: ValueKey('club-member-${member.userId}'),
      color: palette.muted.withValues(alpha: .7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showMemberDetails(member),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            children: [
              UserAvatar(
                name: member.name,
                gender: member.gender,
                imageUrl: member.image,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (member.role != 'MEMBER' || member.level != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        children: [
                          if (member.role != 'MEMBER')
                            _RoleBadge(role: member.role),
                          if (member.level != null)
                            SkillLevelBadge(
                              level: member.level!,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  key: ValueKey('club-member-remove-${member.userId}'),
                  tooltip: l10n.clubRemoveFromClub,
                  onPressed: removing ? null : () => _confirmRemove(member),
                  color: Theme.of(context).colorScheme.error,
                  icon: removing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.delete, size: 20),
                )
              else
                Icon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: palette.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMemberDetails(ClubMember member) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _MemberDetailsSheet(
          member: member,
          isAdmin: widget.isAdmin,
          onViewProfile: member.userId.isEmpty
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  unawaited(
                    context.push(AppRoutes.publicProfile(member.userId)),
                  );
                },
          onRemove: widget.isAdmin
              ? () {
                  Navigator.pop(sheetContext);
                  unawaited(_confirmRemove(member));
                }
              : null,
        ),
      );

  Future<void> _confirmRemove(ClubMember member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.clubRemoveMember,
      content: l10n.clubRemoveMemberConfirm(member.name),
      confirmLabel: l10n.commonRemove,
      confirmKey: const Key('club-member-confirm-remove'),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removingMemberId = member.userId);
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .removeMember(widget.club.id, member.userId);
      if (mounted) _toast(l10n.clubMemberRemovedSuccess);
    } on Object {
      if (mounted) _toast(l10n.clubMemberRemoveFailed);
    } finally {
      if (mounted) setState(() => _removingMemberId = null);
    }
  }

  Future<void> _showAddMemberSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ClubMemberSearchSheet(club: widget.club),
  );

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final color = switch (role) {
      'ADMIN' => palette.warning,
      'MODERATOR' => palette.info,
      _ => palette.mutedForeground,
    };
    final label = switch (role) {
      'ADMIN' => l10n.clubRoleAdmin,
      'MODERATOR' => 'Mod',
      _ => l10n.clubRoleMember,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MemberDetailsSheet extends StatelessWidget {
  const _MemberDetailsSheet({
    required this.member,
    required this.isAdmin,
    this.onViewProfile,
    this.onRemove,
  });

  final ClubMember member;
  final bool isAdmin;
  final VoidCallback? onViewProfile;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + bottom,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.clubMemberDetails,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          name: member.name,
                          gender: member.gender,
                          imageUrl: member.image,
                          size: 72,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          member.name,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _RoleBadge(role: member.role),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MemberInfoRow(
                          icon: _genderIcon(member.gender),
                          label: l10n.clubMemberGender,
                          value: _genderLabel(l10n, member.gender),
                        ),
                        _MemberInfoRow(
                          icon: AppIcons.trophy,
                          label: l10n.clubMemberLevel,
                          value: member.level == null
                              ? l10n.clubMemberInfoNotUpdated
                              : l10n.levelName(member.level!),
                        ),
                        _MemberInfoRow(
                          icon: AppIcons.calendar,
                          label: l10n.clubMemberJoinedDate,
                          value: member.createdAt == null
                              ? l10n.clubMemberInfoNotUpdated
                              : Dates.dateOnly(
                                  member.createdAt!,
                                  locale: locale,
                                ),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isAdmin && onRemove != null) ...[
                    OutlinedButton.icon(
                      key: const Key('club-member-details-remove'),
                      onPressed: onRemove,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      icon: const Icon(AppIcons.delete, size: 18),
                      label: Text(l10n.clubRemoveFromClub),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  FilledButton(
                    key: const Key('club-member-view-profile'),
                    onPressed: onViewProfile,
                    child: Text(l10n.clubViewProfile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _genderIcon(String? gender) => switch (gender) {
    'MALE' => AppIcons.male,
    'FEMALE' => AppIcons.female,
    _ => AppIcons.user,
  };

  static String _genderLabel(AppLocalizations l10n, String? gender) =>
      switch (gender) {
        'MALE' => l10n.clubMemberGenderMale,
        'FEMALE' => l10n.clubMemberGenderFemale,
        null || '' => l10n.clubMemberInfoNotUpdated,
        _ => l10n.clubMemberGenderOther,
      };
}

class _MemberInfoRow extends StatelessWidget {
  const _MemberInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: palette.mutedForeground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class _MemberSearchControl {
  static const query = 'query';
}

class _ClubMemberSearchSheet extends ConsumerStatefulWidget {
  const _ClubMemberSearchSheet({required this.club});

  final ClubSummary club;

  @override
  ConsumerState<_ClubMemberSearchSheet> createState() =>
      _ClubMemberSearchSheetState();
}

class _ClubMemberSearchSheetState
    extends ConsumerState<_ClubMemberSearchSheet> {
  final _form = FormGroup({
    _MemberSearchControl.query: FormControl<String>(
      validators: [Validators.required],
    ),
  });
  StreamSubscription<Object?>? _querySubscription;
  Timer? _debounce;
  List<ClubUserSearchResult> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;
  bool _searchFailed = false;
  String? _addingUserId;
  String? _activeSearchQuery;
  int _searchRequest = 0;

  FormControl<String> get _query =>
      _form.control(_MemberSearchControl.query) as FormControl<String>;

  @override
  void initState() {
    super.initState();
    _querySubscription = _query.valueChanges.listen((value) {
      _debounce?.cancel();
      _searchRequest++;
      final query = value?.trim() ?? '';
      if (query.isEmpty) {
        setState(() {
          _results = const [];
          _searching = false;
          _activeSearchQuery = null;
          _hasSearched = false;
          _searchFailed = false;
        });
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 400), _search);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_querySubscription?.cancel());
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + bottom,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.sizeOf(context).height * .82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.clubAddMember,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppReactiveForm(
                  formGroup: _form,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final field = ReactiveTextField<String>(
                        key: const Key('public-club-member-search'),
                        formControlName: _MemberSearchControl.query,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(markTouched: true),
                        decoration: InputDecoration(
                          hintText: l10n.clubSearchUsers,
                          prefixIcon: const Icon(AppIcons.search),
                          errorMaxLines: 2,
                        ),
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              l10n.clubSearchUsersRequired,
                        },
                      );
                      final button = FilledButton(
                        key: const Key('public-club-member-search-button'),
                        onPressed: _searching
                            ? null
                            : () => _search(markTouched: true),
                        child: Text(l10n.commonSearch),
                      );
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            field,
                            const SizedBox(height: AppSpacing.sm),
                            button,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: field),
                          const SizedBox(width: AppSpacing.sm),
                          button,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(child: _searchBody(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.clubMemberSearchFailed, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _search(markTouched: true),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (!_hasSearched) {
      return Center(
        child: Text(
          l10n.clubSearchUsersHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.mutedForeground),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          l10n.clubNoUsersFound,
          key: const Key('club-member-search-empty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.mutedForeground),
        ),
      );
    }
    return ListView.separated(
      key: const Key('club-member-search-results'),
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final user = _results[index];
        final isMember = widget.club.members.any(
          (member) => member.userId == user.id,
        );
        final adding = _addingUserId == user.id;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.muted.withValues(alpha: .7),
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                UserAvatar(name: user.name, imageUrl: user.image, size: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (isMember)
                  Text(
                    l10n.clubAlreadyMember,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.success,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  FilledButton(
                    key: ValueKey('club-member-add-${user.id}'),
                    onPressed: adding || _addingUserId != null
                        ? null
                        : () => _add(user),
                    child: adding
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.clubMemberAddAction),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _search({bool markTouched = false}) async {
    _debounce?.cancel();
    if (markTouched) _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final query = _query.value?.trim() ?? '';
    if (query.isEmpty) return;
    if (_searching && _activeSearchQuery == query) return;
    final request = ++_searchRequest;
    setState(() {
      _searching = true;
      _activeSearchQuery = query;
      _searchFailed = false;
    });
    try {
      final results = await ref.read(
        clubUserSearchProvider((clubId: widget.club.id, query: query)).future,
      );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } on Object {
      if (mounted && request == _searchRequest) {
        setState(() {
          _searchFailed = true;
          _hasSearched = true;
        });
      }
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() {
          _searching = false;
          _activeSearchQuery = null;
        });
      }
    }
  }

  Future<void> _add(ClubUserSearchResult user) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _addingUserId = user.id);
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .addMember(widget.club.id, user.id);
      if (!mounted) return;
      setState(
        () => _results = _results
            .where((result) => result.id != user.id)
            .toList(growable: false),
      );
      _toast(l10n.clubMemberAddedSuccess);
    } on Object {
      if (mounted) _toast(l10n.clubMemberAddFailed);
    } finally {
      if (mounted) setState(() => _addingUserId = null);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
