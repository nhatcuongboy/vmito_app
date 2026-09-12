import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';

void main() {
  testWidgets('leaves emoji rendering to the platform fallback font', (
    tester,
  ) async {
    const name = 'Host To Mồm 🏸🔥';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmojiSafeText(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(name));

    expect(text.data, name);
    expect(text.style?.fontFamily, isNull);
    expect(text.style?.fontFamilyFallback, isNull);
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(tester.takeException(), isNull);
  });
}
