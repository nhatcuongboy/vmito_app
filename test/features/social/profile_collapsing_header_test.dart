import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_collapsing_header.dart';
import 'package:vmito_app/features/social/presentation/widgets/profile_header_geometry.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _longName = 'Nguyễn Nhật Cường Phạm Hữu Tưởng Bạch Nguyễn Nhật Cường';

const _profile = PublicProfile(
  id: 'user-1',
  name: _longName,
  role: 'HOST',
  joinedSessionsCount: 12,
);

const _user = User(
  id: 'user-1',
  email: 'owner@example.test',
  role: UserRole.host,
  name: _longName,
);

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('fades compact avatar without moving it between slots', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(0);
    addTearDown(offset.dispose);

    await _pumpHeader(tester, offset: offset);

    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(_opacity(tester, 'profile-compact-identity'), 0);
    expect(find.byType(AnimatedPositioned), findsNothing);

    offset.value = ProfileHeaderGeometry.collapseExtent(800);
    await tester.pump();

    expect(_opacity(tester, 'profile-compact-identity'), 1);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight,
      190,
    );
  });

  testWidgets('keeps fallback cover geometry and ellipsizes compact name', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(
      ProfileHeaderGeometry.collapseExtent(800),
    );
    addTearDown(offset.dispose);

    await _pumpHeader(tester, offset: offset, usesCompactOverlay: true);

    expect(
      find.byKey(const ValueKey('profile-fallback-cover')),
      findsOneWidget,
    );
    final compactIdentity = find.byKey(
      const ValueKey('profile-compact-identity'),
    );
    final name = tester.widget<Text>(
      find.descendant(of: compactIdentity, matching: find.text(_longName)),
    );
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  testWidgets('switches status icons after toolbar becomes compact', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(0);
    addTearDown(offset.dispose);

    await _pumpHeader(tester, offset: offset);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).systemOverlayStyle,
      isA<SystemUiOverlayStyle>().having(
        (style) => style.statusBarIconBrightness,
        'statusBarIconBrightness',
        Brightness.light,
      ),
    );

    await _pumpHeader(tester, offset: offset, usesCompactOverlay: true);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).systemOverlayStyle,
      isA<SystemUiOverlayStyle>().having(
        (style) => style.statusBarIconBrightness,
        'statusBarIconBrightness',
        Brightness.dark,
      ),
    );
  });

  testWidgets('shows the hamburger menu only on the root profile header', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(0);
    addTearDown(offset.dispose);
    var menuTapped = false;

    await _pumpHeader(
      tester,
      offset: offset,
      onMenuTap: () => menuTapped = true,
    );
    expect(find.byIcon(AppIcons.menu), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byIcon(AppIcons.menu));
    expect(menuTapped, isTrue);

    await _pumpHeader(tester, offset: offset, isRootProfile: false);
    expect(find.byIcon(AppIcons.menu), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('keeps independent tab offsets and shared collapsed header', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user),
          publicProfileProvider('user-1').overrideWith(
            (ref) async => const PublicProfileBundle(
              profile: _profile,
              stats: RatingStats(average: 4.8, total: 20),
              ratings: [],
              hostedSessionsCount: 34,
            ),
          ),
          profileTabsServiceProvider.overrideWithValue(
            const _FakeProfileTabsService(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PublicProfileScreen(userId: 'user-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final posts = find.byKey(const PageStorageKey('profile-posts-user-1'));
    await tester.drag(posts, const Offset(0, -900));
    await tester.pumpAndSettle();
    final postsOffset = _scrollOffset(tester, posts);
    expect(postsOffset, greaterThan(0));
    expect(_opacity(tester, 'profile-compact-identity'), 1);

    await tester.tap(find.text('Thành tích'));
    await tester.pumpAndSettle();
    final achievements = find.byKey(
      const PageStorageKey('profile-achievements-user-1'),
    );
    await tester.drag(achievements, const Offset(0, -500));
    await tester.pumpAndSettle();
    final achievementsOffset = _scrollOffset(tester, achievements);
    expect(achievementsOffset, greaterThan(0));

    await tester.tap(find.text('Bài viết'));
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester, posts), closeTo(postsOffset, .1));
    expect(_opacity(tester, 'profile-compact-identity'), 1);
  });

  testWidgets('fits overlapped avatar and edit action at 375dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user),
          publicProfileProvider('user-1').overrideWith(
            (ref) async => const PublicProfileBundle(
              profile: _profile,
              stats: RatingStats(average: 4.8, total: 20),
              ratings: [],
              hostedSessionsCount: 34,
            ),
          ),
          profileTabsServiceProvider.overrideWithValue(
            const _FakeProfileTabsService(hasPosts: false),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PublicProfileScreen(userId: 'user-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cover = find.byKey(const ValueKey('profile-cover'));
    final avatar = find.byKey(const ValueKey('profile-avatar-44.0'));
    final editButton = find.byKey(const ValueKey('profile-edit-button'));
    expect(tester.getSize(cover).height, 150);
    expect(
      tester.getCenter(avatar).dy,
      closeTo(tester.getBottomLeft(cover).dy, 1),
    );
    expect(editButton, findsOneWidget);
    expect(
      tester.getTopRight(avatar).dx,
      lessThanOrEqualTo(tester.getTopLeft(editButton).dx),
    );
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    expect(find.text('HOST'), findsNothing);
  });
}

double _opacity(WidgetTester tester, String key) =>
    tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

double _scrollOffset(WidgetTester tester, Finder list) => tester
    .state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    )
    .position
    .pixels;

