import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _club = ClubSummary(
  id: 'club-1',
  name: 'Nhóm Cầu Lông Vmito',
  memberCount: 24,
  joinPolicy: 'OPEN',
  image: 'https://example.invalid/cover.jpg',
  logo: 'https://example.invalid/logo.jpg',
  images: [
    'https://example.invalid/one.jpg',
    'https://example.invalid/two.jpg',
  ],
);

const _clubWithoutImages = ClubSummary(
  id: 'club-without-images',
  name: 'Nhóm chưa có ảnh',
  memberCount: 4,
  joinPolicy: 'OPEN',
);

const _memberUser = User(
  id: 'member-1',
  email: 'member@example.com',
  role: UserRole.player,
  name: 'Thành viên',
);

const _memberClub = ClubSummary(
  id: 'member-club',
  name: 'Nhóm của thành viên',
  memberCount: 1,
  joinPolicy: 'OPEN',
  members: [
    ClubMember(
      id: 'membership-1',
      userId: 'member-1',
      name: 'Thành viên',
      email: 'member@example.com',
      role: 'MEMBER',
      level: 3,
    ),
  ],
);

const _invitationClub = ClubSummary(
  id: 'invitation-club',
  name: 'Nhóm chỉ nhận lời mời',
  memberCount: 8,
  joinPolicy: 'INVITATION_ONLY',
);

const _longNameClub = ClubSummary(
  id: 'long-name-club',
  name: 'Nhóm cầu lông giao lưu cuối tuần dành cho mọi trình độ',
  memberCount: 18,
  joinPolicy: 'APPROVAL_REQUIRED',
);

const _richAboutClub = ClubSummary(
  id: 'rich-about-club',
  name: 'Nhóm có giới thiệu chi tiết',
  memberCount: 18,
  joinPolicy: 'OPEN',
  description: '''
    <h2>Chơi vui cuối tuần</h2>
    <p>Chào <strong>mọi người</strong> đến với nhóm.</p>
    <ul><li>Sinh hoạt đều đặn</li><li>Tôn trọng đồng đội</li></ul>
    <p><a href="https://vmito.com/clubs/rich-about-club">Xem thông tin nhóm</a></p>
    <table>
      <thead><tr><th>Ngày</th><th>Khung giờ</th></tr></thead>
      <tbody><tr><td>Thứ Bảy</td><td>18:00–20:00</td></tr></tbody>
    </table>
    <img src="https://example.invalid/about.jpg" alt="Ảnh sinh hoạt nhóm">
  ''',
  location: 'Quận 1, TP.HCM',
  hostName: 'Nguyễn Văn A',
  requiredLevels: [3, 4],
  socialLinks: {'facebook': 'https://facebook.com/vmito'},
);

const _emptyHtmlClub = ClubSummary(
  id: 'empty-html-club',
  name: 'Nhóm chưa có giới thiệu',
  memberCount: 2,
  joinPolicy: 'OPEN',
  description: '<p><br></p><script>ignored()</script><style>.x{}</style>',
);

