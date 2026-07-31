import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

class RegistrationController extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() => const AsyncData(null);

  Future<User?> submit({
    required String name,
    required String email,
    required String password,
    required String locale,
    String? phone,
    String? gender,
  }) async {
    state = const AsyncLoading();
    final webLocale = locale == 'zh' ? 'cn' : locale;
    final normalizedPhone = phone?.trim();
    final result = await AsyncValue.guard(
      () => ref
          .read(authServiceProvider)
          .register(
            name: name.trim(),
            email: email.trim().toLowerCase(),
            password: password,
            phone: normalizedPhone?.isEmpty ?? true ? null : normalizedPhone,
            gender: gender?.isEmpty ?? true ? null : gender,
            locale: webLocale,
          ),
    );
    state = result;
    return result.value;
  }
}

final NotifierProvider<RegistrationController, AsyncValue<User?>>
registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, AsyncValue<User?>>(
      RegistrationController.new,
    );
