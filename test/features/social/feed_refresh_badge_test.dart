import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class _MockSocialService extends Mock implements SocialService {}

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      email: 'user@example.test',
      role: UserRole.player,
    ),
  );
}

class _RecordingBadgeController extends NewsfeedBadgeController {
  int marks = 0;

  @override
  NewsfeedBadgeState build() => const NewsfeedBadgeState(count: 3);

  @override
  Future<void> markAsRead() async {
    marks++;
    state = state.copyWith(count: 0);
  }
}

void main() {
  late _MockSocialService service;
  late _RecordingBadgeController badge;
  late ProviderContainer container;

  setUp(() {
    service = _MockSocialService();
    badge = _RecordingBadgeController();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_TestAuthController.new),
        socialServiceProvider.overrideWithValue(service),
        newsfeedBadgeControllerProvider.overrideWith(() => badge),
      ],
    );
    addTearDown(container.dispose);
  });

  test('successful feed refresh marks the badge as read', () async {
    when(
      () => service.feed(page: 1),
    ).thenAnswer(
      (_) async => const SocialPostPage(posts: [], page: 1, hasMore: false),
    );

    final refreshed = await container
        .read(feedControllerProvider.notifier)
        .refresh();
    await Future<void>.delayed(Duration.zero);

    expect(refreshed, isTrue);
    expect(badge.marks, 1);
    expect(container.read(newsfeedBadgeControllerProvider).count, 0);
  });

  test('failed feed refresh preserves the unread badge', () async {
    when(() => service.feed(page: 1)).thenThrow(Exception('offline'));

    final refreshed = await container
        .read(feedControllerProvider.notifier)
        .refresh();

    expect(refreshed, isFalse);
    expect(badge.marks, 0);
    expect(container.read(newsfeedBadgeControllerProvider).count, 3);
  });
}
