import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/shared/widgets/level_badge_picker.dart';

void main() {
  testWidgets('selects ordered levels with the matching band colours', (
    tester,
  ) async {
    final emitted = <List<int>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: _PickerHost(
            onChanged: emitted.add,
          ),
        ),
      ),
    );

    expect(_background(tester, 'level-9-badge'), isNull);
    expect(_background(tester, 'level-3-badge'), isNull);

    await tester.tap(find.byKey(const ValueKey('level-9')));
    await tester.pump();
    expect(emitted.last, [9]);
    expect(_background(tester, 'level-9-badge'), AppColors.success);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('level-9')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('level-3')));
    await tester.pump();
    expect(emitted.last, [9, 3]);
    expect(_background(tester, 'level-3-badge'), AppColors.warning);
  });

  testWidgets('all levels clears the selected badges', (tester) async {
    final emitted = <List<int>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: _PickerHost(
            initialLevels: const [9],
            onChanged: emitted.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('all-levels-option')));
    await tester.pump();

    expect(emitted.last, isEmpty);
    expect(_background(tester, 'all-levels-badge'), AppColors.success);
    expect(_background(tester, 'level-9-badge'), isNull);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-levels-option')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });
}

Color? _background(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey(key)));
  return (container.decoration! as BoxDecoration).color;
}

class _PickerHost extends StatefulWidget {
  const _PickerHost({this.initialLevels = const [], required this.onChanged});

  final List<int> initialLevels;
  final ValueChanged<List<int>> onChanged;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  late List<int> _levels = widget.initialLevels;

  @override
  Widget build(BuildContext context) => LevelBadgePicker(
    selectedLevels: _levels,
    allLevelsLabel: 'Tất cả trình độ',
    allLevelsKey: const Key('all-levels-option'),
    onChanged: (levels) {
      setState(() => _levels = levels);
      widget.onChanged(levels);
    },
  );
}