Future<void> _pumpHeader(
  WidgetTester tester, {
  required ValueNotifier<double> offset,
  bool usesCompactOverlay = false,
  bool isRootProfile = true,
  VoidCallback? onMenuTap,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          ProfileCollapsingHeader(
            profile: _profile,
            scrollOffset: offset,
            isRootProfile: isRootProfile,
            isOwner: true,
            usesCompactSystemOverlay: usesCompactOverlay,
            menuTooltip: 'Mở menu',
            shareTooltip: 'Chia sẻ',
            settingsTooltip: 'Cài đặt',
            onMenuTap: onMenuTap ?? _doNothing,
            onShare: _doNothing,
            onSettings: _doNothing,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ],
      ),
    ),
  ),
);

void _doNothing() {}

class _FakeProfileTabsService implements ProfileTabsService {
  const _FakeProfileTabsService({this.hasPosts = true});

  final bool hasPosts;

  @override
  Future<SocialPostPage> posts(String id, {int page = 1}) async =>
      SocialPostPage(
        posts: hasPosts
            ? [
                for (var index = 0; index < 24; index++)
                  SocialPost(
                    id: 'post-$index',
                    content: 'Bài viết số $index',
                    author: const SocialPostAuthor(
                      id: 'user-1',
                      name: _longName,
                    ),
                    images: const [],
                    likeCount: index,
                    commentCount: 0,
                    shareCount: 0,
                    isLiked: false,
                    createdAt: DateTime(2026, 8, 11),
                  ),
              ]
            : const [],
        page: page,
        hasMore: false,
      );

  @override
  Future<UserAchievements> achievements(String id) async => UserAchievements(
    totalPoints: 420,
    tier: 'GOLD',
    ranks: const [],
    stats: const UserAchievementStats(),
    recentTransactions: [
      for (var index = 0; index < 30; index++)
        PointTransaction(
          id: 'transaction-$index',
          points: index,
          reason: 'Hoạt động $index',
          occurredAt: DateTime(2026, 8, 11),
        ),
    ],
  );

  @override
  Future<List<ClubSummary>> clubs(String id) => throw UnimplementedError();

  @override
  Future<pagination.Page<FavoriteTarget>> favorites(
    String type, {
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<pagination.Page<Session>> hosted(
    String id, {
    int page = 1,
    String filter = 'active',
  }) => throw UnimplementedError();
}
