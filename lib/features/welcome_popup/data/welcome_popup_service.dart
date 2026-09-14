import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/welcome_popup/domain/welcome_popup.dart';

class WelcomePopupService {
  const WelcomePopupService(this._client);
  final ApiClient _client;

  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;

  Future<WelcomePopup?> fetchActive() async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.activeWelcomePopup,
    );
    final payload = _payload(response.data);
    if (payload is! Map<String, dynamic>) return null;
    return WelcomePopup.fromJson(payload);
  }
}

final welcomePopupServiceProvider = Provider<WelcomePopupService>(
  (ref) => WelcomePopupService(ref.watch(apiClientProvider)),
);
