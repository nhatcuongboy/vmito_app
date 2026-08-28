import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:vmito_app/core/location/device_location_service.dart';

class DevicePlacemark {
  const DevicePlacemark(this.parts);

  final List<String?> parts;
}

typedef DeviceReverseGeocoder =
    Future<DevicePlacemark> Function(DeviceCoordinates coordinates);

Future<DevicePlacemark> reverseGeocodeDeviceLocation(
  DeviceCoordinates coordinates,
) async {
  final geocoding = Geocoding();
  final placemarks = await geocoding.placemarkFromCoordinates(
    coordinates.latitude,
    coordinates.longitude,
  );
  if (placemarks.isEmpty) throw const DeviceGeocodingException();
  final placemark = placemarks.first;
  return DevicePlacemark([
    placemark.administrativeArea,
    placemark.subAdministrativeArea,
    placemark.locality,
    placemark.subLocality,
    placemark.name,
    placemark.street,
  ]);
}

class DeviceGeocodingException implements Exception {
  const DeviceGeocodingException();
}

final deviceReverseGeocoderProvider = Provider<DeviceReverseGeocoder>(
  (ref) => reverseGeocodeDeviceLocation,
);
