import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

/// Reference implementation for every service in this app.
///
/// Rules, taken from `vmito-fe/src/lib/api/*.service.ts`:
/// - one class per web service file, named the same;
/// - it takes [ApiClient], never a bare `Dio`;
/// - it returns domain models, never `Response` or raw maps;
/// - it does **not** touch app state — the controller does that.
class AuthService {
  const AuthService(this._client);

  final ApiClient _client;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
      // The sign-in form renders its own error inline; no global surface.
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, LoginResponse.fromJson);
  }

  /// `locale` is a query param, and it decides the language of the welcome
  /// email — pass the app's current locale, not a constant.
  Future<User> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? gender,
    String? locale,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      queryParameters: {'locale': ?locale},
      data: {
        'email': email,
        'password': password,
        'name': name,
        'phone': ?phone,
        'gender': ?gender,
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, User.fromJson);
  }

  Future<User> currentUser() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.currentUser,
    );
    return unwrap(response.data, User.fromJson);
  }

  Future<void> forgotPassword(String email) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put<Map<String, dynamic>>(
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      options: apiOptions(skipGlobalError: true),
    );
  }

  /// Guest join. Returns the player and session the code resolves to.
  Future<Map<String, dynamic>> joinByCode({
    required String sessionCode,
    String? name,
    String? gender,
    int? level,
    String? phone,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.joinByCode,
      data: {
        'sessionCode': sessionCode.trim().toUpperCase(),
        'name': ?name,
        'gender': ?gender,
        // PlayerLevel is an int, never an enum — the values are non-contiguous
        // (1-8, then 9 = BEGINNER_MINUS, 10 = BEGINNER_PLUS).
        'level': ?level,
        'phone': ?phone,
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, (json) => json);
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);
