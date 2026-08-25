import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
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

Widget harness({
  required String tab,
  User user = host,
  List<ClubSummary> myClubs = const [],
  List<ClubSummary> pending = const [],
  List<ClubSummary>? managedClubs,
  TextScaler textScaler = TextScaler.noScaling,
}) => ProviderScope(
  overrides: [
    currentUserProvider.overrideWithValue(user),
    canCreateClubProvider.overrideWithValue(false),
    managedClubsProvider.overrideWith(
      (ref) async =>
          managedClubs ?? [sampleClub(id: 'managed', name: 'Nhóm quản lý')],
    ),
    incomingClubRequestsProvider.overrideWith((ref) async => const []),
    pendingClubsProvider.overrideWith((ref) async => pending),
    myClubsProvider.overrideWith((ref) async => myClubs),
    myClubRequestsProvider.overrideWith((ref) async => const []),
  ],
  child: MaterialApp(
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
  testWidgets('managing tab renders managed groups and request section', (
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
    expect(find.text('Yêu cầu tham gia'), findsOneWidget);
    expect(find.text('Không có yêu cầu tham gia đang chờ'), findsOneWidget);
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
    expect(find.text('Nhóm đã tham gia'), findsWidgets);
    expect(find.text('Nhóm sở hữu'), findsNothing);
    expect(find.text('Không có yêu cầu nào đang chờ duyệt'), findsOneWidget);
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
