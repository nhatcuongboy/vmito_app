import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vmito_app/core/utils/app_settings_launcher.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Shows the "location denied" SnackBar with an "Open Settings" action.
///
/// The OS won't re-show its own permission dialog once a user has denied
/// location access (permanently on iOS), so this is the retry path: the user
/// hits it again from whichever feature needed the location, not from a
/// dedicated permissions screen. Pass [message] to reuse a screen's existing
/// denial copy instead of the generic one.
void showLocationPermissionDeniedSnackBar(
  BuildContext context, {
  String? message,
}) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message ?? l10n.venueFilterLocationDenied),
        action: SnackBarAction(
          label: l10n.locationPermissionOpenSettings,
          onPressed: () => unawaited(openDeviceAppSettings()),
        ),
      ),
    );
}
