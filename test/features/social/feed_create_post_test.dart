import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class _MockSocialService extends Mock implements SocialService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PostComposerDraft(content: 'fallback'));
  });

  test(
    'creating a post adds the server result at the top of the feed',
    () async {
      final service = _MockSocialService();
      final container = ProviderContainer(
        overrides: [socialServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      const draft = PostComposerDraft(content: 'Bài viết mới');
      final post = SocialPost(
        id: 'post-1',
        content: draft.content,
        author: const SocialPostAuthor(id: 'user-1', name: 'An'),
        images: const [],
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        isLiked: false,
        createdAt: DateTime(2026, 8, 29),
      );
      when(() => service.createPost(any())).thenAnswer((_) async => post);

      await container.read(feedControllerProvider.notifier).createPost(draft);

      expect(container.read(feedControllerProvider).posts, [post]);
      verify(() => service.createPost(draft)).called(1);
    },
  );
}
