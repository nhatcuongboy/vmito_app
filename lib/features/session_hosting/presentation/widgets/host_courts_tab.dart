import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court_display_mode_switch.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_waiting_players.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The host's court board.
///
/// Refreshes on a timer while it is on screen. The web polls
/// `GET /sessions/:id` every 60 s here; sockets already push most changes, but
/// wait times only advance server-side, so without a poll the queue order goes
/// stale on a quiet court.
///
/// Deliberately **not** ported: the web's `PUT /sessions/:id/wait-times`
/// heartbeat. It is a blind increment with no idempotency key, mounted by both
/// the host and player pages, so a phone alongside a laptop would double-count
/// every minute — and iOS suspending the timer would make our share lumpy.
class HostCourtsTab extends ConsumerStatefulWidget {
  const HostCourtsTab({required this.session, super.key});

  final Session session;

  @override
  ConsumerState<HostCourtsTab> createState() => _HostCourtsTabState();
}

class _HostCourtsTabState extends ConsumerState<HostCourtsTab> {
  Timer? _poll;

  static const _pollInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _syncPoll();
  }

  @override
  void didUpdateWidget(HostCourtsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPoll();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Polls only while the session is live — a finished board never changes.
  void _syncPoll() {
    final shouldPoll = widget.session.status.isLive;
    if (shouldPoll == (_poll != null)) return;
    _poll?.cancel();
    _poll = shouldPoll
        ? Timer.periodic(
            _pollInterval,
            (_) => ref.invalidate(sessionDetailProvider(widget.session.id)),
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.session;

    if (session.courts.isEmpty) {
      return Center(child: Text(l10n.liveNoCourts));
    }

    final courts = session.orderedCourts;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionDetailProvider(session.id).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        // Display toggle, every court, then the waiting queue.
        itemCount: courts.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CourtDisplayModeSwitch(),
              ],
            );
          }
          if (index == courts.length + 1) {
            return HostWaitingPlayers(session: session);
          }
          return HostCourtCard(session: session, court: courts[index - 1]);
        },
      ),
    );
  }
}
