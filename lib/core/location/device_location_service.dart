import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class DeviceCoordinates {
  const DeviceCoordinates({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

typedef DeviceLocationLoader = Future<DeviceCoordinates> Function();

Future<DeviceCoordinates> loadDeviceLocation() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationPermissionException();
  }
  final position = await Geolocator.getCurrentPosition();
  return DeviceCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

class LocationPermissionException implements Exception {
  const LocationPermissionException();
}

final deviceLocationServiceProvider = Provider<DeviceLocationLoader>(
  (ref) => loadDeviceLocation,
);
