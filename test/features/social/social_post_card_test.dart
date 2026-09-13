import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

final _post = SocialPost(
  id: 'p1',
  content: 'Kèo cầu lông tối nay',
  author: const SocialPostAuthor(id: '', name: 'An'),
  images: const [],
  likeCount: 2,
  commentCount: 0,
  shareCount: 1,
  isLiked: false,
  createdAt: DateTime(2026, 7, 30, 19),
);

class _FakeFeedController extends FeedController {
  @override
  FeedState build() => FeedState(posts: [_post], page: 1);

  @override
  Future<void> toggleLike(String postId) async {
    final post = state.posts.single;
    state = state.copyWith(
      posts: [post.copyWith(isLiked: true, likeCount: 3)],
    );
  }
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(feedControllerProvider).posts.single;
    return Scaffold(body: SocialPostCard(post: post));
  }
}

class _ProfilePostHarness extends StatefulWidget {
  const _ProfilePostHarness();

  @override
  State<_ProfilePostHarness> createState() => _ProfilePostHarnessState();
}

class _ProfilePostHarnessState extends State<_ProfilePostHarness> {
  SocialPost post = _post;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SocialPostCard(
      post: post,
      onPostChanged: (updated) => setState(() => post = updated),
    ),
  );
}

class _EmptyFeedController extends FeedController {
  @override
  FeedState build() => const FeedState();

  @override
  Future<void> toggleLike(String postId) async {}
}

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('renders post counters and updates like interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedControllerProvider.overrideWith(_FakeFeedController.new),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Harness(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Kèo cầu lông tối nay'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(AppIcons.favorite), findsOneWidget);

    await tester.tap(find.byKey(const Key('like-p1')));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(AppIcons.favoriteFilled), findsWidgets);
  });

  testWidgets('updates a profile post immediately when liked', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedControllerProvider.overrideWith(_EmptyFeedController.new),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ProfilePostHarness(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('like-p1')));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Đã thích'), findsOneWidget);
  });

  testWidgets('opens every image from a shared post in the lightbox', (
    tester,
  ) async {
    final sharedPost = SocialPost(
      id: 'shared-1',
      content: 'Chia sẻ bài viết',
      author: const SocialPostAuthor(id: 'user-1', name: 'An'),
      images: const [],
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      isLiked: false,
      createdAt: DateTime(2026, 7, 30, 19),
      originalPost: SocialPost(
        id: 'original-1',
        content: 'Bài viết gốc',
        author: const SocialPostAuthor(id: 'user-2', name: 'Bình'),
        images: const [
          SocialPostImage(id: 'image-1', url: 'https://image/1.jpg'),
          SocialPostImage(id: 'image-2', url: 'https://image/2.jpg'),
        ],
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        isLiked: false,
        createdAt: DateTime(2026, 7, 30, 18),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedControllerProvider.overrideWith(_EmptyFeedController.new),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SocialPostCard(post: sharedPost)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('shared-post-image-original-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lightbox-next-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('opens a regular post image in the lightbox', (tester) async {
    final post = SocialPost(
      id: 'post-with-image',
      content: 'Bài viết có ảnh',
      author: const SocialPostAuthor(id: 'user-1', name: 'An'),
      images: const [
        SocialPostImage(id: 'image-1', url: 'https://image/1.jpg'),
      ],
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      isLiked: false,
      createdAt: DateTime(2026, 7, 30, 19),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedControllerProvider.overrideWith(_EmptyFeedController.new),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SocialPostCard(post: post)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('post-image-single')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('lightbox-close-button')), findsOneWidget);
  });

  testWidgets('opens an activity post image in the lightbox', (tester) async {
    final post = SocialPost(
      id: 'avatar-update',
      content: '',
      author: const SocialPostAuthor(id: 'user-1', name: 'An'),
      images: const [],
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      isLiked: false,
      createdAt: DateTime(2026, 7, 30, 19),
      activityType: 'AVATAR_UPDATED',
      metadata: const {'image': 'https://image/avatar.jpg'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedControllerProvider.overrideWith(_EmptyFeedController.new),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SocialPostCard(post: post)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('activity-post-image')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('lightbox-close-button')), findsOneWidget);
  });
}
