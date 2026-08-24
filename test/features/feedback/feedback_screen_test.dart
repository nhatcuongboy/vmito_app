import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/feedback/application/feedback_controller.dart';
import 'package:vmito_app/features/feedback/data/feedback_image_picker.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';
import 'package:vmito_app/features/feedback/presentation/feedback_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeFeedbackController extends FeedbackController {
  _FakeFeedbackController(this.initialState);

  final FeedbackState initialState;
  FeedbackDraft? submittedDraft;
  PickedFeedbackImage? submittedImage;

  @override
  FeedbackState build() => initialState;

  @override
  Future<void> load() async {}

  @override
  Future<bool> submit({
    required FeedbackDraft draft,
    PickedFeedbackImage? image,
  }) async {
    submittedDraft = draft;
    submittedImage = image;
    return true;
  }
}

Widget _app(
  _FakeFeedbackController controller, {
  FeedbackImagePicker? picker,
}) => ProviderScope(
  overrides: [
    feedbackControllerProvider.overrideWith(() => controller),
    if (picker != null) feedbackImagePickerProvider.overrideWithValue(picker),
  ],
  child: MaterialApp(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const FeedbackScreen(),
  ),
);

Finder _editable(String fieldKey) => find.descendant(
  of: find.byKey(ValueKey(fieldKey)),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('marks blank contact fields touched and preserves tab drafts', (
    tester,
  ) async {
    final controller = _FakeFeedbackController(const FeedbackState());
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('feedback-contact-submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin bắt buộc'), findsNWidgets(2));

    await tester.enterText(
      _editable('feedback-contact-title-field'),
      'Liên hệ của tôi',
    );
    await tester.enterText(
      _editable('feedback-contact-description-field'),
      'Nội dung liên hệ',
    );
    await tester.tap(find.text('Báo cáo lỗi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _editable('feedback-bug-title-field'),
      'Lỗi hiển thị',
    );
    await tester.tap(find.text('Liên hệ'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(
            _editable('feedback-contact-title-field'),
          )
          .controller
          .text,
      'Liên hệ của tôi',
    );
  });

  testWidgets('picks an image, submits bug report and clears its form', (
    tester,
  ) async {
    final image = PickedFeedbackImage(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      filename: 'bug.png',
    );
    final controller = _FakeFeedbackController(const FeedbackState());
    await tester.pumpWidget(_app(controller, picker: () async => image));
    await tester.pump();
    await tester.tap(find.text('Báo cáo lỗi'));
    await tester.pumpAndSettle();

    await tester.enterText(_editable('feedback-bug-title-field'), 'Bug');
    await tester.enterText(
      _editable('feedback-bug-description-field'),
      'Chi tiết lỗi',
    );
    await tester.tap(find.byKey(const ValueKey('feedback-pick-image')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('feedback-image-preview')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('feedback-bug-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback-bug-submit')));
    await tester.pumpAndSettle();

    expect(controller.submittedDraft?.type, FeedbackType.bugReport);
    expect(controller.submittedImage?.filename, 'bug.png');
    expect(
      tester
          .widget<EditableText>(
            _editable('feedback-bug-title-field'),
          )
          .controller
          .text,
      isEmpty,
    );
    expect(find.byKey(const ValueKey('feedback-image-preview')), findsNothing);
    expect(
      find.text('Cảm ơn bạn! Chúng tôi sẽ phản hồi sớm nhất có thể.'),
      findsOneWidget,
    );
  });

  testWidgets('renders feedback history with status and admin note', (
    tester,
  ) async {
    final controller = _FakeFeedbackController(
      FeedbackState(
        items: [
          FeedbackItem(
            id: 'feedback-1',
            type: FeedbackType.contact,
            status: FeedbackStatus.resolved,
            title: 'Cần hỗ trợ',
            description: 'Nội dung phản hồi',
            adminNote: 'Đã liên hệ người dùng',
            createdAt: DateTime.utc(2026, 8, 25),
          ),
        ],
      ),
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Cần hỗ trợ'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Cần hỗ trợ'), findsOneWidget);
    expect(find.text('Đã giải quyết'), findsOneWidget);
    expect(
      find.text('Ghi chú từ quản trị viên: Đã liên hệ người dùng'),
      findsOneWidget,
    );
  });
}
