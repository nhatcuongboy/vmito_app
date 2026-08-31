import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';

void main() {
  test('keeps regular text separate from emoji font spans', () {
    final spans = emojiSafeTextSpans('Khải 🦈 2️⃣');

    expect(spans, hasLength(4));
    expect((spans.first as TextSpan).text, 'Khải ');
    expect((spans.first as TextSpan).style?.fontFamily, isNull);
    expect((spans[1] as TextSpan).text, '🦈');
    expect((spans.last as TextSpan).text, '2️⃣');
    expect(
      (spans.last as TextSpan).style?.fontFamily,
      appEmojiFontFamily,
    );
    expect((spans.last as TextSpan).style?.fontWeight, FontWeight.w400);
  });

  testWidgets('renders an emoji user name without changing app typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmojiSafeText(
            'Khải 🦈',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    expect(find.text('Khải 🦈', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
