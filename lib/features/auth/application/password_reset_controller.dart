import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/password_reset.dart';

class ForgotPasswordController extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncData(false);

  Future<bool> submit({
    required String email,
    required String locale,
  }) async {
    state = const AsyncLoading();
    final webLocale = locale == 'zh' ? 'cn' : locale;
    final redirectUrl = Uri.parse(
      AppConfig.webBaseUrl,
    ).replace(path: '/$webLocale/auth/reset-password').toString();
    final result = await AsyncValue.guard(() async {
      await ref
          .read(authServiceProvider)
          .forgotPassword(
            email: email.trim(),
            locale: webLocale,
            redirectUrl: redirectUrl,
          );
      return true;
    });
    state = result;
    return result.value ?? false;
  }
}

final NotifierProvider<ForgotPasswordController, AsyncValue<bool>>
forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, AsyncValue<bool>>(
      ForgotPasswordController.new,
    );

final FutureProviderFamily<PasswordResetTokenStatus, String>
passwordResetTokenProvider = FutureProvider.autoDispose
    .family<PasswordResetTokenStatus, String>(
      (ref, token) => ref.watch(authServiceProvider).verifyResetToken(token),
    );

class ResetPasswordController extends Notifier<AsyncValue<bool>> {
  ResetPasswordController(this.token);

  final String token;

  @override
  AsyncValue<bool> build() => const AsyncData(false);

  Future<bool> submit(String newPassword) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref
          .read(authServiceProvider)
          .resetPassword(token: token, newPassword: newPassword);
      return true;
    });
    state = result;
    return result.value ?? false;
  }
}

final NotifierProviderFamily<ResetPasswordController, AsyncValue<bool>, String>
resetPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ResetPasswordController, AsyncValue<bool>, String>(
      ResetPasswordController.new,
    );
