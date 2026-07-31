import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('like-p1')));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