Future<void> _pump(
  WidgetTester tester, {
  ClubSummary club = _club,
  double width = 390,
  double safeAreaTop = 0,
  double textScale = 1,
  User? currentUser,
}) async {
  tester.view
    ..physicalSize = Size(width * 3, 844 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(
        '${club.id}-${currentUser?.id}-$width-$safeAreaTop-$textScale',
      ),
      overrides: [
        clubDetailProvider.overrideWith((ref, id) async => club),
        clubAnnouncementsProvider.overrideWith((ref, id) async => const []),
        currentUserProvider.overrideWithValue(currentUser),
        isSignedInProvider.overrideWithValue(currentUser != null),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final safePadding = EdgeInsets.only(top: safeAreaTop);
          return MediaQuery(
            data: mediaQuery.copyWith(
              padding: safePadding,
              viewPadding: safePadding,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: const ClubDetailScreen(clubId: 'club-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the club cover carousel and pinned header', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.byKey(const Key('club-hero-carousel')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-hero-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-hero-dot-1')), findsOneWidget);
    expect(find.text('Nhóm Cầu Lông Vmito'), findsWidgets);
    expect(find.text('Thành viên'), findsOneWidget);
    expect(find.text('Thành viên (24)'), findsNothing);
    expect(find.text('Lịch sinh hoạt'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.byKey(const ValueKey('club-tab-bar')), findsOneWidget);
    expect(find.byKey(const Key('club-identity-regular')), findsOneWidget);
    expect(find.byKey(const Key('club-identity-compact')), findsNothing);
    expect(find.byKey(const Key('club-membership-bottom-bar')), findsOneWidget);
    expect(find.byKey(const Key('club-join-button')), findsOneWidget);
    expect(find.byIcon(AppIcons.userPlus), findsOneWidget);
    expect(find.text('Tham gia nhóm'), findsOneWidget);

    final appBar = tester.widget<SliverAppBar>(
      find.byKey(const Key('club-detail-app-bar')),
    );
    expect(appBar.expandedHeight, 220);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('reveals the compact title below an iPhone safe area', (
    tester,
  ) async {
    await _pump(tester, safeAreaTop: 59);

    AnimatedOpacity sticky() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('club-sticky-title')),
    );

    expect(sticky().opacity, 0);
    await tester.drag(
      find.byKey(const Key('club-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pump();

    expect(sticky().opacity, 1);
    expect(
      tester
          .widget<FavoriteButton>(
            find.byKey(const Key('club-favorite-button')),
          )
          .overlay,
      isFalse,
    );
    expect(
      tester.getSize(find.byKey(const Key('club-share-button'))),
      tester.getSize(find.byKey(const Key('club-favorite-button'))),
    );
    expect(
      tester.getSize(find.byKey(const Key('club-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
  });

  testWidgets('share button matches favorite button on the cover', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      tester.getSize(find.byKey(const Key('club-share-button'))),
      tester.getSize(find.byKey(const Key('club-favorite-button'))),
    );
    expect(
      tester.getSize(find.byKey(const Key('club-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
  });

  testWidgets('limits long identity and sticky names', (tester) async {
    await _pump(tester, club: _longNameClub);

    final identityName = tester.widget<Text>(
      find.byKey(const Key('club-identity-name')),
    );
    final stickyName = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('club-sticky-title')),
        matching: find.byType(Text),
      ),
    );

    expect(identityName.maxLines, 2);
    expect(identityName.overflow, TextOverflow.ellipsis);
    expect(stickyName.maxLines, 1);
    expect(stickyName.overflow, TextOverflow.ellipsis);
    expect(stickyName.style?.fontSize, 16);
    expect(stickyName.style?.height, closeTo(20 / 16, 0.0001));
    expect(stickyName.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the sticky action usable at narrow width and large text', (
    tester,
  ) async {
    await _pump(tester, width: 320, textScale: 2);

    expect(find.byKey(const Key('club-identity-compact')), findsOneWidget);
    expect(find.byKey(const Key('club-identity-regular')), findsNothing);
    expect(find.byKey(const Key('club-join-button')), findsOneWidget);
    expect(find.byKey(const Key('club-membership-bottom-bar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('club-join-button'))).width,
      greaterThan(250),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a leave action sheet for an existing member', (
    tester,
  ) async {
    await _pump(tester, club: _memberClub, currentUser: _memberUser);
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(find.text('MEMBER · TB-'), findsOneWidget);

    final status = tester.widget<OutlinedButton>(
      find.byKey(const Key('club-membership-status-button')),
    );

    expect(status.style?.backgroundColor?.resolve({}), isNotNull);
    expect(find.text('Đã tham gia'), findsOneWidget);
    await tester.tap(find.byKey(const Key('club-membership-status-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-leave-group-button')), findsOneWidget);
    expect(find.byIcon(AppIcons.userMinus), findsOneWidget);
    expect(find.text('Rời nhóm'), findsOneWidget);
  });

  testWidgets('shows invitation policy without a duplicate CTA', (
    tester,
  ) async {
    await _pump(tester, club: _invitationClub);

    expect(find.textContaining('Chỉ nhận lời mời'), findsOneWidget);
    expect(find.byKey(const Key('club-membership-bottom-bar')), findsNothing);
    expect(find.byKey(const Key('club-join-button')), findsNothing);
    expect(
      find.byKey(const Key('club-membership-status-button')),
      findsNothing,
    );
  });

  testWidgets('uses the default cover when the club has no images', (
    tester,
  ) async {
    await _pump(tester, club: _clubWithoutImages);

    expect(find.byKey(const Key('club-default-cover')), findsOneWidget);
    expect(find.byKey(const Key('club-hero-carousel')), findsNothing);
    expect(find.text('Ảnh'), findsNothing);
    expect(find.byKey(const Key('club-identity-logo')), findsOneWidget);
    expect(find.text('N'), findsOneWidget);

    final logo = tester.widget<Container>(
      find.byKey(const Key('club-identity-logo')),
    );
    expect((logo.decoration! as BoxDecoration).shape, BoxShape.circle);
  });

  testWidgets('does not overflow at a narrow phone width', (tester) async {
    await _pump(
      tester,
      club: _richAboutClub,
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the web rich description and keeps mobile metadata', (
    tester,
  ) async {
    await _pump(tester, club: _richAboutClub);

    expect(find.text('Giới thiệu về nhóm'), findsOneWidget);
    expect(find.byType(HtmlWidget), findsOneWidget);
    expect(find.byKey(const Key('club-about-empty')), findsNothing);
    expect(
      find.text('Chơi vui cuối tuần', findRichText: true),
      findsOneWidget,
    );
    expect(
      _richTextContaining('Chào mọi người đến với nhóm.'),
      findsOneWidget,
    );
    expect(_richTextContaining('Sinh hoạt đều đặn'), findsOneWidget);
    expect(_richTextContaining('Xem thông tin nhóm'), findsOneWidget);
    expect(find.textContaining('<h2>'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('club-about-rich-description')),
        matching: find.byType(CachedNetworkImage),
      ),
      findsOneWidget,
    );

    expect(find.text('Trình độ yêu cầu'), findsOneWidget);
    expect(find.text('TB-'), findsOneWidget);
    expect(find.text('Địa điểm'), findsOneWidget);
    expect(find.text('Quận 1, TP.HCM'), findsOneWidget);
    expect(find.text('Trưởng nhóm'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Mạng xã hội & Liên kết'), findsOneWidget);
    expect(find.text('facebook'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('treats visually empty HTML as an empty description', (
    tester,
  ) async {
    await _pump(tester, club: _emptyHtmlClub);

    expect(find.byKey(const Key('club-about-empty')), findsOneWidget);
    expect(find.text('Chưa có mô tả.'), findsOneWidget);
    expect(find.byType(HtmlWidget), findsNothing);
    expect(find.textContaining('ignored'), findsNothing);
  });
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);
