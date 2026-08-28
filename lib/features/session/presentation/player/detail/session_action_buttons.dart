import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// What the bottom bar offers, given who is looking and where they stand.
///
/// Ports `renderActionButton` in
/// `vmito-fe/src/components/session/SessionDetailStickyBar.tsx`. The branch
/// order is load-bearing and matches web exactly: an earlier branch wins, so
/// a host looking at their own finished session still gets "Host" rather than
/// the disabled "Session ended".
class SessionActionButtons extends StatelessWidget {
  const SessionActionButtons({
    required this.session,
    required this.canManage,
    required this.registrationStatus,
    required this.onManage,
    required this.onOpenBoard,
    required this.onRegister,
    required this.onViewRegistration,
    required this.onAddGuest,
    super.key,
  });

  final Session session;

  /// Host of this session, or an admin.
  final bool canManage;

  /// Null when the viewer has not registered — including when signed out.
  final RegistrationStatus? registrationStatus;

  final VoidCallback onManage;
  final VoidCallback onOpenBoard;
  final VoidCallback onRegister;
  final VoidCallback onViewRegistration;
  final VoidCallback onAddGuest;

  /// A session nobody can join any more: the host ended or cancelled it, or
  /// its scheduled window has passed.
  bool get _isClosed {
    if (session.status == SessionStatus.finished ||
        session.status == SessionStatus.cancelled) {
      return true;
    }
    final end = session.endTime;
    return end != null && end.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 1. Crawled posts have no roster and no host account — the only useful
    //    action is opening the original, and this beats every other branch.
    if (session.isCrawled) {
      final url = session.externalUrl;
      return _ActionRow(
        children: [
          Flexible(
            child: _Primary(
              label: l10n.sessionViewOriginalPost,
              icon: AppIcons.facebook,
              backgroundColor: const Color(0xFF1877F2),
              onPressed: url == null || url.isEmpty
                  ? null
                  : () => unawaited(
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    // 2. The host's own session: manage it, never register for it.
    if (canManage) {
      return _ActionRow(
        children: [
          Flexible(
            child: _Primary(
              label: l10n.sessionManageAction,
              icon: AppIcons.settings,
              onPressed: onManage,
            ),
          ),
        ],
      );
    }

    // 3. Closed. Disabled rather than hidden, so the reason is visible.
    if (_isClosed) {
      return _ActionRow(
        children: [
          Flexible(
            child: _Primary(
              label: l10n.sessionEnded,
              icon: AppIcons.calendarX,
              onPressed: null,
            ),
          ),
        ],
      );
    }

    // 4. Approved: the player is in. Court board first, ticket and add-guest
    //    beside it.
    if (registrationStatus == RegistrationStatus.approved) {
      return _ActionRow(
        children: [
          Flexible(
            child: _Primary(
              label: l10n.sessionViewBoard,
              icon: AppIcons.court,
              onPressed: onOpenBoard,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Secondary(
            tooltip: l10n.sessionViewMyRegistration,
            icon: AppIcons.ticket,
            onPressed: onViewRegistration,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Secondary(
            tooltip: l10n.sessionAddGuest,
            icon: AppIcons.userPlus,
            onPressed: session.isFull ? null : onAddGuest,
          ),
        ],
      );
    }

    // 5. Pending and rejected share a branch, as on web: both mean "you have
    //    a ticket, go look at it".
    if (registrationStatus != null) {
      return _ActionRow(
        children: [
          Flexible(
            child: _Primary(
              label: l10n.sessionViewMyRegistration,
              icon: AppIcons.ticket,
              onPressed: onViewRegistration,
              tonal: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Secondary(
            tooltip: l10n.sessionAddGuest,
            icon: AppIcons.userPlus,
            onPressed: session.isFull ? null : onAddGuest,
          ),
        ],
      );
    }

    // 6. Never registered — including signed out, which the tap handler
    //    turns into a sign-in prompt.
    return _ActionRow(
      children: [
        Flexible(
          child: _Primary(
            label: session.isFull
                ? l10n.sessionSlotsFull
                : l10n.sessionRegisterAction,
            icon: AppIcons.userPlus,
            onPressed: session.isFull ? null : onRegister,
          ),
        ),
      ],
    );
  }
}

/// The shape every branch returns: a full-width row whose buttons hug the
/// right edge.
///
/// Full width rather than [MainAxisSize.min] because a min-size row
/// under-allocates to its `Flexible` child, so a long label overflows instead
/// of ellipsizing. The primary button is always wrapped in a `Flexible` by the
/// caller, which is what lets it give way when three buttons and a price share
/// a phone-width bar.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
}

class _Primary extends StatelessWidget {
  const _Primary({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tonal = false,
    this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tonal;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // The theme stretches filled buttons to full width, which would push the
    // price out of the bar's row.
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, AppSizes.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      backgroundColor: backgroundColor,
      foregroundColor: backgroundColor == null ? null : Colors.white,
    );
    // Ellipsize rather than overflow: three buttons plus a price is already
    // tight at phone width, and a longer translation or a large text scale
    // would otherwise push the row past the edge. No Flexible here — the
    // button already wraps its label in one, and a second competes for the
    // same parent data.
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    return tonal
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: text,
            style: style,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: text,
            style: style,
          );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    icon: Icon(icon, size: 20),
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(AppSizes.minTapTarget),
    ),
  );
}
