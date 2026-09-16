import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/router/app_router.dart' show rootNavigatorKey;
import 'package:vmito_app/core/widgets/first_run_gate.dart';
import 'package:vmito_app/core/widgets/welcome_popup_dialog.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/welcome_popup/application/welcome_popup_controller.dart';

/// Evaluates and shows the welcome popup once per app open.
///
/// Lives in `MaterialApp.router`'s `builder`, which sits *above* the app's
/// `Router`/`Navigator` in the element tree — this widget's own
/// [BuildContext] has no `Navigator` ancestor, so showing the dialog goes
/// through [rootNavigatorKey]'s context instead (same gotcha documented on
/// `CourtCallListener`).
class WelcomePopupLifecycle extends ConsumerStatefulWidget {
  const WelcomePopupLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WelcomePopupLifecycle> createState() =>
      _WelcomePopupLifecycleState();
}

class _WelcomePopupLifecycleState extends ConsumerState<WelcomePopupLifecycle> {
  ProviderSubscription<AuthState>? _authSubscription;
  ProviderSubscription<WelcomePopupState>? _popupSubscription;
  bool _evaluated = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Auth resolves before the popup should show, so it never pops over the
    // splash screen or the biometric lock gate. It also waits for the city
    // onboarding sheet to resolve, so the two first-run prompts never stack.
    _authSubscription = ref.listenManual<AuthState>(
      authControllerProvider,
      (_, next) {
        if (_evaluated || next.status == AuthStatus.unknown) return;
        _evaluated = true;
        unawaited(_evaluatePopup());
      },
      fireImmediately: true,
    );
    _popupSubscription = ref.listenManual<WelcomePopupState>(
      welcomePopupControllerProvider,
      (_, next) {
        if (next.isVisible) unawaited(_showDialog(next));
      },
    );
  }

  Future<void> _evaluatePopup() async {
    await ref.read(firstRunGateProvider).resolved;
    if (!mounted) return;
    await ref.read(welcomePopupControllerProvider.notifier).evaluate();
  }

  Future<void> _showDialog(WelcomePopupState state) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      // A socket/auth event can land mid-frame; wait for it to settle before
      // pushing a dialog route, same reasoning as `CourtCallListener`.
      await SchedulerBinding.instance.endOfFrame;
      final dialogContext = rootNavigatorKey.currentContext;
      if (!mounted || dialogContext == null || !dialogContext.mounted) return;
      await WelcomePopupDialog.show(dialogContext, popup: state.popup!);
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _popupSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
