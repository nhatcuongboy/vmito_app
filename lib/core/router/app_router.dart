import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/features/home/presentation/home_screen.dart';
import 'package:vmito_app/features/splash/presentation/splash_screen.dart';

/// The app's [GoRouter], rebuilt whenever auth status changes.
///
/// `redirect` is the single gate: no screen checks auth for itself.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = AppRoutes.stripLocale(state.matchedLocation);

      // Tokens are still being read from the Keychain. Hold on the splash
      // screen rather than bouncing a signed-in user to sign-in.
      if (!auth.isResolved) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (auth.isSignedIn) {
        // Signed in but sitting on splash or an auth screen — move on.
        if (location == AppRoutes.splash || location.startsWith('/auth/')) {
          return AppRoutes.home;
        }
        return null;
      }

      if (AppRoutes.isPublic(location) && location != AppRoutes.splash) {
        return null;
      }

      return AppRoutes.signIn;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.nameSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRoutes.nameSignIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.nameHome,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
