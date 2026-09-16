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
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestClubManagementController extends ClubManagementController {
  static String? addedUserId;
  static String? removedUserId;
  static String? cancelledJoinRequestClubId;

  @override
  Future<void> addMember(String clubId, String userId) async {
    addedUserId = userId;
  }

  @override
  Future<void> removeMember(String clubId, String userId) async {
    removedUserId = userId;
  }

  @override
  Future<void> cancelJoinRequest(String clubId) async {
    cancelledJoinRequestClubId = clubId;
  }
}

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

const _adminUser = User(
  id: 'admin-1',
  email: 'admin@example.com',
  role: UserRole.admin,
  name: 'Quản trị viên',
);

const _guestUser = User(
  id: 'guest-player-1',
  email: '',
  role: UserRole.guest,
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

ClubSummary _membersClub(int count) => ClubSummary(
  id: 'many-members-club',
  name: 'Nhóm đông thành viên',
  memberCount: count,
  joinPolicy: 'OPEN',
  members: List.generate(
    count,
    (index) => ClubMember(
      id: 'membership-$index',
      userId: 'user-$index',
      name: 'Người chơi $index',
      email: 'player$index@example.com',
      role: switch (index) {
        0 => 'ADMIN',
        1 => 'MODERATOR',
        _ => 'MEMBER',
      },
      level: index == 0 ? 3 : null,
      gender: index.isEven ? 'MALE' : 'FEMALE',
      createdAt: DateTime.utc(2026, 8, index + 1),
    ),
  ),
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
  List<ClubJoinRequest> myClubRequests = const [],
  List<PlayerProfile> guests = const [],
}) async {
  _TestClubManagementController.addedUserId = null;
  _TestClubManagementController.removedUserId = null;
  _TestClubManagementController.cancelledJoinRequestClubId = null;
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
        clubRosterProvider.overrideWith((ref, id) async => guests),
        clubAnnouncementsProvider.overrideWith((ref, id) async => const []),
        clubUserSearchProvider.overrideWith(
          (ref, search) async => search.query == 'Lan'
              ? const [
                  ClubUserSearchResult(
                    id: 'new-user',
                    name: 'Lan',
                    email: 'lan@example.com',
                  ),
                ]
              : const [],
        ),
        myClubRequestsProvider.overrideWith((ref) async => myClubRequests),
        clubManagementControllerProvider.overrideWith(
          _TestClubManagementController.new,
        ),
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

  testWidgets('uses the available dialog width and does not submit on cancel', (
    tester,
  ) async {
    await _pump(tester, currentUser: _memberUser);

    await tester.tap(find.byKey(const Key('club-join-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-join-dialog')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('club-join-message-field'))).width,
      greaterThan(300),
    );

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-join-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prompts a guest to sign in before joining a club', (
    tester,
  ) async {
    await _pump(tester, currentUser: _guestUser);

    await tester.tap(find.byKey(const Key('club-join-button')));
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
    expect(find.byKey(const Key('club-join-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows a pending state instead of the join button after a request is sent',
    (tester) async {
      await _pump(
        tester,
        currentUser: _memberUser,
        myClubRequests: [
          ClubJoinRequest(
            id: 'request-1',
            userId: _memberUser.id,
            userName: _memberUser.name ?? '',
            userEmail: _memberUser.email,
            createdAt: DateTime.utc(2026),
            clubId: _club.id,
          ),
        ],
      );

      expect(find.text('Tham gia nhóm'), findsNothing);
      expect(find.text('Đang chờ duyệt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('club-join-button')));
      await tester.pumpAndSettle();

      final confirmButton = find.byKey(
        const Key('club-cancel-request-confirm'),
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(
        _TestClubManagementController.cancelledJoinRequestClubId,
        _club.id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reveals the compact title below an iPhone safe area', (
    tester,
  ) async {
    await _pump(tester, safeAreaTop: 59, currentUser: _adminUser);

    AnimatedOpacity sticky() => tester.widget<AnimatedOpacity>(
      find.byKey(const Key('club-sticky-title')),
    );

    expect(sticky().opacity, 0);
    expect(
      find.byKey(const Key('club-favorite-button')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('club-detail-scroll')),
      const Offset(0, -360),
    );
    await tester.pump();

    expect(sticky().opacity, 1);
    expect(find.byKey(const Key('club-favorite-button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('club-share-button'))),
      const Size.square(FavoriteButton.detailControlSize),
    );
  });

  testWidgets('share button matches favorite button on the cover', (
    tester,
  ) async {
    await _pump(tester, currentUser: _adminUser);

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
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Rời nhóm'), findsOneWidget);
    await tester.tap(find.text('Rời nhóm'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Bạn có chắc muốn rời khỏi nhóm "Nhóm của thành viên" không?'),
      findsOneWidget,
    );
  });

  testWidgets('ports member header, badges and incremental view more', (
    tester,
  ) async {
    await _pump(tester, club: _membersClub(10));
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    expect(find.text('10 thành viên'), findsOneWidget);
    expect(find.text('Quản trị viên'), findsOneWidget);
    expect(find.text('Điều hành viên'), findsOneWidget);
    expect(find.text('TB-'), findsOneWidget);
    expect(find.byKey(const ValueKey('club-member-user-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-member-user-8')), findsNothing);

    await tester.drag(
      find.byKey(const Key('public-club-members-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('club-members-view-more')));
    await tester.pump();

    expect(find.byKey(const ValueKey('club-member-user-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-member-user-9')), findsOneWidget);
    expect(find.byKey(const Key('club-members-view-more')), findsNothing);
  });

  testWidgets('shows the mobile member details sheet', (tester) async {
    await _pump(tester, club: _memberClub, currentUser: _memberUser);
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('club-member-member-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông tin thành viên'), findsOneWidget);
    expect(find.text('Giới tính'), findsOneWidget);
    expect(find.text('Trình độ'), findsOneWidget);
    expect(find.text('Ngày tham gia'), findsOneWidget);
    expect(find.text('Chưa cập nhật'), findsNWidgets(2));
    expect(find.byKey(const Key('club-member-view-profile')), findsOneWidget);
    expect(find.byKey(const Key('club-member-details-remove')), findsNothing);
  });

  testWidgets('shows admin empty actions and reactive member search', (
    tester,
  ) async {
    await _pump(tester, currentUser: _adminUser);
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-members-empty')), findsOneWidget);
    expect(find.byKey(const Key('club-members-add')), findsOneWidget);
    expect(find.byKey(const Key('club-members-add-first')), findsOneWidget);

    await tester.tap(find.byKey(const Key('club-members-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('public-club-member-search')),
      'Lan',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('lan@example.com'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('club-member-add-new-user')),
    );
    await tester.pumpAndSettle();

    expect(_TestClubManagementController.addedUserId, 'new-user');
    expect(find.text('Đã thêm thành viên vào nhóm'), findsOneWidget);
  });

  testWidgets('admin can remove a member after confirmation', (tester) async {
    await _pump(
      tester,
      club: _membersClub(1),
      currentUser: _adminUser,
    );
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('club-member-remove-user-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gỡ Người chơi 0 khỏi nhóm?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('club-member-confirm-remove')));
    await tester.pumpAndSettle();

    expect(_TestClubManagementController.removedUserId, 'user-0');
    expect(find.text('Đã xóa thành viên khỏi nhóm'), findsOneWidget);
  });

  testWidgets('member grid adapts between phone and tablet widths', (
    tester,
  ) async {
    await _pump(tester, club: _membersClub(2), width: 320, textScale: 2);
    await tester.drag(find.byType(TabBar), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thành viên'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-members-grid-1')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(tester, club: _membersClub(2), width: 700);
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-members-grid-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('shows guest members in members tab with normal member UI', (
    tester,
  ) async {
    const guest = PlayerProfile(
      id: 'guest-1',
      name: 'Khách mời A',
      phone: '0912345678',
      level: 4,
      clubId: 'member-club',
    );
    await _pump(
      tester,
      club: _memberClub,
      currentUser: _adminUser,
      guests: const [guest],
    );

    // Switch to Members tab
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();

    // Verify official member and guest member are both rendered as normal members
    expect(find.text('Thành viên'), findsWidgets);
    expect(find.text('Khách mời A'), findsOneWidget);
    expect(find.text('Thành viên khách'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-member-guest-guest-1')),
      findsOneWidget,
    );

    // Tap on guest member card to view details
    await tester.tap(find.byKey(const ValueKey('club-member-guest-guest-1')));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin thành viên'), findsOneWidget);
    expect(find.byKey(const Key('club-member-edit-guest')), findsOneWidget);
    expect(find.text('Sửa'), findsOneWidget);
  });
}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);
