import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

void main() {
  testWidgets('opens at the tapped image and navigates next and previous', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-lightbox'),
                onPressed: () {
                  unawaited(
                    showAppLightbox(
                      context,
                      images: const [
                        'https://image/1.jpg',
                        'https://image/2.jpg',
                        'https://image/3.jpg',
                      ],
                      initialIndex: 1,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-lightbox')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('2/3'), findsOneWidget);
    final closeButton = tester.getTopLeft(
      find.byKey(const Key('lightbox-close-button')),
    );
    expect(closeButton.dx, greaterThan(400));
    expect(find.byKey(const Key('lightbox-previous-button')), findsOneWidget);
    expect(find.byKey(const Key('lightbox-next-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lightbox-next-button')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lightbox-previous-button')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2/3'), findsOneWidget);
  });
}
