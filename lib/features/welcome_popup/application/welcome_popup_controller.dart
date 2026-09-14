import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/welcome_popup/data/welcome_popup_preferences.dart';
import 'package:vmito_app/features/welcome_popup/data/welcome_popup_service.dart';
import 'package:vmito_app/features/welcome_popup/domain/welcome_popup.dart';

class WelcomePopupState {
  const WelcomePopupState({this.popup});

  final WelcomePopup? popup;
  bool get isVisible => popup != null;
}

/// Fetches the active welcome popup and decides whether it should show, one
/// version at a time — mirrors `vmito-fe`'s `useWelcomePopupStore`.
class WelcomePopupController extends Notifier<WelcomePopupState> {
  @override
  WelcomePopupState build() => const WelcomePopupState();

  Future<void> evaluate() async {
    try {
      final popup = await ref.read(welcomePopupServiceProvider).fetchActive();
      if (popup == null) return;

      final preferences = ref.read(welcomePopupPreferencesProvider);
      final dismissed = await preferences.readDismissedToken();
      if (dismissed == popup.versionToken) return;

      state = WelcomePopupState(popup: popup);
    } on Object catch (error) {
      // A broken fetch/prefs read must never block or crash startup.
      AppLogger.warn('welcome popup evaluation failed', error: error);
    }
  }

  Future<void> dismiss() async {
    final popup = state.popup;
    if (popup == null) return;
    state = const WelcomePopupState();
    try {
      await ref
          .read(welcomePopupPreferencesProvider)
          .writeDismissedToken(popup.versionToken);
    } on Object catch (error) {
      AppLogger.warn('welcome popup dismissal not persisted', error: error);
    }
  }
}

final welcomePopupControllerProvider =
    NotifierProvider<WelcomePopupController, WelcomePopupState>(
      WelcomePopupController.new,
    );
