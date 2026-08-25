import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/session/domain/reference_video.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_podium.dart';
import 'package:vmito_app/features/tournament/domain/tournament_pulse.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  const TournamentDetailScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(tournamentDetailControllerProvider(widget.idOrSlug).notifier)
            .refresh(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(
      tournamentDetailControllerProvider(widget.idOrSlug),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tournamentDetailTitle)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(
            tournamentDetailControllerProvider(widget.idOrSlug),
          ),
        ),
        data: (state) => TournamentHomeContent(
          state: state,
          onRefresh: () => ref
              .read(
                tournamentDetailControllerProvider(widget.idOrSlug).notifier,
              )
              .refresh(),
          onRetryMatches: () => ref
              .read(
                tournamentDetailControllerProvider(widget.idOrSlug).notifier,
              )
              .refreshLiveSections(),
        ),
      ),
    );
  }
}

class TournamentHomeContent extends ConsumerWidget {
  const TournamentHomeContent({
    required this.state,
    required this.onRefresh,
    required this.onRetryMatches,
  });

  final TournamentDetailState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetryMatches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = state.tournament;
    final auth = ref.watch(authControllerProvider);
    final canManage =
        auth.user?.id == tournament.hostId || auth.user?.role == UserRole.admin;
    final missingSections = <({String label, String option})>[
      if (tournament.description?.trim().isEmpty ?? true)
        (
          label: AppLocalizations.of(context).tournamentDetailAddNotes,
          option: 'name',
        ),
      if (tournament.youtubeVideoUrls.isEmpty)
        (
          label: AppLocalizations.of(context).tournamentDetailAddVideos,
          option: 'videos',
        ),
      if (state.sponsors.isEmpty)
        (
          label: AppLocalizations.of(context).tournamentDetailAddSponsors,
          option: 'sponsors',
        ),
      if (tournament.resolvedContactName == null &&
          tournament.resolvedContactEmail == null &&
          tournament.contactPhone == null)
        (
          label: AppLocalizations.of(context).tournamentDetailAddContact,
          option: 'contact',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 700
            ? AppSpacing.lg
            : AppSpacing.md;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              padding,
              AppSpacing.md,
              padding,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(
                        tournament: tournament,
                        status: state.effectiveStatus,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PulseCard(
                        state: state,
                        onRetry: onRetryMatches,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _QuickActions(tournament: tournament),
                      const SizedBox(height: AppSpacing.md),
                      _CategoriesSection(
                        categories: tournament.categories,
                        canManage: canManage,
                        tournament: tournament,
                      ),
                      if (tournament.categories.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _CompetitionInfoSection(
                          categories: tournament.categories,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PodiumSection(state: state),
                      ],
                      if (tournament.venues.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _VenuesSection(
                          venues: tournament.venues,
                          canManage: canManage,
                          tournament: tournament,
                        ),
                      ],
                      if (tournament.description?.trim().isNotEmpty ??
                          false) ...[
                        const SizedBox(height: AppSpacing.md),
                        _NotesSection(
                          text: tournament.description!.trim(),
                          canManage: canManage,
                          tournament: tournament,
                        ),
                      ],
                      if (tournament.youtubeVideoUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _VideosSection(
                          urls: tournament.youtubeVideoUrls,
                          canManage: canManage,
                          tournament: tournament,
                        ),
                      ],
                      if (state.sponsors.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _SponsorsSection(
                          sponsors: state.sponsors,
                          canManage: canManage,
                          tournament: tournament,
                        ),
                      ],
                      if (_hasContact(tournament)) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ContactSection(
                          tournament: tournament,
                          canManage: canManage,
                        ),
                      ],
                      if (canManage && missingSections.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _OrganizerCompletion(
                          tournament: tournament,
                          items: missingSections,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _QrSection(tournament: tournament),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _hasContact(TournamentDetail tournament) =>
      tournament.resolvedContactName != null ||
      tournament.resolvedContactEmail != null ||
      tournament.contactPhone != null;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.tournament, required this.status});

  final TournamentDetail tournament;
  final TournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final venueName = tournament.venues.map((venue) => venue.name).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (tournament.resolvedCoverPhoto case final cover?)
                  CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const _HeroPlaceholder(),
                  )
                else
                  const _HeroPlaceholder(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC020617)],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _StatusPill(status: status),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Row(
                    children: [
                      _OverlayButton(
                        tooltip: l10n.commonShare,
                        icon: AppIcons.share,
                        onPressed: () => _shareTournament(context, tournament),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FavoriteButton(
                        type: FavoriteType.tournament,
                        targetId: tournament.id,
                        showCount: false,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          shadows: const [Shadow(blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _HeroMeta(
                        icon: AppIcons.calendarMonth,
                        text: DateFormat.yMMMMEEEEd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(tournament.startDate.toLocal()),
                      ),
                      if (venueName.isNotEmpty)
                        _HeroMeta(icon: AppIcons.location, text: venueName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: AppIcons.users,
                    text: l10n.tournamentDetailTeams(
                      tournament.registrationCount,
                    ),
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: _Stat(
                    icon: AppIcons.user,
                    text: l10n.tournamentDetailAthletes(
                      tournament.playerCount,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.brand, Color(0xFF0F766E)]),
    ),
    child: Center(child: Icon(AppIcons.trophy, color: Colors.white, size: 56)),
  );
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      TournamentStatus.preparing => (
        l10n.tournamentStatusPreparing,
        Colors.blue,
      ),
      TournamentStatus.inProgress => (
        l10n.tournamentStatusInProgress,
        AppColors.success,
      ),
      TournamentStatus.finished => (
        l10n.tournamentStatusFinished,
        AppColors.warning,
      ),
      TournamentStatus.cancelled => (
        l10n.tournamentStatusCancelled,
        AppColors.destructive,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.state, required this.onRetry});
  final TournamentDetailState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.matchesError != null) {
      return _SectionCard(
        child: Row(
          children: [
            const Icon(AppIcons.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(l10n.tournamentDetailMatchesUnavailable)),
            TextButton(
              onPressed: () => unawaited(onRetry()),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    final selection = selectTournamentPulse(
      state.matches,
      state.effectiveStatus,
    );
    final title = switch (selection.kind) {
      TournamentPulseKind.live => l10n.tournamentDetailPulseLive,
      TournamentPulseKind.next => l10n.tournamentDetailPulseNext,
      TournamentPulseKind.finished => l10n.tournamentDetailPulseFinished,
      TournamentPulseKind.preparing => l10n.tournamentDetailPulsePreparing,
      TournamentPulseKind.cancelled => l10n.tournamentDetailPulseCancelled,
    };
    final match = selection.match;
    final category = match == null
        ? null
        : state.tournament.categories
              .where((item) => item.id == match.categoryId)
              .firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  selection.kind == TournamentPulseKind.live
                      ? AppIcons.wifi
                      : AppIcons.trophy,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (selection.kind == TournamentPulseKind.live)
                  Chip(label: Text(l10n.tournamentDetailLive)),
              ],
            ),
            if (match != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                      category?.name,
                      if (match.startTime != null)
                        DateFormat.Hm().format(match.startTime!.toLocal()),
                      _courtLabel(match.court),
                    ]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _MatchSide(
                label: match.side(1)?.teamLabel ?? '—',
                score: match.score1,
              ),
              const Divider(),
              _MatchSide(
                label: match.side(2)?.teamLabel ?? '—',
                score: match.score2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _courtLabel(TournamentCourt? court) {
    if (court == null) return null;
    final label = court.name?.trim().isNotEmpty ?? false
        ? court.name!
        : '${court.number}';
    return [court.venueName, label].whereType<String>().join(' · ');
  }
}

class _MatchSide extends StatelessWidget {
  const _MatchSide({required this.label, required this.score});
  final String label;
  final int? score;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      Text(
        '${score ?? '–'}',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.tournament});
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = [
      (l10n.tournamentDetailSchedule, AppIcons.calendarMonth, 'schedule'),
      (l10n.tournamentDetailStandings, AppIcons.trendingUp, 'standings'),
      (l10n.tournamentDetailScoreboard, AppIcons.playCircle, 'scoreboard'),
      (l10n.tournamentDetailShowcase, AppIcons.sparkles, 'showcase'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
          childAspectRatio: 2.35,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              onTap: () => _openTournamentWeb(context, tournament, action.$3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      action.$2,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        action.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.categories,
    required this.canManage,
    required this.tournament,
  });
  final List<TournamentCategory> categories;
  final bool canManage;
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.tournamentDetailCategories,
      icon: AppIcons.tag,
      trailing: canManage
          ? _EditAction(
              onPressed: () => _openManage(context, tournament, 'categories'),
            )
          : null,
      child: categories.isEmpty
          ? Text(l10n.tournamentDetailNoCategories)
          : Column(
              children: [
                for (final (index, category) in categories.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.tag),
                    title: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      category.registrationMode ==
                              TournamentRegistrationMode.individual
                          ? l10n.tournamentDetailCategoryPlayers(
                              category.registrationCount,
                            )
                          : l10n.tournamentDetailCategoryTeams(
                              category.registrationCount,
                            ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CompetitionInfoSection extends StatelessWidget {
  const _CompetitionInfoSection({required this.categories});
  final List<TournamentCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minTileHeight: AppSizes.minTapTarget,
        leading: Icon(
          AppIcons.shuffle,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          l10n.tournamentDetailCompetitionInfo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(l10n.tournamentDetailCompetitionSubtitle),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _CompetitionSheet(categories: categories),
        ),
      ),
    );
  }
}

class _CompetitionSheet extends StatelessWidget {
  const _CompetitionSheet({required this.categories});
  final List<TournamentCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            Text(
              l10n.tournamentDetailCompetitionInfo,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final category in categories) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_formatLabel(category.format, l10n)),
                      if (category.format ==
                              TournamentCategoryFormat.roundRobin ||
                          category.format ==
                              TournamentCategoryFormat
                                  .roundRobinToSingleElimination) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.tournamentDetailPoints(
                            category.winPoints,
                            category.tiePoints,
                            category.lossPoints,
                          ),
                        ),
                        if (category.tiebreakers.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.tournamentDetailTiebreakers,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          for (final (index, item)
                              in category.tiebreakers.indexed)
                            Text(
                              '${index + 1}. ${item['label'] ?? item['id'] ?? '—'}',
                            ),
                        ],
                      ],
                      if (category.format !=
                          TournamentCategoryFormat.roundRobin) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.tournamentDetailPlayoff,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          category.eliminationMatchFormat ??
                              category.matchFormat ??
                              'BEST_OF_3',
                        ),
                        Text(
                          l10n.tournamentDetailThirdPlace(
                            category.thirdPlaceMatch == true
                                ? l10n.tournamentDetailYes
                                : l10n.tournamentDetailNo,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatLabel(
    TournamentCategoryFormat format,
    AppLocalizations l10n,
  ) => switch (format) {
    TournamentCategoryFormat.roundRobin => l10n.tournamentDetailRoundRobin,
    TournamentCategoryFormat.singleElimination =>
      l10n.tournamentDetailSingleElimination,
    TournamentCategoryFormat.roundRobinToSingleElimination =>
      l10n.tournamentDetailRoundRobinPlayoff,
    TournamentCategoryFormat.doubleElimination =>
      l10n.tournamentDetailDoubleElimination,
  };
}

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.state});
  final TournamentDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.tournamentDetailChampions,
      icon: AppIcons.trophy,
      child: state.standingsError != null || state.matchesError != null
          ? Row(
              children: [
                const Icon(AppIcons.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.tournamentDetailMatchesUnavailable)),
              ],
            )
          : Column(
              children: [
                for (final (index, podium) in state.podiums.indexed) ...[
                  if (index > 0) const Divider(height: AppSpacing.lg),
                  _CategoryPodium(podium: podium),
                ],
              ],
            ),
    );
  }
}

class _CategoryPodium extends StatelessWidget {
  const _CategoryPodium({required this.podium});
  final TournamentCategoryPodium podium;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (podium.state) {
      TournamentPodiumState.decided => l10n.tournamentDetailFinal,
      TournamentPodiumState.provisional => l10n.tournamentDetailProvisional,
      TournamentPodiumState.inProgress => l10n.tournamentDetailPodiumInProgress,
      TournamentPodiumState.empty => l10n.tournamentDetailPodiumEmpty,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                podium.category.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(status, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (podium.entries.isEmpty)
          Text(status)
        else
          for (final entry in podium.entries)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _rankColor(entry.rank).withValues(alpha: 0.12),
                border: Border(
                  left: BorderSide(color: _rankColor(entry.rank), width: 4),
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(
                    entry.rank == 1 ? AppIcons.trophy : AppIcons.award,
                    color: _rankColor(entry.rank),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.tournamentDetailRank(entry.rank)}${entry.tied ? ' · ${l10n.tournamentDetailTied}' : ''}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          entry.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (entry.playerNames case final names?
                            when names != entry.label)
                          Text(
                            names,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (entry.detail case final detail?) Text(detail),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static Color _rankColor(int rank) => switch (rank) {
    1 => const Color(0xFFD4A017),
    2 => const Color(0xFF88909A),
    _ => const Color(0xFFB87333),
  };
}

class _VenuesSection extends StatefulWidget {
  const _VenuesSection({
    required this.venues,
    required this.canManage,
    required this.tournament,
  });
  final List<TournamentVenue> venues;
  final bool canManage;
  final TournamentDetail tournament;

  @override
  State<_VenuesSection> createState() => _VenuesSectionState();
}

class _VenuesSectionState extends State<_VenuesSection> {
  late TournamentVenue selected = widget.venues.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.tournamentDetailVenues,
      icon: AppIcons.location,
      trailing: widget.canManage
          ? _EditAction(
              onPressed: () =>
                  _openManage(context, widget.tournament, 'venues'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.venues.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final venue in widget.venues)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(venue.name),
                        selected: selected.id == venue.id,
                        onSelected: (_) => setState(() => selected = venue),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Theme.of(context).extension<AppPalette>()!.muted,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Center(child: Icon(AppIcons.location, size: 38)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selected.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (selected.addressLabel.isNotEmpty) Text(selected.addressLabel),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openDirections(context, selected),
              icon: const Icon(AppIcons.navigation),
              label: Text(l10n.tournamentDetailDirections),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.text,
    required this.canManage,
    required this.tournament,
  });
  final String text;
  final bool canManage;
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: AppLocalizations.of(context).tournamentDetailNotes,
    icon: AppIcons.notes,
    trailing: canManage
        ? _EditAction(onPressed: () => _openManage(context, tournament, 'name'))
        : null,
    child: _LinkedText(text: text),
  );
}

class _LinkedText extends StatelessWidget {
  const _LinkedText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final urlPattern = RegExp(r'https?://[^\s]+');
    final spans = <Widget>[];
    var cursor = 0;
    for (final match in urlPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(Text(text.substring(cursor, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        InkWell(
          onTap: () => _launchExternal(context, Uri.parse(url)),
          child: Text(
            url,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(Text(text.substring(cursor)));
    return Wrap(spacing: 3, runSpacing: 3, children: spans);
  }
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({
    required this.urls,
    required this.canManage,
    required this.tournament,
  });
  final List<String> urls;
  final bool canManage;
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: AppLocalizations.of(context).tournamentDetailVideos,
    icon: AppIcons.playCircle,
    trailing: canManage
        ? _EditAction(
            onPressed: () => _openManage(context, tournament, 'videos'),
          )
        : null,
    child: LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: urls.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: constraints.maxWidth >= 700
              ? 410
              : constraints.maxWidth,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemBuilder: (context, index) => _VideoCard(url: urls[index]),
      ),
    ),
  );
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final video = ReferenceVideo.parse(url);
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: video == null
            ? null
            : () => _launchExternal(context, Uri.parse(video.url)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video is YouTubeVideo)
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            const ColoredBox(color: Color(0x33000000)),
            const Center(
              child: Icon(AppIcons.playCircle, size: 52, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorsSection extends StatelessWidget {
  const _SponsorsSection({
    required this.sponsors,
    required this.canManage,
    required this.tournament,
  });
  final List<TournamentSponsor> sponsors;
  final bool canManage;
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: AppLocalizations.of(context).tournamentDetailSponsors,
    icon: AppIcons.award,
    trailing: canManage
        ? _EditAction(
            onPressed: () => _openManage(context, tournament, 'sponsors'),
          )
        : null,
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final sponsor in sponsors) _SponsorTile(sponsor: sponsor),
      ],
    ),
  );
}

class _SponsorTile extends StatelessWidget {
  const _SponsorTile({required this.sponsor});
  final TournamentSponsor sponsor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: sponsor.name,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSponsor(context, sponsor),
        child: SizedBox(
          width: 88,
          height: 88,
          child: sponsor.logo == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      sponsor.name,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: CachedNetworkImage(
                    imageUrl: sponsor.logo!,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.tournament, required this.canManage});
  final TournamentDetail tournament;
  final bool canManage;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: AppLocalizations.of(context).tournamentDetailContact,
    icon: AppIcons.user,
    trailing: canManage
        ? _EditAction(
            onPressed: () => _openManage(context, tournament, 'contact'),
          )
        : null,
    child: Column(
      children: [
        if (tournament.resolvedContactName case final name?)
          _ContactRow(icon: AppIcons.user, text: name),
        if (tournament.resolvedContactEmail case final email?)
          _ContactRow(
            icon: Icons.mail_outline,
            text: email,
            onTap: () =>
                _launchExternal(context, Uri(scheme: 'mailto', path: email)),
          ),
        if (tournament.contactPhone case final phone?)
          _ContactRow(
            icon: AppIcons.phone,
            text: phone,
            onTap: () =>
                _launchExternal(context, Uri(scheme: 'tel', path: phone)),
          ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: AppSizes.minTapTarget,
    leading: Icon(icon),
    title: Text(text),
    onTap: onTap,
  );
}

class _OrganizerCompletion extends StatelessWidget {
  const _OrganizerCompletion({required this.tournament, required this.items});
  final TournamentDetail tournament;
  final List<({String label, String option})> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tournamentDetailOrganizerTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.tournamentDetailOrganizerDescription),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in items)
                  ActionChip(
                    avatar: const Icon(AppIcons.edit, size: 16),
                    label: Text(item.label),
                    onPressed: () =>
                        _openManage(context, tournament, item.option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrSection extends StatelessWidget {
  const _QrSection({required this.tournament});
  final TournamentDetail tournament;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = _publicUrl(context, tournament);
    return _SectionCard(
      title: l10n.tournamentDetailAccessQr,
      icon: Icons.qr_code_2,
      child: Row(
        children: [
          QrImageView(data: url, size: 112, backgroundColor: Colors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(url, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => _shareTournament(context, tournament),
                  icon: const Icon(AppIcons.share),
                  label: Text(l10n.commonShare),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
    this.icon,
    this.trailing,
  });
  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    ),
  );
}

class _EditAction extends StatelessWidget {
  const _EditAction({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).commonEdit,
    onPressed: onPressed,
    icon: const Icon(AppIcons.edit, size: 18),
  );
}

Future<void> _showSponsor(BuildContext context, TournamentSponsor sponsor) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sponsor.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              if (sponsor.logo != null)
                SizedBox(
                  height: 170,
                  child: CachedNetworkImage(
                    imageUrl: sponsor.logo!,
                    fit: BoxFit.contain,
                  ),
                ),
              if (sponsor.website != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () =>
                      _launchExternal(context, Uri.parse(sponsor.website!)),
                  icon: const Icon(AppIcons.externalLink),
                  label: Text(
                    AppLocalizations.of(context).tournamentDetailOpenWebsite,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

Future<void> _openDirections(BuildContext context, TournamentVenue venue) {
  final query = [
    venue.name,
    venue.addressLabel,
  ].where((value) => value.isNotEmpty).join(' ');
  final uri = venue.placeId != null
      ? Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query_place_id': venue.placeId,
          'query': query,
        })
      : venue.lat != null && venue.lng != null
      ? Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '${venue.lat},${venue.lng}',
        })
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': query,
        });
  return _launchExternal(context, uri);
}

Future<void> _openTournamentWeb(
  BuildContext context,
  TournamentDetail tournament,
  String segment,
) => _launchExternal(
  context,
  Uri.parse('${_publicUrl(context, tournament)}/$segment'),
);

Future<void> _openManage(
  BuildContext context,
  TournamentDetail tournament,
  String option,
) {
  final uri = Uri.parse(
    '${_publicUrl(context, tournament)}/manage',
  ).replace(queryParameters: {'option': option});
  return _launchExternal(context, uri);
}

String _publicUrl(BuildContext context, TournamentDetail tournament) {
  final language = Localizations.localeOf(context).languageCode;
  final locale = language == 'zh' ? 'cn' : language;
  return '${AppConfig.webBaseUrl}/$locale/tournament/${tournament.slug}';
}

Future<void> _shareTournament(
  BuildContext context,
  TournamentDetail tournament,
) async {
  final box = context.findRenderObject();
  await SharePlus.instance.share(
    ShareParams(
      title: tournament.name,
      subject: AppLocalizations.of(context).tournamentDetailShareSubject,
      text: '${tournament.name}\n${_publicUrl(context, tournament)}',
      sharePositionOrigin: box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    ),
  );
}

Future<void> _launchExternal(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).tournamentDetailExternalError,
        ),
      ),
    );
  }
}
