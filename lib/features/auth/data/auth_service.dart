import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/auth/domain/password_reset.dart';
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

  /// Exchanges a verified Apple identity token for our own JWT pair.
  ///
  /// [givenName] and [familyName] must be passed through on the **first**
  /// authorization and only then: Apple supplies the display name once and
  /// never again, so dropping it here leaves the account nameless forever.
  Future<LoginResponse> signInWithApple({
    required String identityToken,
    String? givenName,
    String? familyName,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.appleSignIn,
      data: {
        'identityToken': identityToken,
        'givenName': ?givenName,
        'familyName': ?familyName,
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, LoginResponse.fromJson);
  }

  /// Permanently deletes the signed-in account.
  ///
  /// The backend anonymizes rather than row-deletes — hosted sessions and the
  /// payment ledger are also other people's data — but the account can never
  /// be signed into again and the email is freed. Irreversible either way, so
  /// the caller must confirm before invoking this.
  Future<void> deleteAccount() async {
    await _client.delete<Map<String, dynamic>>(
      ApiEndpoints.deleteAccount,
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<User> currentUser() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.currentUser,
    );
    return unwrap(response.data, User.fromJson);
  }

  Future<void> forgotPassword({
    required String email,
    required String locale,
    required String redirectUrl,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiEndpoints.forgotPassword,
      data: {
        'email': email,
        'locale': locale,
        'redirectUrl': redirectUrl,
      },
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.put<Map<String, dynamic>>(
      ApiEndpoints.resetPassword,
      data: {'token': token, 'newPassword': newPassword},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<PasswordResetTokenStatus> verifyResetToken(String token) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.verifyResetToken,
      queryParameters: {'token': token},
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, PasswordResetTokenStatus.fromJson);
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
