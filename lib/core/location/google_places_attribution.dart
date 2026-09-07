import 'package:flutter/material.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';

/// Google attribution required when Places predictions are shown outside a
/// Google map.
class GooglePlacesAttribution extends StatelessWidget {
  const GooglePlacesAttribution({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Powered by Google',
    child: const ExcludeSemantics(
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Align(
            alignment: Alignment.centerRight,
            child: Image(
              image: FlutterGooglePlacesSdk.assetPoweredByGoogleOnWhite,
              height: 16,
            ),
          ),
        ),
      ),
    ),
  );
}
