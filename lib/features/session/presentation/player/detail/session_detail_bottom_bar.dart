import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/registration/presentation/my_registration_sheet.dart';
import 'package:vmito_app/features/registration/presentation/register_session_sheet.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_action_buttons.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_fee_detail_dialog.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';

/// Price on the left, the action that fits the viewer on the right.
///
/// Ports the mobile variant of the web app's `SessionDetailStickyBar`. The
/// branch tree itself lives in [SessionActionButtons]; this widget owns the
/// bar chrome and turns each action into navigation or a sheet.
class SessionDetailBottomBar extends ConsumerWidget {
  const SessionDetailBottomBar({
    required this.session,
    required this.onManage,
    required this.onOpenLive,
    super.key,
  });

  final Session session;
  final VoidCallback onManage;
  final VoidCallback onOpenLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final user = ref.watch(currentUserProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    final canManage =
        (session.host?.id != null && session.host!.id == user?.id) ||
        (user?.isAdmin ?? false);

    // When the host adds a player directly (bypassing the self-registration
    // flow), the `/players/me` endpoint may return an empty list if the row
    // was created without a `createdByUserId` (single-add path on the backend).
    // In that case, fall back to scanning `session.players`, which the detail
    // endpoint already includes, and derive the status from the player's own
    // `registrationStatus` field. This prevents the "Đăng ký" button from
    // appearing for a user who is already in the session.
    final hostAddedStatus = isSignedIn && user != null
        ? session.players
              .where((p) => p.userId == user.id)
              .firstOrNull
              ?.registrationStatus
        : null;

    final price = sessionPriceLabel(session, locale);
    // A split fee has useful information even before the host enters the
    // final per-player amount. Showing just the info button looked like a
    // missing price rather than an intentional payment arrangement.
    final feeLabel = session.feeConfig?.isSplitEvenly == true
        ? l10n.sessionRecommendationSplitEvenly
        : price;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            // The price takes only what it needs while the actions box takes a
            // flex share, so the row rarely fills: without spaceBetween the
            // slack lands after the last child and the buttons float short of
            // the right edge.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            children: [
              if (feeLabel != null || session.feeConfig != null)
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (feeLabel != null)
                        Flexible(
                          // The action group deliberately receives more of
                          // the row on compact phones. Scale the complete fee
                          // down within its share rather than ellipsizing or
                          // wrapping the unit (for example "/slot").
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                text: feeLabel,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        session.feeConfig?.feeType ==
                                            FeeType.splitEvenly
                                        ? ''
                                        : ' ${l10n.sessionPerSlot}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      if (session.feeConfig case final feeConfig?)
                        IconButton(
                          key: const Key('session-fee-details'),
                          tooltip: l10n.feeTitle,
                          icon: const Icon(AppIcons.info, size: 18),
                          color: theme.colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => showSessionFeeDetailDialog(
                            context,
                            feeConfig: feeConfig,
                          ),
                        ),
                    ],
                  ),
                ),
              // Expanded with a larger flex than the price: 3 action items
              // (label + two icon buttons) need more room than a one-line
              // price, so an even 1:1 split starved the label to invisible.
              Expanded(
                flex: 3,
                // Not wrapped in an Align: Align takes the largest height its
                // constraints allow, which inside a bar with no height of its
                // own is the whole screen. The buttons right-align themselves.
                child: SessionActionButtons(
                  session: session,
                  canManage: canManage,
                  // Signed out there is no ticket to read, and the provider
                  // short-circuits rather than calling an endpoint that
                  // would certainly 401.
                  // Fall back to `hostAddedStatus` when the provider returns
                  // null: the host may have added this user directly without
                  // going through the self-registration flow, so the
                  // `/players/me` list is empty even though the user already
                  // has a slot.
                  registrationStatus: isSignedIn
                      ? (ref.watch(myRegistrationStatusProvider(session.id)) ??
                            hostAddedStatus)
                      : null,
                  onManage: onManage,
                  onOpenBoard: onOpenLive,
                  onRegister: () => _register(context, isSignedIn: isSignedIn),
                  onViewRegistration: () => unawaited(
                    showMyRegistrationSheet(context, sessionId: session.id),
                  ),
                  onAddGuest: () => _register(
                    context,
                    isSignedIn: isSignedIn,
                    asGuest: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _register(
    BuildContext context, {
    required bool isSignedIn,
    bool asGuest = false,
  }) {
    if (!isSignedIn) {
      unawaited(showLoginPromptDialog(context));
      return;
    }
    unawaited(
      showRegisterSessionSheet(context, session: session, asGuest: asGuest),
    );
  }
}
