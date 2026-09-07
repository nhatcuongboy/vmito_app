import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';

void main() {
  group('AppTabBar', () {
    testWidgets('renders tabs correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                bottom: AppTabBar(
                  tabs: const [
                    Tab(text: 'Tab 1'),
                    Tab(text: 'Tab 2'),
                    Tab(text: 'Tab 3'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
      expect(find.text('Tab 3'), findsOneWidget);
    });

    testWidgets('calls onTap when tab is tapped', (tester) async {
      var tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: AppTabBar(
                  onTap: (index) => tappedIndex = index,
                  tabs: const [
                    Tab(text: 'First'),
                    Tab(text: 'Second'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Second'));
      await tester.pump();

      expect(tappedIndex, 1);
    });

    testWidgets('has correct preferred size', (tester) async {
      const widget = AppTabBar(
        tabs: [
          Tab(text: 'Test'),
        ],
      );

      expect(widget.preferredSize.height, kTextTabBarHeight);
    });

    testWidgets('applies theme colors correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [
              AppPalette.light(),
            ],
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: DefaultTabController(
            length: 1,
            child: Scaffold(
              appBar: AppBar(
                bottom: const AppTabBar(
                  tabs: [
                    Tab(text: 'Test'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.dividerColor, Colors.transparent);
      expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
    });
  });
}
