import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeFavoriteRepository implements FavoriteRepository {
  _FakeFavoriteRepository({this.summaryResult = const FavoriteSummary()});

  FavoriteSummary summaryResult;
  Exception? summaryError;
  Exception? addError;
  Exception? removeError;
  Completer<void>? pendingAdd;
  final calls = <String>[];

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async {
    if (summaryError case final error?) throw error;
    return summaryResult;
  }

  @override
  Future<void> add(FavoriteType type, String targetId) async {
    calls.add('add:${type.wireValue}:$targetId');
    if (addError case final error?) throw error;
    await pendingAdd?.future;
  }

  @override
  Future<void> remove(FavoriteType type, String targetId) async {
    calls.add('remove:${type.wireValue}:$targetId');
    if (removeError case final error?) throw error;
  }
}

Widget _app({
  required FavoriteSummary summary,
  FavoriteType type = FavoriteType.venue,
  String targetId = 'v1',
  bool overlay = true,
  bool showCount = true,
  bool signedIn = true,
  Locale locale = const Locale('en'),
  _FakeFavoriteRepository? repository,
  VoidCallback? onCardTap,
}) {
  final activeRepository =
      repository ?? _FakeFavoriteRepository(summaryResult: summary);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) {
          final favorite = FavoriteButton(
            type: type,
            targetId: targetId,
            initialIsFavorite: summary.isFavorite,
            overlay: overlay,
            showCount: showCount,
          );
          return Scaffold(
            body: onCardTap == null
                ? favorite
                : InkWell(onTap: onCardTap, child: favorite),
          );
        },
      ),
      GoRoute(
        path: '/favorites',
        builder: (_, state) => Scaffold(
          body: Text('favorites-${state.uri.queryParameters['type']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      favoriteRepositoryProvider.overrideWithValue(activeRepository),
      isSignedInProvider.overrideWithValue(signedIn),
    ],
    child: MaterialApp.router(
      locale: locale,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'renders active state with filled heart icon, destructive red color, and count',
    (tester) async {
      await tester.pumpWidget(
        _app(
          summary: const FavoriteSummary(
            isFavorite: true,
            favoriteCount: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsOneWidget);

      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.icon, AppIcons.favoriteFilled);
      expect(iconWidget.color, AppColors.destructive);
      expect(find.text('5'), findsOneWidget);
    },
  );

  testWidgets('renders inactive state with outline heart icon and count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(
          favoriteCount: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byType(Icon);
    expect(iconFinder, findsOneWidget);

    final iconWidget = tester.widget<Icon>(iconFinder);
    expect(iconWidget.icon, AppIcons.favorite);
    expect(iconWidget.color, Colors.white); // overlay is true
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides count when showCount is false', (tester) async {
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(
          isFavorite: true,
          favoriteCount: 12,
        ),
        showCount: false,
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byType(Icon);
    expect(iconFinder, findsOneWidget);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('hides count when favoriteCount is 0', (tester) async {
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byType(Icon);
    expect(iconFinder, findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows a success toast after adding a favorite', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
        locale: const Locale('vi'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu vào Yêu thích'), findsOneWidget);
    expect(find.text('Xem danh sách'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const Key('favorite-toast-icon'))).icon,
      AppIcons.favoriteFilled,
    );

    final snackBarFinder = find.byType(SnackBar);
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.action, isNull);
    expect(tester.getSize(snackBarFinder).height, lessThanOrEqualTo(64));

    final surface = tester.widget<Container>(
      find.byKey(const Key('favorite-toast-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.light.colorScheme.inverseSurface);
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.xl));

    final badge = tester.widget<Container>(
      find.byKey(const Key('favorite-toast-badge')),
    );
    final badgeDecoration = badge.decoration! as BoxDecoration;
    expect(
      badgeDecoration.color,
      AppColors.destructive.withValues(alpha: 0.16),
    );
    expect(
      tester.getSize(find.byKey(const Key('favorite-toast-badge'))),
      const Size.square(32),
    );
  });

  testWidgets('shows a success toast after removing a favorite', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(isFavorite: true, favoriteCount: 1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Removed from Favorites'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const Key('favorite-toast-icon'))).icon,
      AppIcons.favorite,
    );

    final badge = tester.widget<Container>(
      find.byKey(const Key('favorite-toast-badge')),
    );
    final badgeDecoration = badge.decoration! as BoxDecoration;
    expect(
      badgeDecoration.color,
      AppTheme.light.colorScheme.onInverseSurface.withValues(alpha: 0.1),
    );
  });

  testWidgets('undo adds the removed favorite again', (tester) async {
    final repository = _FakeFavoriteRepository(
      summaryResult: const FavoriteSummary(
        isFavorite: true,
        favoriteCount: 1,
      ),
    );
    await tester.pumpWidget(
      _app(
        summary: repository.summaryResult,
        type: FavoriteType.tournament,
        targetId: 't1',
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['remove:TOURNAMENT:t1', 'add:TOURNAMENT:t1']);
    expect(find.text('Saved to Favorites'), findsOneWidget);
  });

  testWidgets('reports a type-specific add failure and restores state', (
    tester,
  ) async {
    final repository = _FakeFavoriteRepository()..addError = Exception('no');
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Could not add to favorites'), findsOneWidget);
    expect(find.byIcon(AppIcons.favorite), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const Key('favorite-toast-icon'))).icon,
      AppIcons.error,
    );
  });

  testWidgets('blocks repeated taps while a write is pending', (tester) async {
    final repository = _FakeFavoriteRepository()
      ..pendingAdd = Completer<void>();
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(repository.calls, ['add:VENUE:v1']);
    repository.pendingAdd!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('uses browse state if loading the summary fails', (tester) async {
    final repository = _FakeFavoriteRepository()
      ..summaryError = Exception('summary unavailable');
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(isFavorite: true),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(repository.calls, ['remove:VENUE:v1']);
    expect(find.text('Removed from Favorites'), findsOneWidget);
  });

  testWidgets('does not invoke the surrounding card tap', (tester) async {
    var cardTaps = 0;
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
        onCardTap: () => cardTaps++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(FavoriteButton),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(cardTaps, 0);
  });

  testWidgets('hides the favorite control for guests', (tester) async {
    await tester.pumpWidget(
      _app(summary: const FavoriteSummary(), signedIn: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.byIcon(AppIcons.favorite), findsNothing);
  });

  testWidgets('view-list action opens the matching favorite type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        summary: const FavoriteSummary(),
        type: FavoriteType.club,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View list'));
    await tester.pumpAndSettle();

    expect(find.text('favorites-CLUB'), findsOneWidget);
  });
}
