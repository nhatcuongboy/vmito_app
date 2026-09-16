import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_card.dart';
import 'package:vmito_app/features/roster/presentation/widgets/player_profile_form_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubGuestsTab extends ConsumerWidget {
  const ClubGuestsTab({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestsAsync = ref.watch(clubRosterProvider(clubId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'club-guests-add-fab-$clubId',
        onPressed: () => showPlayerProfileFormSheet(
          context,
          defaultClubId: clubId,
        ),
        icon: const Icon(AppIcons.userPlus),
        label: Text(l10n.clubAddGuestAction),
      ),
      body: guestsAsync.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(clubRosterProvider(clubId).future),
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.5,
                      child: Center(
                        child: Text(
                          l10n.clubGuestsEmpty,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) => PlayerProfileCard(
                    profile: items[index],
                    onChanged: () => ref.invalidate(clubRosterProvider(clubId)),
                  ),
                ),
        ),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(clubRosterProvider(clubId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
