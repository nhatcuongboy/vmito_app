import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals that the first-run city-onboarding step (shown once from Home) has
/// been shown and dismissed, so lower-priority first-run UI — the marketing
/// popup, the push-permission prompt — can proceed without stacking on top of
/// it. Resolves immediately once onboarding was already completed on a prior
/// run, since [complete] is called unconditionally after the check.
class FirstRunGate {
  final _completer = Completer<void>();

  Future<void> get resolved => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

final firstRunGateProvider = Provider<FirstRunGate>((ref) => FirstRunGate());
