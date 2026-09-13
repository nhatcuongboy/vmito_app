import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';

class NewAdminUnit {
  const NewAdminUnit({required this.city, required this.wards});

  factory NewAdminUnit.fromJson(Map<String, dynamic> json) => NewAdminUnit(
    city: json['city'] as String? ?? '',
    wards: (json['wards'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
  );
  final String city;
  final List<String> wards;
}

final newAdminUnitsProvider = FutureProvider<List<NewAdminUnit>>((ref) async {
  final response = await ref
      .watch(apiClientProvider)
      .get<dynamic>(
        ApiEndpoints.venueAdminUnits,
      );
  final body = response.data;
  final payload = body is Map<String, dynamic> && body['success'] == true
      ? body['data']
      : body;
  return (payload as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(NewAdminUnit.fromJson)
      .where((unit) => unit.city.isNotEmpty)
      .toList(growable: false);
});
