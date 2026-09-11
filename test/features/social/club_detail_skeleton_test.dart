import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _club = ClubSummary(
  id: 'club-1',
  name: 'Nhóm Cầu Lông Vmito',
  memberCount: 10,
  joinPolicy: 'OPEN',
);

const _skeleton = Key('club-detail-skeleton');

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<ClubSummary> club,
    Future<List<ClubAnnouncement>>? announcements,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clubDetailProvider.overrideWith((ref, id) => club),
          clubAnnouncementsProvider.overrideWith(
            (ref, id) => announcements ?? Future.value(const []),
          ),
          myClubRequestsProvider.overrideWith((ref) async => const []),
          currentUserProvider.overrideWithValue(null),
          isSignedInProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ClubDetailScreen(clubId: 'club-1'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the club skeleton, not a spinner, while loading', (
    tester,
  ) async {
    await pump(tester, club: Completer<ClubSummary>().future);

    expect(find.byKey(_skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final backButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('club-back-button')),
        matching: find.byType(IconButton),
      ),
    );
    expect(backButton.onPressed, isNotNull);
  });

  for (final (size, theme) in [
    (const Size(320, 640), AppTheme.light),
    (const Size(320, 640), AppTheme.dark),
    (const Size(430, 932), AppTheme.light),
    (const Size(430, 932), AppTheme.dark),
  ]) {
    testWidgets(
      'skeleton lays out without overflow at ${size.width.toInt()}dp '
      '(${theme.brightness.name})',
      (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(
          tester,
          club: Completer<ClubSummary>().future,
          theme: theme,
        );

        expect(find.byKey(_skeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('skeleton renders without the app palette extension', (
    tester,
  ) async {
    await pump(
      tester,
      club: Completer<ClubSummary>().future,
      theme: ThemeData.light(),
    );

    expect(find.byKey(_skeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'announcements tab shows a skeleton list while pending, not a spinner',
    (tester) async {
      await pump(
        tester,
        club: Future.value(_club),
        announcements: Completer<List<ClubAnnouncement>>().future,
      );
      await tester.pump();

      expect(find.byKey(_skeleton), findsNothing);
      await tester.tap(find.text('Thông báo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('club-announcements-skeleton-list')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
