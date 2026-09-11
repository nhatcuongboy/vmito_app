import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// What the host list shows for a tournament: the server status, except that
/// an IN_PROGRESS tournament past its end day reads as overdue.
///
/// Colours are the web `STATUS_THEME` (Chakra `subtle` badges) rather than
/// theme tokens, because the stripe gradients have no token equivalent.
enum HostTournamentDisplayStatus {
  preparing(
    background: Color(0xFFF4F4F5),
    foreground: Color(0xFF3F3F46),
    dot: Color(0xFFA1A1AA),
    gradient: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
  ),
  inProgress(
    background: Color(0xFFC6F0D3),
    foreground: Color(0xFF0E5C23),
    dot: Color(0xFF179A3B),
    gradient: [Color(0xFF34D399), Color(0xFF059669)],
  ),
  finished(
    background: Color(0xFFDBEAFE),
    foreground: Color(0xFF1D4ED8),
    dot: Color(0xFF3B82F6),
    gradient: [Color(0xFF60A5FA), Color(0xFF2563EB)],
  ),
  cancelled(
    background: Color(0xFFFEE2E2),
    foreground: Color(0xFFB91C1C),
    dot: Color(0xFFEF4444),
    gradient: [Color(0xFFFCA5A5), Color(0xFFDC2626)],
  ),
  overdue(
    background: Color(0xFFFFEDD5),
    foreground: Color(0xFFC2410C),
    dot: Color(0xFFF97316),
    gradient: [Color(0xFFFDBA74), Color(0xFFEA580C)],
  );

  const HostTournamentDisplayStatus({
    required this.background,
    required this.foreground,
    required this.dot,
    required this.gradient,
  });

  static HostTournamentDisplayStatus of(
    TournamentSummary tournament, {
    DateTime? now,
  }) {
    if (tournament.isOverdue(now: now)) return overdue;
    return switch (tournament.status) {
      TournamentStatus.preparing => preparing,
      TournamentStatus.inProgress => inProgress,
      TournamentStatus.finished => finished,
      TournamentStatus.cancelled => cancelled,
    };
  }

  final Color background;
  final Color foreground;
  final Color dot;
  final List<Color> gradient;

  LinearGradient get linearGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradient,
  );

  String label(AppLocalizations l10n) => switch (this) {
    preparing => l10n.tournamentStatusPreparing,
    inProgress => l10n.tournamentStatusInProgress,
    finished => l10n.tournamentStatusFinished,
    cancelled => l10n.tournamentStatusCancelled,
    overdue => l10n.hostTournamentsStatusExpired,
  };
}

class HostTournamentStatusBadge extends StatelessWidget {
  const HostTournamentStatusBadge({required this.status, super.key});

  final HostTournamentDisplayStatus status;

  @override
  Widget build(BuildContext context) => _Pill(
    background: status.background,
    foreground: status.foreground,
    leading: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: status.dot, shape: BoxShape.circle),
    ),
    label: status.label(AppLocalizations.of(context)),
  );
}

/// Shown next to the status badge while the tournament is unpublished.
class HostTournamentDraftBadge extends StatelessWidget {
  const HostTournamentDraftBadge({super.key});

  @override
  Widget build(BuildContext context) => _Pill(
    foreground: const Color(0xFFC2410C),
    border: const Color(0xFFFDBA74),
    label: AppLocalizations.of(context).tournamentManagePrivate,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.foreground,
    required this.label,
    this.background = Colors.transparent,
    this.border,
    this.leading,
  });

  final Color foreground;
  final Color background;
  final Color? border;
  final Widget? leading;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
