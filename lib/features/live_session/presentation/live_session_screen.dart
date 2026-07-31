import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/live_session/application/live_session_controller.dart';
import 'package:vmito_app/features/live_session/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
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
      ref.invalidate(sessionDetailProvider(widget.sessionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveSessionRealtimeProvider(widget.sessionId));
    final connected = ref.watch(socketConnectionProvider).value ?? false;
    final session = ref.watch(sessionDetailProvider(widget.sessionId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveCourtTitle)),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: connected
                ? const SizedBox.shrink()
                : Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(l10n.liveReconnecting)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: session.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                error: error,
                onRetry: () => ref.invalidate(
                  sessionDetailProvider(widget.sessionId),
                ),
              ),
              data: (value) => RefreshIndicator(
                onRefresh: () async => ref.refresh(
                  sessionDetailProvider(widget.sessionId).future,
                ),
                child: _CourtBoard(session: value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtBoard extends StatelessWidget {
  const _CourtBoard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final courts = session.orderedCourts;
    if (courts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .55,
            child: Center(child: Text(l10n.liveNoCourts)),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final width =
            (constraints.maxWidth -
                AppSpacing.screenPadding * 2 -
                AppSpacing.md * (columns - 1)) /
            columns;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text(session.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final court in courts)
                  SizedBox(
                    width: width,
                    child: _CourtCard(court: court),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final players = court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : court.preSelectedPlayers;
    final status = switch (court.status) {
      CourtStatus.inUse => l10n.courtStatusInUse,
      CourtStatus.ready => l10n.courtStatusReady,
      CourtStatus.empty => l10n.courtStatusEmpty,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.courtName(court),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(status, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BadmintonCourtView(court: court),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.livePlayerCount(players.length)),
          ],
        ),
      ),
    );
  }
}
