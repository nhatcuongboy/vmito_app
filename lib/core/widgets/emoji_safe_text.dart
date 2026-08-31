import 'package:flutter/material.dart';

const appEmojiFontFamily = 'AppEmoji';

/// Renders emoji with the bundled emoji font without changing the font used by
/// the surrounding user-generated text.
///
/// Applying an emoji-only font as an app-wide fallback can make normal letters
/// resolve to missing glyphs. Splitting emoji grapheme clusters keeps regular
/// text on the native UI font and scopes the fallback to emoji only.
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
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: emojiSafeTextSpans(data)),
    style: style,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.clip,
    softWrap: softWrap,
    textAlign: textAlign,
    semanticsLabel: data,
  );
}

@visibleForTesting
List<InlineSpan> emojiSafeTextSpans(String value) {
  final spans = <InlineSpan>[];
  final regular = StringBuffer();

  void flushRegular() {
    if (regular.isEmpty) return;
    spans.add(TextSpan(text: regular.toString()));
    regular.clear();
  }

  for (final grapheme in value.characters) {
    if (_emojiPattern.hasMatch(grapheme)) {
      flushRegular();
      spans.add(
        TextSpan(
          text: grapheme,
          style: const TextStyle(
            fontFamily: appEmojiFontFamily,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    } else {
      regular.write(grapheme);
    }
  }
  flushRegular();
  return spans;
}

final _emojiPattern = RegExp(
  r'[\u{00A9}\u{00AE}\u{203C}\u{2049}\u{20E3}\u{2122}\u{2139}'
  r'\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}'
  r'\u{2B00}-\u{2BFF}\u{1F000}-\u{1FAFF}]',
  unicode: true,
);
