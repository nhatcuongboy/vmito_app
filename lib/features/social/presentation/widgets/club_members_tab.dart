import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubMembersTab extends ConsumerWidget {
  const ClubMembersTab({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(clubMembersProvider(clubId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AddMemberDialog(clubId: clubId),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.clubAddMember),
      ),
      body: members.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(clubMembersProvider(clubId).future),
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .5,
                      child: Center(child: Text(l10n.clubMembersEmpty)),
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
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _MemberTile(clubId: clubId, member: items[index]),
                ),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubMembersProvider(clubId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.clubId, required this.member});

  final String clubId;
  final ClubMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: member.image == null
            ? null
            : CachedNetworkImageProvider(member.image!),
        child: member.image == null
            ? const Icon(Icons.person_outline_rounded)
            : null,
      ),
      title: Text(member.name),
      subtitle: Text('${member.email}\n${_roleLabel(l10n, member.role)}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'remove') {
            await _remove(context, ref);
          } else {
            await ref
                .read(clubManagementControllerProvider.notifier)
                .updateMemberRole(clubId, member.userId, value);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'ADMIN', child: Text(l10n.clubRoleAdmin)),
          PopupMenuItem(
            value: 'MODERATOR',
            child: Text(l10n.clubRoleModerator),
          ),
          PopupMenuItem(value: 'MEMBER', child: Text(l10n.clubRoleMember)),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'remove', child: Text(l10n.commonRemove)),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) => switch (role) {
    'ADMIN' => l10n.clubRoleAdmin,
    'MODERATOR' => l10n.clubRoleModerator,
    _ => l10n.clubRoleMember,
  };

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clubRemoveMember),
        content: Text(l10n.clubRemoveMemberConfirm(member.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .removeMember(clubId, member.userId);
    }
  }
}

class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _searchController = TextEditingController();
  List<ClubUserSearchResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.clubAddMember),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('club-member-search'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: l10n.clubSearchUsers,
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? Center(child: Text(l10n.clubSearchUsersHint))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        return ListTile(
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          trailing: IconButton(
                            tooltip: l10n.clubAddMember,
                            onPressed: () => _add(user),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final results = await ref.read(
        clubUserSearchProvider((clubId: widget.clubId, query: query)).future,
      );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(ClubUserSearchResult user) async {
    await ref
        .read(clubManagementControllerProvider.notifier)
        .addMember(widget.clubId, user.id);
    if (mounted) {
      setState(
        () => _results = _results.where((item) => item.id != user.id).toList(),
      );
    }
  }
}
