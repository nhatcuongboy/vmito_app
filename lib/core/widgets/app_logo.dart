import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Reusable application logo component.
///
/// Combines the shuttlecock icon (`assets/icons/main-logo.png`) with two stylized
/// text lines beside it:
/// - Brand text: `"vmito"` with the signature brand-green dot on the letter 'i'.
/// - Slogan text: Localized uppercase slogan using Montserrat font styling.
///
/// Adapts automatically to light mode and dark mode, and scales all typography
/// and geometry proportionally based on [height].
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 78.0,
    this.slogan,
    this.showSlogan = true,
    this.showGreenDot = true,
    this.textColor,
    this.sloganColor,
    this.dotColor,
    this.vmitoFontSize,
    this.sloganFontSize,
    this.semanticLabel,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textCrossAxisAlignment = CrossAxisAlignment.center,
  });

  /// Design canvas reference height (1909×824) used to calculate proportional
  /// typography and spacing.
  static const double _kReferenceCanvasHeight = 824.0;
  static const double _kReferenceVmitoFontSize = 490.0;
  static const double _kReferenceSloganFontSize = 68.0;

  /// Overall height of the logo widget in logical pixels. Defaults to `78.0`.
  final double height;

  /// Custom slogan text override. If omitted, uses the localized
  /// [AppLocalizations.appSlogan].
  final String? slogan;

  /// Whether to render the slogan line beneath the brand text. Defaults to `true`.
  final bool showSlogan;

  /// Whether to render the signature brand-green dot on the letter 'i' in `"vmito"`.
  /// Defaults to `true`.
  final bool showGreenDot;

  /// Text color override for the `"vmito"` brand line.
  ///
  /// Defaults to `#0C1F33` in light mode and `#FFFFFF` in dark mode.
  final Color? textColor;

  /// Text color override for the slogan line.
  ///
  /// Defaults to `#2C415B` in light mode and `#E0E0E0` in dark mode.
  final Color? sloganColor;

  /// Dot color override for the 'i' dot.
  ///
  /// Defaults to [AppColors.brand] (`#179B3A`) in light mode and
  /// [AppColors.brandDark] (`#1EC84B`) in dark mode.
  final Color? dotColor;

  /// Custom font size override for the `"vmito"` brand text.
  /// If omitted, scales proportionally to [height].
  final double? vmitoFontSize;

  /// Custom font size override for the slogan text.
  /// If omitted, scales proportionally to [height].
  final double? sloganFontSize;

  /// Accessibility semantic label. Defaults to the localized app name.
  final String? semanticLabel;

  /// Main axis size of the containing [Row]. Defaults to [MainAxisSize.min].
  final MainAxisSize mainAxisSize;

  /// Cross axis alignment of the containing [Row]. Defaults to [CrossAxisAlignment.center].
  final CrossAxisAlignment crossAxisAlignment;

  /// Cross axis alignment of the text column containing `"vmito"` and the slogan.
  /// Defaults to [CrossAxisAlignment.center] to match the original logo composition.
  final CrossAxisAlignment textCrossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // Proportional dimensions derived from the reference canvas
    final scale = height / _kReferenceCanvasHeight;
    final iconSpacing = height * 0.055;
    final effectiveVmitoFontSize =
        vmitoFontSize ?? (_kReferenceVmitoFontSize * scale);
    final effectiveSloganFontSize = sloganFontSize ??
        ((_kReferenceSloganFontSize * scale).clamp(6.0, 24.0));
    final sloganLetterSpacing = effectiveSloganFontSize * 0.08;
    final textSpacing = height * 0.035;

    // Theme-adaptive colors
    final effectiveTextColor = textColor ??
        (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0C1F33));
    final effectiveSloganColor = sloganColor ??
        (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C415B));
    final effectiveDotColor = dotColor ??
        (isDark ? AppColors.brandDark : AppColors.brand);

    final vmitoTextStyle = TextStyle(
      fontFamily: 'Poppins',
      fontFamilyFallback: const ['Google Sans', 'Roboto', 'sans-serif'],
      fontSize: effectiveVmitoFontSize,
      fontWeight: FontWeight.w800,
      color: effectiveTextColor,
      letterSpacing: -effectiveVmitoFontSize * 0.02,
      height: 1.0,
    );

    final sloganText =
        (slogan ?? l10n?.appSlogan ?? 'KẾT NỐI ĐAM MÊ - NÂNG TẦM TRẢI NGHIỆM')
            .toUpperCase();
    final sloganTextStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      fontSize: effectiveSloganFontSize,
      fontWeight: FontWeight.w600,
      color: effectiveSloganColor,
      letterSpacing: sloganLetterSpacing,
      height: 1.1,
    );

    return Semantics(
      label: semanticLabel ?? l10n?.appName ?? 'Vmito',
      child: Row(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Image.asset(
            'assets/icons/main-logo.png',
            height: height,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          SizedBox(width: iconSpacing),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: textCrossAxisAlignment,
            children: [
              if (showGreenDot)
                _VmitoTextWithDot(
                  style: vmitoTextStyle,
                  dotColor: effectiveDotColor,
                )
              else
                Text(
                  'vmito',
                  style: vmitoTextStyle,
                ),
              if (showSlogan) ...[
                SizedBox(height: textSpacing),
                Text(
                  sloganText,
                  style: sloganTextStyle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders `"vmito"` with the signature brand-green dot accurately positioned
/// directly above the stem of the letter 'i'.
class _VmitoTextWithDot extends StatelessWidget {
  const _VmitoTextWithDot({
    required this.style,
    required this.dotColor,
  });

  final TextStyle style;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    // Use dotless i (\u0131) so the native dark dot is not painted,
    // allowing the custom brand-green circular dot to be drawn seamlessly.
    final textPainter = TextPainter(
      text: TextSpan(text: 'vm\u0131to', style: style),
      textDirection: textDirection,
    )..layout();

    return Semantics(
      label: 'vmito',
      child: CustomPaint(
        size: textPainter.size,
        painter: _VmitoDotPainter(
          textPainter: textPainter,
          style: style,
          dotColor: dotColor,
          textDirection: textDirection,
        ),
      ),
    );
  }
}

class _VmitoDotPainter extends CustomPainter {
  _VmitoDotPainter({
    required this.textPainter,
    required this.style,
    required this.dotColor,
    required this.textDirection,
  });

  final TextPainter textPainter;
  final TextStyle style;
  final Color dotColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    textPainter.paint(canvas, Offset.zero);

    // Measure 'vm' and 'vm\u0131' to calculate the exact horizontal center of 'i'
    final vmPainter = TextPainter(
      text: TextSpan(text: 'vm', style: style),
      textDirection: textDirection,
    )..layout();
    final vmiPainter = TextPainter(
      text: TextSpan(text: 'vm\u0131', style: style),
      textDirection: textDirection,
    )..layout();

    final iCenterX = (vmPainter.width + vmiPainter.width) / 2;

    final fontSize = style.fontSize ?? 20.0;
    final dotRadius = fontSize * 0.088;

    // Calculate the top of the lowercase 'i' stem from alphabetic baseline.
    // In Poppins/sans-serif typography, lowercase x-height is ~0.53 of fontSize.
    final baseline =
        textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final stemTop = baseline - (fontSize * 0.53);

    // Position the dot above the stem of 'i' with balanced optical spacing
    final gap = dotRadius * 0.70;
    final dotCenterY = stemTop - gap - dotRadius;

    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(iCenterX, dotCenterY), dotRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _VmitoDotPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.dotColor != dotColor;
  }
}
