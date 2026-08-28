import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';

void main() {
  group('LocationPreferencesController', () {
    test('starts with new-address mode enabled before restore', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(locationPreferencesControllerProvider);

      expect(state.showNewAddress, isTrue);
      expect(state.isRestored, isFalse);
    });

    test('defaults new-address mode to on and restores an undecided user', () {
      final container = ProviderContainer(
        overrides: [
          locationPreferencesRepositoryProvider.overrideWithValue(
            _Repository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationPreferencesControllerProvider.notifier).restore();

      expect(
        container.read(locationPreferencesControllerProvider).showNewAddress,
        isTrue,
      );
      expect(
        container
            .read(locationPreferencesControllerProvider)
            .onboardingCompleted,
        isFalse,
      );
    });

    test(
      'persists an intentional nationwide selection without reopening onboarding',
      () async {
        final repository = _Repository(city: 'Hồ Chí Minh');
        final container = ProviderContainer(
          overrides: [
            locationPreferencesRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          locationPreferencesControllerProvider.notifier,
        );
        controller.restore();

        await controller.selectCity(null);

        final state = container.read(locationPreferencesControllerProvider);
        expect(state.preferredCity, isNull);
        expect(state.onboardingCompleted, isTrue);
        expect(repository.city, isNull);
      },
    );

    test(
      'keeps the device preference when auth state changes elsewhere',
      () async {
        final repository = _Repository();
        final container = ProviderContainer(
          overrides: [
            locationPreferencesRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          locationPreferencesControllerProvider.notifier,
        );
        controller.restore();

        await controller.selectCity('Đà Nẵng');
        await controller.setShowNewAddress(value: false);

        expect(repository.city, 'Đà Nẵng');
        expect(repository.showNewAddress, isFalse);
        expect(repository.onboardingCompleted, isTrue);
      },
    );

    test('migrates a stored legacy code to the canonical API name', () async {
      final repository = _Repository(city: 'HCM');
      final container = ProviderContainer(
        overrides: [
          locationPreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationPreferencesControllerProvider.notifier).restore();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(locationPreferencesControllerProvider).preferredCity,
        'Hồ Chí Minh',
      );
      expect(repository.city, 'Hồ Chí Minh');
    });
  });
}

class _Repository implements LocationPreferencesRepository {
  _Repository({this.city});

  String? city;
  bool? onboardingCompleted;
  bool? showNewAddress;

  @override
  String? readPreferredCity() => city;
  @override
  bool? readOnboardingCompleted() => onboardingCompleted;
  @override
  bool? readShowNewAddress() => showNewAddress;

  @override
  Future<void> write({
    String? preferredCity,
    required bool onboardingCompleted,
    required bool showNewAddress,
  }) async {
    city = preferredCity;
    this.onboardingCompleted = onboardingCompleted;
    this.showNewAddress = showNewAddress;
  }
}
