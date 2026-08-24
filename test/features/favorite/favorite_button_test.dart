import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/favorite/application/favorite_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeFavoriteRepository implements FavoriteRepository {
  _FakeFavoriteRepository({this.summaryResult = const FavoriteSummary()});

  FavoriteSummary summaryResult;

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async =>
      summaryResult;

  @override
  Future<void> add(FavoriteType type, String targetId) async {}

  @override
  Future<void> remove(FavoriteType type, String targetId) async {}
}

Widget _app({
  required FavoriteSummary summary,
  FavoriteType type = FavoriteType.venue,
  String targetId = 'v1',
  bool overlay = true,
  bool showCount = true,
}) {
  final repository = _FakeFavoriteRepository(summaryResult: summary);
  return ProviderScope(
    overrides: [
      favoriteRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FavoriteButton(
          type: type,
          targetId: targetId,
          overlay: overlay,
          showCount: showCount,
        ),
      ),
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
          isFavorite: false,
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
        summary: const FavoriteSummary(
          isFavorite: false,
          favoriteCount: 0,
        ),
        showCount: true,
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byType(Icon);
    expect(iconFinder, findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
