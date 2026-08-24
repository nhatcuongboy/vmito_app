import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/feedback/domain/feedback.dart';

void main() {
  test('parses and serializes a complete feedback item', () {
    final item = FeedbackItem.fromJson({
      'id': 'feedback-1',
      'type': 'BUG_REPORT',
      'status': 'IN_PROGRESS',
      'title': 'Crash on launch',
      'description': 'The app closes immediately.',
      'imageUrl': 'https://example.com/screenshot.jpg',
      'imagePublicId': 'feedback/screenshot',
      'adminNote': 'Investigating',
      'createdAt': '2026-08-25T03:00:00.000Z',
    });

    expect(item.type, FeedbackType.bugReport);
    expect(item.status, FeedbackStatus.inProgress);
    expect(item.adminNote, 'Investigating');
    expect(item.toJson(), {
      'id': 'feedback-1',
      'type': 'BUG_REPORT',
      'status': 'IN_PROGRESS',
      'title': 'Crash on launch',
      'description': 'The app closes immediately.',
      'imageUrl': 'https://example.com/screenshot.jpg',
      'imagePublicId': 'feedback/screenshot',
      'adminNote': 'Investigating',
      'createdAt': '2026-08-25T03:00:00.000Z',
    });
  });

  test('keeps unknown wire enum values safe', () {
    final item = FeedbackItem.fromJson({
      'id': 'feedback-2',
      'type': 'FEATURE_REQUEST',
      'status': 'REOPENED',
      'title': 'New idea',
      'description': 'Please add this.',
      'createdAt': 'not-a-date',
    });

    expect(item.type, FeedbackType.unknown);
    expect(item.status, FeedbackStatus.unknown);
    expect(item.createdAt.millisecondsSinceEpoch, 0);
  });

  test('feedback draft includes attachment only when supplied', () {
    const plain = FeedbackDraft(
      type: FeedbackType.contact,
      title: 'Hello',
      description: 'I need help.',
    );
    const attached = FeedbackDraft(
      type: FeedbackType.bugReport,
      title: 'Bug',
      description: 'Details',
      attachment: FeedbackAttachment(
        imageUrl: 'https://example.com/image.jpg',
        imagePublicId: 'feedback/image',
      ),
    );

    expect(plain.toJson(), {
      'type': 'CONTACT',
      'title': 'Hello',
      'description': 'I need help.',
    });
    expect(attached.toJson(), containsPair('imagePublicId', 'feedback/image'));
  });
}
