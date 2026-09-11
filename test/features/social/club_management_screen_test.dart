import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management/widgets/club_management_states.dart';
import 'package:vmito_app/features/social/presentation/club_management_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const host = User(
  id: 'host-1',
  email: 'host@example.com',
  name: 'Host',
  role: UserRole.host,
);

const admin = User(
  id: 'admin-1',
  email: 'admin@example.com',
  name: 'Admin',
  role: UserRole.admin,
);

ClubSummary sampleClub({
  required String id,
  required String name,
  String role = 'ADMIN',
  String? hostId = 'host-1',
  int memberCount = 8,
  ClubVenue? defaultVenue,
}) => ClubSummary(
  id: id,
  slug: '$id-slug',
  name: name,
  memberCount: memberCount,
  joinPolicy: 'OPEN',
  role: role,
  hostId: hostId,
  hostName: 'Chủ nhóm',
  defaultVenue: defaultVenue,
);

ClubJoinRequest sampleRequest({
  required String id,
  String userName = 'Người xin',
  String clubName = 'Nhóm quản lý',
}) => ClubJoinRequest(
  id: id,
  userId: 'user-$id',
  userName: userName,
  userEmail: '$id@example.com',
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  clubId: 'club-$id',
  club: ClubJoinRequestClub(
    id: 'club-$id',
    name: clubName,
    hostName: 'Chủ nhóm khác',
  ),
);

Widget harness({
  required String tab,
  User user = host,
  List<ClubSummary> myClubs = const [],
  List<ClubSummary> pending = const [],
  List<ClubSummary>? managedClubs,
  Future<List<ClubSummary>>? managedClubsFuture,
  List<ClubJoinRequest> incoming = const [],
  List<ClubJoinRequest> outgoing = const [],
  TextScaler textScaler = TextScaler.noScaling,
  bool withRouter = false,
}) => ProviderScope(
  overrides: [
    currentUserProvider.overrideWithValue(user),
    canCreateClubProvider.overrideWithValue(false),
    managedClubsProvider.overrideWith(
      (ref) =>
          managedClubsFuture ??
          Future.value(
            managedClubs ?? [sampleClub(id: 'managed', name: 'Nhóm quản lý')],
          ),
    ),
    incomingClubRequestsProvider.overrideWith((ref) async => incoming),
    pendingClubsProvider.overrideWith((ref) async => pending),
    myClubsProvider.overrideWith((ref) async => myClubs),
    myClubRequestsProvider.overrideWith((ref) async => outgoing),
  ],
  child: withRouter
      ? MaterialApp.router(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Switching tabs rewrites the `?tab=` query via `context.replace`.
          routerConfig: GoRouter(
            initialLocation: AppRoutes.manageClubsForTab(tab),
            routes: [
              GoRoute(
                path: AppRoutes.manageClubs,
                builder: (_, state) => ClubManagementScreen(
                  initialTab:
                      state.uri.queryParameters[AppRoutes
                          .clubManagementTabQuery] ??
                      'managing',
                ),
              ),
            ],
          ),
        )
      : MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: ClubManagementScreen(initialTab: tab),
        ),
);

void main() {
  testWidgets('managing tab hides the request section when it is empty', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(harness(tab: 'managing'));
    await tester.pumpAndSettle();

    expect(find.text('Nhóm đang quản lý'), findsOneWidget);
    expect(find.text('Nhóm quản lý'), findsOneWidget);
    expect(find.text('Yêu cầu tham gia'), findsNothing);
    expect(
      find.byKey(const Key('club-management-waiting-badge')),
      findsNothing,
    );
    // The viewer hosts this club, so their own name is not repeated.
    expect(find.text('Chủ nhóm: Chủ nhóm'), findsNothing);
  });

  testWidgets('join requests come first and are counted on the tab', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 1400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      harness(
        tab: 'managing',
        incoming: [sampleRequest(id: 'r1')],
      ),
    );
    await tester.pumpAndSettle();

    final requests = tester.getTopLeft(find.text('Yêu cầu tham gia')).dy;
    final managed = tester.getTopLeft(find.text('Nhóm đang quản lý')).dy;
    expect(requests, lessThan(managed));
    expect(find.text('Người xin'), findsOneWidget);
    expect(find.textContaining('Đã gửi 2 ngày trước'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('club-management-waiting-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('title stays fixed when switching tabs', (tester) async {
    await tester.pumpWidget(harness(tab: 'managing', withRouter: true));
    await tester.pumpAndSettle();
    expect(find.text('Nhóm của tôi'), findsOneWidget);

    await tester.tap(find.text('Đã tham gia'));
    await tester.pumpAndSettle();

    expect(find.text('Nhóm của tôi'), findsOneWidget);
    expect(find.text('Nhóm đang tham gia'), findsOneWidget);
  });

  testWidgets('managed club menu drops "Manage" and keeps delete', (
    tester,
  ) async {
    await tester.pumpWidget(harness(tab: 'managing'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('managed-club-more-managed')));
    await tester.pumpAndSettle();

    expect(find.text('Xem trang nhóm'), findsOneWidget);
    expect(find.text('Sửa'), findsOneWidget);
    expect(find.text('Cấu hình phí'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);
    expect(find.text('Quản lý'), findsOneWidget); // the tab label only
  });

  testWidgets('shows skeleton cards while managed clubs load', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        tab: 'managing',
        managedClubsFuture: Completer<List<ClubSummary>>().future,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ClubCardSkeletonList), findsOneWidget);
  });

  testWidgets('member tab excludes clubs managed by the current user', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(900, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      harness(
        tab: 'member',
        myClubs: [
          sampleClub(id: 'owned', name: 'Nhóm sở hữu'),
          sampleClub(
            id: 'joined',
            name: 'Nhóm đã tham gia',
            role: 'MEMBER',
            hostId: 'another-host',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhóm đang tham gia'), findsOneWidget);
    expect(find.text('Nhóm đã tham gia'), findsOneWidget);
    expect(find.text('Nhóm sở hữu'), findsNothing);
    expect(find.text('Đang chờ duyệt'), findsNothing);
  });

  testWidgets('outgoing requests drop the redundant pending pill', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      harness(
        tab: 'member',
        outgoing: [
          sampleRequest(id: 'o1', clubName: 'CLB CLVK - Cầu Lông Vui Khỏe'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ duyệt'), findsOneWidget);
    expect(find.text('CLB CLVK - Cầu Lông Vui Khỏe'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsNothing);
    expect(find.text('Xem nhóm'), findsNothing);
    expect(find.text('Thu hồi'), findsOneWidget);
  });

  testWidgets('club card does not overflow on a narrow screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      harness(
        tab: 'managing',
        textScaler: const TextScaler.linear(1.2),
        managedClubs: [
          sampleClub(
            id: 'narrow',
            name: 'Nhóm cầu lông có tên tương đối dài',
            memberCount: 128,
            defaultVenue: const ClubVenue(
              name: 'Sân cầu lông trung tâm thành phố',
              address: 'Hà Nội',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sân cầu lông trung tâm thành phố'), findsOneWidget);
  });

  testWidgets('admin sees pending groups and rejection requires a reason', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 1400)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      harness(
        tab: 'managing',
        user: admin,
        pending: [sampleClub(id: 'pending', name: 'Nhóm chờ duyệt')],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nhóm chờ duyệt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Duyệt nhóm'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pump();

    expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
  });
}
