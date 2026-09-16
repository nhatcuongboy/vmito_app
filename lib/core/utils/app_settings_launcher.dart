import 'package:geolocator/geolocator.dart';

/// Opens this app's page in the OS Settings app. `geolocator` already ships a
/// generic "open app settings" platform channel (used for its own permission
/// flow) — reused here so we don't pull in a second plugin just to deep-link
/// to Settings for a permission the OS itself won't re-prompt for.
Future<bool> openDeviceAppSettings() => Geolocator.openAppSettings();
