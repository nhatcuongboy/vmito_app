import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';

class _MemoryLocaleRepository implements LocaleRepository {
  _MemoryLocaleRepository([this.languageCode]);

  String? languageCode;

  @override
  String? readLanguageCode() => languageCode;

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }
}

ProviderContainer _container(_MemoryLocaleRepository repository) =>
    ProviderContainer(
      overrides: [localeRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test('restores a persisted supported locale', () {
    final container = _container(_MemoryLocaleRepository('zh'));
    addTearDown(container.dispose);

    container.read(localeControllerProvider.notifier).restore(const [
      Locale('en'),
    ]);

    expect(container.read(localeControllerProvider), const Locale('zh'));
  });

  test('uses the first supported device locale when no choice is stored', () {
    final container = _container(_MemoryLocaleRepository());
    addTearDown(container.dispose);

    container.read(localeControllerProvider.notifier).restore(const [
      Locale('fr'),
      Locale('en', 'GB'),
      Locale('vi'),
    ]);

    expect(container.read(localeControllerProvider), const Locale('en'));
  });

  test('falls back to Vietnamese for unsupported or corrupt values', () {
    final container = _container(_MemoryLocaleRepository('fr'));
    addTearDown(container.dispose);

    container.read(localeControllerProvider.notifier).restore(const [
      Locale('ja'),
    ]);

    expect(container.read(localeControllerProvider), const Locale('vi'));
  });

  test('selection updates state and persistence', () async {
    final repository = _MemoryLocaleRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(localeControllerProvider.notifier)
        .select(const Locale('en'));

    expect(container.read(localeControllerProvider), const Locale('en'));
    expect(repository.languageCode, 'en');

    final restartedContainer = _container(repository);
    addTearDown(restartedContainer.dispose);
    restartedContainer.read(localeControllerProvider.notifier).restore(const [
      Locale('vi'),
    ]);
    expect(
      restartedContainer.read(localeControllerProvider),
      const Locale('en'),
    );
  });
}
