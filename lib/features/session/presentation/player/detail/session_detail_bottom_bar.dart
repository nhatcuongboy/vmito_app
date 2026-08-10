import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/registration/presentation/my_registration_sheet.dart';
import 'package:vmito_app/features/registration/presentation/register_session_sheet.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_action_buttons.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

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
    required this.onSignInRequired,
    super.key,
  });

  final Session session;
  final VoidCallback onManage;
  final VoidCallback onOpenLive;

  /// Registration is per-account, so a signed-out tap has to become a
  /// sign-in prompt rather than an empty form.
  final VoidCallback onSignInRequired;

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

    final price = sessionPriceLabel(session, locale);

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
              if (price != null)
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: price,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: l10n.sessionPerSlot,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Expanded, not Spacer: the actions must be the side that gives
              // way when the row is tight, so the price stays readable and the
              // button labels ellipsize instead of overflowing.
              Expanded(
                // Not wrapped in an Align: Align takes the largest height its
                // constraints allow, which inside a bar with no height of its
                // own is the whole screen. The buttons right-align themselves.
                child: SessionActionButtons(
                  session: session,
                  canManage: canManage,
                  // Signed out there is no ticket to read, and the provider
                  // short-circuits rather than calling an endpoint that
                  // would certainly 401.
                  registrationStatus: isSignedIn
                      ? ref.watch(myRegistrationStatusProvider(session.id))
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
      onSignInRequired();
      return;
    }
    unawaited(
      showRegisterSessionSheet(context, session: session, asGuest: asGuest),
    );
  }
}
