import 'package:flutter/material.dart';

/// Renders user-generated text while preserving the platform emoji fallback.
///
/// Emoji glyphs deliberately do not use an app-bundled font. Flutter can then
/// resolve them through the system color-emoji font instead of the monochrome
/// Noto Emoji font previously registered by the app.
class EmojiSafeText extends StatelessWidget {
  const EmojiSafeText(
    this.data, {
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    data,
    style: style,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.clip,
    softWrap: softWrap,
    textAlign: textAlign,
    semanticsLabel: data,
  );
}
