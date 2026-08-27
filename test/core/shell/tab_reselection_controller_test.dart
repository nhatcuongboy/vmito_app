import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';

void main() {
  group('TabReselectionController', () {
    test('calls the action registered for the reselected tab', () async {
      final controller = TabReselectionController();
      var calls = 0;
      controller.register(tabIndex: 2, onReselect: () async => calls++);

      await controller.handleReselect(2);

      expect(calls, 1);
    });

    test(
      'does not remove a newer registration when an old one disposes',
      () async {
        final controller = TabReselectionController();
        final removeOld = controller.register(
          tabIndex: 0,
          onReselect: () async {},
        );
        var calls = 0;
        controller.register(tabIndex: 0, onReselect: () async => calls++);

        removeOld();
        await controller.handleReselect(0);

        expect(calls, 1);
      },
    );
  });
}
