import 'package:flutter/material.dart';

/// The app's default full-view loading state: a centered spinner.
///
/// Use whenever a screen or tab has nothing more specific to show while its
/// data loads. Prefer this over inlining `Center(child:
/// CircularProgressIndicator())` so the loading look stays consistent and is
/// easy to change in one place.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(),
  );
}
