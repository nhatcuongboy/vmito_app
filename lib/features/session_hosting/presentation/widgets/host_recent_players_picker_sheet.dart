import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/roster/data/roster_service.dart';
import 'package:vmito_app/features/roster/domain/host_recent_player.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_full_height_modal.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/gender_icon.dart';

Future<List<HostRecentPlayer>?> showHostRecentPlayersPickerSheet(
  BuildContext context, {
  String? clubId,
  Set<String> existingProfileIds = const {},
  Set<String> existingUserIds = const {},
}) {
  return showAppFullHeightModal<List<HostRecentPlayer>>(
    context,
    builder: (context) => _HostRecentPlayersPickerSheet(
      clubId: clubId,
      existingProfileIds: existingProfileIds,
      existingUserIds: existingUserIds,
    ),
  );
}

class _HostRecentPlayersPickerSheet extends ConsumerStatefulWidget {
  const _HostRecentPlayersPickerSheet({
    this.clubId,
    required this.existingProfileIds,
    required this.existingUserIds,
  });

  final String? clubId;
  final Set<String> existingProfileIds;
  final Set<String> existingUserIds;

  @override
  ConsumerState<_HostRecentPlayersPickerSheet> createState() =>
      _HostRecentPlayersPickerSheetState();
}

class _HostRecentPlayersPickerSheetState
    extends ConsumerState<_HostRecentPlayersPickerSheet> {
  final _searchController = TextEditingController();
  final Set<HostRecentPlayer> _selected = {};
  Timer? _debounce;
  List<HostRecentPlayer> _players = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchPlayers(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayers(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(rosterServiceProvider)
          .getHostRecentPlayers(
            clubId: widget.clubId,
            search: query,
          );
      if (!mounted) return;
      setState(() {
        _players = results;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_fetchPlayers(query));
    });
  }

  void _toggleSelection(HostRecentPlayer player) {
    setState(() {
      if (_selected.any((p) => p.profileId == player.profileId)) {
        _selected.removeWhere((p) => p.profileId == player.profileId);
      } else {
        _selected.add(player);
      }
    });
  }

  List<HostRecentPlayer> _sortPlayers(List<HostRecentPlayer> players) {
    final myClubs = ref.watch(myClubsProvider).asData?.value ?? const [];
    final managedClubs =
        ref.watch(managedClubsProvider).asData?.value ?? const [];
    final userClubIds = <String>{
      if (widget.clubId != null) widget.clubId!,
      for (final c in myClubs) c.id,
      for (final c in managedClubs) c.id,
    };

    int getPriority(HostRecentPlayer p) {
      if (widget.clubId != null && p.clubId == widget.clubId) return 0;
      if (p.clubId != null && userClubIds.contains(p.clubId)) return 1;
      if (p.isClubMember) return 2;
      return 3;
    }

    return [...players]..sort((a, b) {
      final prioA = getPriority(a);
      final prioB = getPriority(b);
      if (prioA != prioB) return prioA.compareTo(prioB);

      final dateA = a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCmp = dateB.compareTo(dateA);
      if (dateCmp != 0) return dateCmp;

      return b.totalSessions.compareTo(a.totalSessions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sortedPlayers = _sortPlayers(_players);

    return Column(
      children: [
        AppSheetHeader(
          title: l10n.rosterPickFromRosterTitle,
          onClose: () => Navigator.pop(context),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.rosterSearchPlaceholder,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.errorUnknown,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () =>
                              _fetchPlayers(_searchController.text),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : sortedPlayers.isEmpty && !_loading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      l10n.rosterNoRecentPlayersFound,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: sortedPlayers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final player = sortedPlayers[index];
                    final isAlreadyInSession =
                        widget.existingProfileIds.contains(player.profileId) ||
                        (player.userId != null &&
                            widget.existingUserIds.contains(player.userId));
                    final isChecked = _selected.any(
                      (p) => p.profileId == player.profileId,
                    );

                    return CheckboxListTile(
                      value: isChecked,
                      enabled: !isAlreadyInSession,
                      onChanged: isAlreadyInSession
                          ? null
                          : (_) => _toggleSelection(player),
                      secondary: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          player.name.isNotEmpty
                              ? player.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (player.gender != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(genderIcon(player.gender), size: 16),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (player.level != null) ...[
                                Text(
                                  l10n.levelName(player.level!),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Text(
                                '${player.totalSessions} sessions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (player.lastPlayedAt != null) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '• ${Dates.dateOnly(player.lastPlayedAt!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (isAlreadyInSession)
                            Text(
                              l10n.hostAddPlayerAlreadySelected,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            )
                          else if (player.club?.name != null)
                            Text(
                              '[${l10n.rosterGroupName(player.club!.name)}]',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              '[${l10n.rosterPersonalBadge}]',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        AppSheetActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          _selected.toList(growable: false),
                        ),
                  child: Text(
                    _selected.isEmpty
                        ? l10n.rosterAddToSessionAction
                        : '${l10n.rosterAddToSessionAction} (${_selected.length})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
