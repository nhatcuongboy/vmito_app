import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/theme/app_typography.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  group('AppTypography', () {
    for (final entry in <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      test('${entry.key} theme exposes the semantic type scale', () {
        final theme = entry.value;
        final text = theme.textTheme;
        final nativeText = ThemeData(
          brightness: theme.brightness,
          colorScheme: theme.colorScheme,
          useMaterial3: true,
        ).textTheme;

        expect(text.bodyLarge?.fontFamily, nativeText.bodyLarge?.fontFamily);
        expect(
          text.bodyLarge?.fontFamilyFallback,
          nativeText.bodyLarge?.fontFamilyFallback,
        );
        _expectStyle(text.headlineSmall, 24, 32, FontWeight.w700);
        _expectStyle(text.titleLarge, 22, 28, FontWeight.w700);
        _expectStyle(text.titleMedium, 16, 24, FontWeight.w600);
        _expectStyle(text.titleSmall, 14, 20, FontWeight.w600);
        _expectStyle(text.bodyLarge, 16, 24, FontWeight.w400);
        _expectStyle(text.bodyMedium, 14, 20, FontWeight.w400);
        _expectStyle(text.bodySmall, 12, 16, FontWeight.w400);
        _expectStyle(text.labelLarge, 14, 20, FontWeight.w600);
        _expectStyle(text.labelMedium, 12, 16, FontWeight.w600);
        _expectStyle(text.labelSmall, 11, 16, FontWeight.w500);

        _expectStyle(
          theme.appBarTheme.titleTextStyle,
          20,
          28,
          FontWeight.w700,
        );
        expect(theme.appBarTheme.titleSpacing, 8);
        _expectStyle(
          AppTypography.compactAppBarTitle(text),
          20,
          28,
          FontWeight.w700,
        );
        _expectStyle(
          AppTypography.chipLabel(text, isActive: false),
          13.5,
          18,
          FontWeight.w500,
        );
        _expectStyle(
          AppTypography.chipLabel(text, isActive: true),
          13.5,
          18,
          FontWeight.w600,
        );
      });
    }

    test('component themes use the shared interactive text roles', () {
      final theme = AppTheme.light;
      final states = <WidgetState>{};

      _expectStyle(
        theme.filledButtonTheme.style?.textStyle?.resolve(states),
        15,
        20,
        FontWeight.w600,
      );
      _expectStyle(
        theme.outlinedButtonTheme.style?.textStyle?.resolve(states),
        15,
        20,
        FontWeight.w600,
      );
      _expectStyle(
        theme.textButtonTheme.style?.textStyle?.resolve(states),
        15,
        20,
        FontWeight.w600,
      );
      _expectStyle(theme.inputDecorationTheme.hintStyle, 14, 20, null);
      _expectStyle(theme.inputDecorationTheme.helperStyle, 12, 16, null);
      _expectStyle(theme.inputDecorationTheme.errorStyle, 12, 16, null);
      _expectStyle(theme.tabBarTheme.labelStyle, 14, 20, FontWeight.w600);
      _expectStyle(
        theme.tabBarTheme.unselectedLabelStyle,
        14,
        20,
        FontWeight.w500,
      );
      _expectStyle(theme.dialogTheme.titleTextStyle, 20, 28, FontWeight.w700);
    });

    test(
      'app chrome uses theme-aware brand surfaces and navigation states',
      () {
        for (final (theme, brandSurface, indicatorAlpha) in [
          (AppTheme.light, const Color(0xFFE2F3E8), 0.16),
          (AppTheme.dark, const Color(0xFF183028), 0.20),
        ]) {
          final palette = theme.extension<AppPalette>()!;
          final navigation = theme.navigationBarTheme;

          expect(palette.brandSurface, brandSurface);
          expect(navigation.backgroundColor, theme.colorScheme.surface);
          expect(
            navigation.indicatorColor,
            theme.colorScheme.primary.withValues(alpha: indicatorAlpha),
          );
          expect(
            navigation.iconTheme?.resolve({WidgetState.selected})?.color,
            theme.colorScheme.primary,
          );
          expect(
            navigation.iconTheme?.resolve({})?.color,
            palette.mutedForeground,
          );
          expect(
            navigation.labelTextStyle?.resolve({
              WidgetState.selected,
            })?.fontWeight,
            FontWeight.w600,
          );
          expect(
            navigation.labelTextStyle?.resolve({})?.fontWeight,
            FontWeight.w400,
          );
        }

        expect(
          AppTheme.light.appBarTheme.backgroundColor,
          AppColors.background,
        );
        expect(
          AppTheme.dark.appBarTheme.backgroundColor,
          AppColors.backgroundDark,
        );
      },
    );
  });

  testWidgets(
    'AppBar title stays bold and overflow-safe across locales and text scales',
    (tester) async {
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        return tester.binding.setSurfaceSize(null);
      });

      const titles = <(Locale, String)>[
        (Locale('vi'), 'Tìm kèo cầu lông gần đây có tên rất dài'),
        (
          Locale('en'),
          'Find nearby badminton sessions with a very long title',
        ),
        (Locale('zh'), '查找附近名称很长的羽毛球活动'),
      ];

      for (final width in const [320.0, 360.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        for (final scale in const [1.0, 1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final (locale, title) in titles) {
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                theme: AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  appBar: AppBar(
                    leading: const IconButton(
                      onPressed: null,
                      icon: Icon(AppIcons.menu),
                    ),
                    title: Text(title),
                    actions: const [
                      IconButton(onPressed: null, icon: Icon(AppIcons.search)),
                      IconButton(onPressed: null, icon: Icon(AppIcons.login)),
                    ],
                  ),
                ),
              ),
            );

            final defaultTextStyle = DefaultTextStyle.of(
              tester.element(find.text(title)),
            );
            final effectiveStyle = defaultTextStyle.style;
            expect(effectiveStyle.fontSize, 20);
            expect(effectiveStyle.fontWeight, FontWeight.w700);
            expect(defaultTextStyle.softWrap, isFalse);
            expect(defaultTextStyle.overflow, TextOverflow.ellipsis);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}

void _expectStyle(
  TextStyle? style,
  double fontSize,
  double lineHeight,
  FontWeight? fontWeight,
) {
  expect(style, isNotNull);
  expect(style?.fontSize, fontSize);
  expect(style?.height, closeTo(lineHeight / fontSize, 0.0001));
  if (fontWeight != null) expect(style?.fontWeight, fontWeight);
  expect(style?.letterSpacing, 0);
}
