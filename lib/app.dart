import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/core/router/app_router.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';
import 'package:vmito_app/core/widgets/app_edge_back_gesture.dart';
import 'package:vmito_app/core/widgets/app_error_listener.dart';
import 'package:vmito_app/core/widgets/app_lock_gate.dart';
import 'package:vmito_app/core/widgets/court_call_listener.dart';
import 'package:vmito_app/core/widgets/newsfeed_badge_lifecycle.dart';
import 'package:vmito_app/core/widgets/push_notification_lifecycle.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The root widget. Wiring only — no business logic belongs here.
class VmitoApp extends ConsumerWidget {
  const VmitoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'Vmito',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Sits above every route so unhandled API errors surface anywhere.
      builder: (context, child) => AppLockGate(
        child: AppEdgeBackGesture(
          onBack: () => _handleEdgeBack(router),
          child: PushNotificationLifecycle(
            router: router,
            child: NewsfeedBadgeLifecycle(
              router: router,
              child: CourtCallListener(
                child: AppErrorListener(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleEdgeBack(GoRouter router) {
    final rootNavigator = rootNavigatorKey.currentState;
    if (rootNavigator?.canPop() ?? false) {
      unawaited(
        rootNavigator!.maybePop().then((didPop) {
          if (!didPop && router.canPop()) router.pop();
        }),
      );
      return;
    }

    if (router.canPop()) router.pop();
  }
}
