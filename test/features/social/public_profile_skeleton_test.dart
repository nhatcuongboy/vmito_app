import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
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
import 'package:vmito_app/l10n/app_localizations.dart';

const _profile = PublicProfile(
  id: 'user-1',
  name: 'Nguyen Player',
  role: 'PLAYER',
  joinedSessionsCount: 3,
);

const _user = User(
  id: 'user-1',
  email: 'player@example.test',
  role: UserRole.player,
  name: 'Nguyen Player',
);

const _bundle = PublicProfileBundle(
  profile: _profile,
  stats: RatingStats(average: 4.5, total: 2),
  ratings: [],
  hostedSessionsCount: 1,
);

const _skeleton = Key('public-profile-skeleton');

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('shows the profile skeleton, not a spinner, while loading', (
    tester,
  ) async {
    final drawerKey = GlobalKey<ScaffoldState>();
    await _pump(
      tester,
      profile: Completer<PublicProfileBundle>().future,
      shellKey: drawerKey,
    );

    expect(find.byKey(_skeleton), findsOneWidget);
    expect(
      find.byKey(const Key('public-profile-skeleton-avatar')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The root profile keeps a working menu button while the request hangs.
    await tester.tap(find.byTooltip('Mở menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(drawerKey.currentState!.isDrawerOpen, isTrue);
  });

  testWidgets('pushed profile skeleton offers a back button', (tester) async {
    await _pump(
      tester,
      profile: Completer<PublicProfileBundle>().future,
      isRootProfile: false,
    );

    expect(find.byKey(_skeleton), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
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

        await _pump(
          tester,
          profile: Completer<PublicProfileBundle>().future,
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
    await _pump(
      tester,
      profile: Completer<PublicProfileBundle>().future,
      theme: ThemeData.light(),
    );

    expect(find.byKey(_skeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('posts tab shows post skeletons while posts are pending', (
    tester,
  ) async {
    await _pump(tester, profile: Future.value(_bundle));
    await tester.pump();

    expect(find.byKey(_skeleton), findsNothing);
    expect(
      find.byKey(const Key('profile-posts-skeleton-list')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('clubs tab shows a club skeleton while clubs are pending', (
    tester,
  ) async {
    final service = _PendingTabsService();
    await _pump(tester, profile: Future.value(_bundle), service: service);
    await tester.pump();

    await tester.tap(find.text('Nhóm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(service.clubsCalls, 1);
    expect(find.byKey(const Key('profile-clubs-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<PublicProfileBundle> profile,
  bool isRootProfile = true,
  ThemeData? theme,
  GlobalKey<ScaffoldState>? shellKey,
  ProfileTabsService? service,
}) async {
  final key = shellKey ?? GlobalKey<ScaffoldState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        publicProfileProvider('user-1').overrideWith((ref) => profile),
        profileTabsServiceProvider.overrideWithValue(
          service ?? _PendingTabsService(),
        ),
        appShellScaffoldKeyProvider.overrideWithValue(key),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Mirrors AppShell: the drawer lives on an outer Scaffold reached
        // through appShellScaffoldKeyProvider.
        home: Scaffold(
          key: key,
          drawer: const Drawer(child: Text('Menu')),
          body: PublicProfileScreen(
            userId: 'user-1',
            isRootProfile: isRootProfile,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Every tab request stays pending so the tab skeletons remain on screen.
class _PendingTabsService implements ProfileTabsService {
  int clubsCalls = 0;

  @override
  Future<SocialPostPage> posts(String id, {int page = 1}) =>
      Completer<SocialPostPage>().future;

  @override
  Future<UserAchievements> achievements(String id) =>
      Completer<UserAchievements>().future;

  @override
  Future<pagination.Page<Session>> hosted(
    String id, {
    int page = 1,
    String filter = 'active',
  }) => Completer<pagination.Page<Session>>().future;

  @override
  Future<List<ClubSummary>> clubs(String id) {
    clubsCalls++;
    return Completer<List<ClubSummary>>().future;
  }

  @override
  Future<pagination.Page<FavoriteTarget>> favorites(
    String type, {
    int page = 1,
  }) => Completer<pagination.Page<FavoriteTarget>>().future;
}
