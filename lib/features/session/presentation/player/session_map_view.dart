import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_permission_feedback.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_map_location.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class SessionMapView extends ConsumerStatefulWidget {
  const SessionMapView({required this.locations, super.key});

  final List<SessionMapLocation> locations;

  @override
  ConsumerState<SessionMapView> createState() => _SessionMapViewState();
}

class _SessionMapViewState extends ConsumerState<SessionMapView> {
  GoogleMapController? _mapController;
  bool _isLocating = false;
  bool _hasLocationPermission = false;

  @override
  void didUpdateWidget(SessionMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_locationSignature(oldWidget.locations) !=
        _locationSignature(widget.locations)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fitLocations());
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations;
    if (locations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.mapPin, size: 44),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context).sessionMapNoLocations,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            key: const Key('session-google-map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(
                locations.first.latitude,
                locations.first.longitude,
              ),
              zoom: locations.length == 1 ? 14 : 11,
            ),
            markers: {
              for (final location in locations)
                Marker(
                  markerId: MarkerId(location.key),
                  position: LatLng(location.latitude, location.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  onTap: () => _showLocation(location),
                ),
            },
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: _hasLocationPermission,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(_fitLocations());
            },
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: 76,
          child: FloatingActionButton.small(
            key: const Key('session-map-my-location'),
            heroTag: 'session-map-my-location',
            tooltip: AppLocalizations.of(context).sessionMapMyLocation,
            onPressed: _isLocating ? null : _goToCurrentLocation,
            child: _isLocating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.myLocation),
          ),
        ),
      ],
    );
  }

  Future<void> _fitLocations() async {
    final controller = _mapController;
    final locations = widget.locations;
    if (controller == null || locations.isEmpty) return;
    if (locations.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(locations.first.latitude, locations.first.longitude),
          14,
        ),
      );
      return;
    }

    var minLat = locations.first.latitude;
    var maxLat = minLat;
    var minLng = locations.first.longitude;
    var maxLng = minLng;
    for (final location in locations.skip(1)) {
      minLat = location.latitude < minLat ? location.latitude : minLat;
      maxLat = location.latitude > maxLat ? location.latitude : maxLat;
      minLng = location.longitude < minLng ? location.longitude : minLng;
      maxLng = location.longitude > maxLng ? location.longitude : maxLng;
    }
    if (minLat == maxLat && minLng == maxLng) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await ref.read(deviceLocationServiceProvider).call();
      if (!mounted) return;
      setState(() => _hasLocationPermission = true);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } on LocationPermissionException {
      if (mounted) {
        showLocationPermissionDeniedSnackBar(
          context,
          message: AppLocalizations.of(context).sessionMapLocationUnavailable,
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).sessionMapLocationUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _showLocation(SessionMapLocation location) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.7,
          child: _SessionLocationSheet(location: location),
        ),
      );
}

class _SessionLocationSheet extends StatelessWidget {
  const _SessionLocationSheet({required this.location});

  final SessionMapLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: location.sessions.length > 2
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(location.name, style: theme.textTheme.titleLarge),
            if (location.address?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                location.address!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: location.sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _SessionMapTile(
                  session: location.sessions[index],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openDirections(location),
              icon: const Icon(AppIcons.navigation),
              label: Text(l10n.sessionGetDirections),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openDirections(SessionMapLocation location) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${location.latitude},${location.longitude}',
    }),
    mode: LaunchMode.externalApplication,
  );
}

class _SessionMapTile extends StatelessWidget {
  const _SessionMapTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localStart = session.startTime?.toLocal();
    final capacity = session.numberOfCourts * session.maxPlayersPerCourt;
    final availableSlots = capacity - session.playerCount;
    final slotLabel = availableSlots > 0
        ? l10n.sessionSlotsLeft(availableSlots)
        : l10n.sessionSlotsFull;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        session.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: localStart == null
          ? null
          : Text(
              '${MaterialLocalizations.of(context).formatShortDate(localStart)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(localStart))} · '
              '$slotLabel',
            ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () {
        Navigator.of(context).pop();
        unawaited(context.push(AppRoutes.sessionDetail(session.id)));
      },
    );
  }
}

String _locationSignature(List<SessionMapLocation> locations) => locations
    .map(
      (location) =>
          '${location.key}:${location.latitude}:${location.longitude}',
    )
    .join('|');
