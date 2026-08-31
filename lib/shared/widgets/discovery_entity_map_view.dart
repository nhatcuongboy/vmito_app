import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A marker and its destination detail action for a discovery map.
class DiscoveryMapItem {
  const DiscoveryMapItem({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.onOpenDetail,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;
  final VoidCallback onOpenDetail;
}

/// Shared Google Map implementation for venue, club and tournament discovery.
class DiscoveryEntityMapView extends ConsumerStatefulWidget {
  const DiscoveryEntityMapView({
    required this.items,
    required this.emptyMessage,
    super.key,
  });

  final List<DiscoveryMapItem> items;
  final String emptyMessage;

  @override
  ConsumerState<DiscoveryEntityMapView> createState() =>
      _DiscoveryEntityMapViewState();
}

class _DiscoveryEntityMapViewState
    extends ConsumerState<DiscoveryEntityMapView> {
  GoogleMapController? _controller;
  var _isLocating = false;
  var _hasLocationPermission = false;

  @override
  void didUpdateWidget(DiscoveryEntityMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.items) != _signature(widget.items)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fitItems());
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.mapPin, size: 44),
              const SizedBox(height: AppSpacing.md),
              Text(widget.emptyMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            key: const Key('discovery-entity-google-map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(items.first.latitude, items.first.longitude),
              zoom: items.length == 1 ? 14 : 11,
            ),
            markers: {
              for (final item in items)
                Marker(
                  markerId: MarkerId(item.id),
                  position: LatLng(item.latitude, item.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  onTap: () => _showItem(item),
                ),
            },
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: _hasLocationPermission,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              unawaited(_fitItems());
            },
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: 76,
          child: FloatingActionButton.small(
            key: const Key('discovery-map-my-location'),
            heroTag: 'discovery-map-my-location',
            tooltip: AppLocalizations.of(context).discoveryMapMyLocation,
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

  Future<void> _fitItems() async {
    final controller = _controller;
    final items = widget.items;
    if (controller == null || items.isEmpty) return;
    if (items.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(items.first.latitude, items.first.longitude),
          14,
        ),
      );
      return;
    }
    var minLat = items.first.latitude;
    var maxLat = minLat;
    var minLng = items.first.longitude;
    var maxLng = minLng;
    for (final item in items.skip(1)) {
      minLat = item.latitude < minLat ? item.latitude : minLat;
      maxLat = item.latitude > maxLat ? item.latitude : maxLat;
      minLng = item.longitude < minLng ? item.longitude : minLng;
      maxLng = item.longitude > maxLng ? item.longitude : maxLng;
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
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).discoveryMapLocationUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _showItem(DiscoveryMapItem item) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            if (item.subtitle?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(item.subtitle!),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                item.onOpenDetail();
              },
              child: Text(AppLocalizations.of(context).discoveryMapViewDetails),
            ),
          ],
        ),
      ),
    ),
  );

  static String _signature(List<DiscoveryMapItem> items) => items
      .map((item) => '${item.id}:${item.latitude}:${item.longitude}')
      .join('|');
}
