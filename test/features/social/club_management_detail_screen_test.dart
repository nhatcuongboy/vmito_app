import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/roster/application/roster_controller.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_management_detail_screen.dart';
import 'package:vmito_app/features/social/presentation/widgets/club_members_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  const clubId = 'club-1';

  const sampleClub = ClubSummary(
    id: clubId,
    name: 'Vmito Badminton Club',
    memberCount: 2,
    joinPolicy: 'OPEN',
  );

  const sampleMember = ClubMember(
    id: 'm-1',
    userId: 'u-1',
    name: 'Official Player',
    email: 'official@example.com',
    role: 'MEMBER',
  );

  const sampleGuest = PlayerProfile(
    id: 'g-1',
    name: 'Guest Player',
    phone: '0901234567',
    clubId: clubId,
  );

  Widget createSubject({
    List<ClubMember> members = const [sampleMember],
    List<PlayerProfile> guests = const [sampleGuest],
  }) {
    return ProviderScope(
      overrides: [
        managedClubProvider(clubId).overrideWith((ref) async => sampleClub),
        managedClubsProvider.overrideWith((ref) async => [sampleClub]),
        clubMembersProvider(clubId).overrideWith((ref) async => members),
        clubRosterProvider(clubId).overrideWith((ref) async => guests),
        clubJoinRequestsProvider(clubId).overrideWith((ref) async => const []),
        clubAnnouncementsProvider(clubId).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClubManagementDetailScreen(clubId: clubId),
      ),
    );
  }

  testWidgets(
      'ClubManagementDetailScreen renders 3 tabs without separate guest tab',
      (tester) async {
    tester.view
      ..physicalSize = const Size(430, 1000)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Verify 3 tabs exist
    expect(find.text('Thành viên'), findsWidgets);
    expect(find.text('Yêu cầu'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);

    // Verify "Thành viên khách" is NOT an independent Tab in the AppBar TabBar
    // (It only appears as a filter chip or section header inside ClubMembersTab)
    final tabController = DefaultTabController.of(
      tester.element(find.byType(ClubMembersTab)),
    );
    expect(tabController.length, 3);
  });

  testWidgets(
      'ClubMembersTab displays both official members and guests in All filter',
      (tester) async {
    tester.view
      ..physicalSize = const Size(430, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Verify filter chips
    expect(find.byKey(const Key('club-members-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('club-members-filter-members')), findsOneWidget);
    expect(find.byKey(const Key('club-members-filter-guests')), findsOneWidget);

    // In "All" filter, both members and guests are shown
    expect(find.text('Official Player'), findsOneWidget);
    expect(find.text('Guest Player'), findsOneWidget);

    // Filter to "Members" only
    await tester.tap(find.byKey(const Key('club-members-filter-members')));
    await tester.pumpAndSettle();

    expect(find.text('Official Player'), findsOneWidget);
    expect(find.text('Guest Player'), findsNothing);

    // Filter to "Guests" only
    await tester.tap(find.byKey(const Key('club-members-filter-guests')));
    await tester.pumpAndSettle();

    expect(find.text('Official Player'), findsNothing);
    expect(find.text('Guest Player'), findsOneWidget);
  });

  testWidgets('Add Member dialog has search input and direct guest add button',
      (tester) async {
    tester.view
      ..physicalSize = const Size(430, 1000)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Tap Add Member FAB
    final fab = find.byKey(const Key('club-members-add-fab-club-1'));
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify dialog elements
    expect(find.byKey(const Key('club-member-search')), findsOneWidget);
    expect(
        find.byKey(const Key('club-add-guest-directly-button')), findsOneWidget);
    expect(find.text('Thêm thành viên khách'), findsOneWidget);
  });
}
