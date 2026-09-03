import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

Widget _buildLogoHarness({
  Locale locale = const Locale('vi'),
  ThemeData? theme,
  AppLogo logo = const AppLogo(),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: Center(
        child: logo,
      ),
    ),
  );
}

void main() {
  group('AppLogo', () {
    testWidgets('renders icon and text elements in Vietnamese by default', (
      tester,
    ) async {
      await tester.pumpWidget(_buildLogoHarness());
      await tester.pumpAndSettle();

      // Check image asset
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(
        (image.image as AssetImage).assetName,
        'assets/icons/main-logo.png',
      );

      // Check brand text semantics
      expect(find.bySemanticsLabel('vmito'), findsOneWidget);

      // Check Vietnamese localized slogan
      expect(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
        findsOneWidget,
      );
    });

    testWidgets('renders localized slogan in English', (tester) async {
      await tester.pumpWidget(
        _buildLogoHarness(locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('vmito'), findsOneWidget);
      expect(
        find.text('CONNECTING PASSION - ELEVATING EXPERIENCE'),
        findsOneWidget,
      );
    });

    testWidgets('renders localized slogan in Chinese', (tester) async {
      await tester.pumpWidget(
        _buildLogoHarness(locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('vmito'), findsOneWidget);
      expect(
        find.text('连接激情 · 提升体验'),
        findsOneWidget,
      );
    });

    testWidgets('displays custom slogan when provided', (tester) async {
      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(slogan: 'Custom Badminton Slogan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM BADMINTON SLOGAN'), findsOneWidget);
    });

    testWidgets('hides slogan when showSlogan is false', (tester) async {
      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(showSlogan: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('vmito'), findsOneWidget);
      expect(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
        findsNothing,
      );
    });

    testWidgets('supports showGreenDot false fallback to standard Text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(showGreenDot: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('vmito'), findsOneWidget);
    });

    testWidgets('adapts text colors in Light Mode and Dark Mode', (tester) async {
      // 1. Light Mode
      await tester.pumpWidget(
        _buildLogoHarness(
          theme: AppTheme.light,
          logo: const AppLogo(showGreenDot: false),
        ),
      );
      await tester.pumpAndSettle();

      final vmitoLight = tester.widget<Text>(find.text('vmito'));
      expect(vmitoLight.style?.color, const Color(0xFF0C1F33));

      final sloganLight = tester.widget<Text>(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
      );
      expect(sloganLight.style?.color, const Color(0xFF2C415B));

      // 2. Dark Mode
      await tester.pumpWidget(
        _buildLogoHarness(
          theme: AppTheme.dark,
          logo: const AppLogo(showGreenDot: false),
        ),
      );
      await tester.pumpAndSettle();

      final vmitoDark = tester.widget<Text>(find.text('vmito'));
      expect(vmitoDark.style?.color, const Color(0xFFFFFFFF));

      final sloganDark = tester.widget<Text>(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
      );
      expect(sloganDark.style?.color, const Color(0xFFE0E0E0));
    });

    testWidgets('allows custom color overrides', (tester) async {
      const customText = Color(0xFFFF0000);
      const customSlogan = Color(0xFF00FF00);

      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(
            showGreenDot: false,
            textColor: customText,
            sloganColor: customSlogan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vmito = tester.widget<Text>(find.text('vmito'));
      expect(vmito.style?.color, customText);

      final slogan = tester.widget<Text>(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
      );
      expect(slogan.style?.color, customSlogan);
    });

    testWidgets('scales properly with different heights without layout error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(height: 120),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.height, 120);
      expect(tester.takeException(), isNull);
    });

    testWidgets('applies proportional font sizes and custom overrides', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildLogoHarness(
          logo: const AppLogo(
            height: 78,
            showGreenDot: false,
            vmitoFontSize: 52,
            sloganFontSize: 11,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vmito = tester.widget<Text>(find.text('vmito'));
      expect(vmito.style?.fontSize, 52);

      final slogan = tester.widget<Text>(
        find.text('KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM'),
      );
      expect(slogan.style?.fontSize, 11);
    });
  });
}
