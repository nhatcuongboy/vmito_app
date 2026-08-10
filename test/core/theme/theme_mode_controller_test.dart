import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/theme_mode_controller.dart';

class _MemoryThemeRepository implements ThemeRepository {
  _MemoryThemeRepository([this.themeModeName]);

  String? themeModeName;

  @override
  String? readThemeModeName() => themeModeName;

  @override
  Future<void> writeThemeModeName(String themeModeName) async {
    this.themeModeName = themeModeName;
  }
}

ProviderContainer _container(_MemoryThemeRepository repository) =>
    ProviderContainer(
      overrides: [themeRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test('restores a persisted theme mode', () {
    final container = _container(_MemoryThemeRepository('dark'));
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider.notifier).restore();

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });

  test('defaults to system when no choice is stored', () {
    final container = _container(_MemoryThemeRepository());
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider.notifier).restore();

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
  });

  test('ignores a corrupt stored value', () {
    final container = _container(_MemoryThemeRepository('sepia'));
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider.notifier).restore();

    expect(container.read(themeModeControllerProvider), ThemeMode.system);
  });

  test('selection updates state and persistence', () async {
    final repository = _MemoryThemeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(themeModeControllerProvider.notifier)
        .select(ThemeMode.dark);

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(repository.themeModeName, 'dark');

    final restartedContainer = _container(repository);
    addTearDown(restartedContainer.dispose);
    restartedContainer.read(themeModeControllerProvider.notifier).restore();

    expect(
      restartedContainer.read(themeModeControllerProvider),
      ThemeMode.dark,
    );
  });
}
