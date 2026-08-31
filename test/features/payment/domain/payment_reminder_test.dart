import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/domain/form/reminder_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

void main() {
  group('PaymentReminder model', () {
    test('parses full JSON from backend contract', () {
      final json = {
        'id': 'rem-123',
        'type': 'CUSTOM',
        'creatorId': 'u-creator',
        'recipientId': 'u-recipient',
        'sessionId': 's-456',
        'amount': 150000,
        'note': 'Court fee for March',
        'status': 'AWAITING_CONFIRMATION',
        'reminderCount': 2,
        'lastRemindedAt': '2026-08-30T10:00:00.000Z',
        'resolvedAt': null,
        'proofImageUrl': 'https://example.com/proof.jpg',
        'proofNotes': 'Transferred via Vietcombank',
        'createdAt': '2026-08-29T10:00:00.000Z',
        'updatedAt': '2026-08-30T10:00:00.000Z',
        'creator': {
          'id': 'u-creator',
          'name': 'Host Alice',
          'email': 'alice@example.com',
          'image': 'https://example.com/alice.jpg',
          'gender': 'FEMALE',
        },
        'recipient': {
          'id': 'u-recipient',
          'name': 'Player Bob',
          'email': 'bob@example.com',
          'image': 'https://example.com/bob.jpg',
          'gender': 'MALE',
        },
        'session': {
          'id': 's-456',
          'name': 'Friday Night Match',
        },
        'payments': [
          {
            'payment': {
              'id': 'pay-1',
              'status': 'SUBMITTED',
              'amount': 150000,
              'proofImageUrl': 'https://example.com/proof.jpg',
              'proofNotes': 'Transferred',
              'hostNotes': null,
              'sessionId': 's-456',
            },
          },
        ],
      };

      final reminder = PaymentReminder.fromJson(json);

      expect(reminder.id, 'rem-123');
      expect(reminder.type, PaymentReminderType.custom);
      expect(reminder.status, PaymentReminderStatus.awaitingConfirmation);
      expect(reminder.amount, 150000);
      expect(reminder.note, 'Court fee for March');
      expect(reminder.reminderCount, 2);
      expect(reminder.creator?.name, 'Host Alice');
      expect(reminder.recipient?.name, 'Player Bob');
      expect(reminder.session?.name, 'Friday Night Match');
      expect(reminder.paymentIds, ['pay-1']);
      expect(reminder.linkedPayments.length, 1);
      expect(reminder.linkedPayments.first.status, PaymentStatus.submitted);
    });

    test('parses minimal JSON with default fallbacks', () {
      final json = {
        'id': 'rem-min',
        'reminderCount': 0,
      };

      final reminder = PaymentReminder.fromJson(json);

      expect(reminder.id, 'rem-min');
      expect(reminder.type, PaymentReminderType.singlePayment);
      expect(reminder.status, PaymentReminderStatus.pending);
      expect(reminder.amount, 0);
      expect(reminder.reminderCount, 0);
      expect(reminder.paymentIds, isEmpty);
      expect(reminder.creator, isNull);
      expect(reminder.recipient, isNull);
    });
  });

  group('Reminder reactive forms', () {
    test('createCustomReminderForm validates required fields', () {
      final form = createCustomReminderForm();
      expect(form.valid, isFalse);

      form.control(CreateCustomReminderControl.recipientUserId).value = 'u-1';
      form.control(CreateCustomReminderControl.amount).value = 50000;
      form.control(CreateCustomReminderControl.note).value = 'Test note';
      expect(form.valid, isTrue);

      form.control(CreateCustomReminderControl.amount).value = 0;
      expect(form.valid, isFalse);
    });

    test('createMarkPaidForm defaults to bankTransfer and validates', () {
      final form = createMarkPaidForm();
      expect(form.valid, isTrue);
      expect(
        form.control(MarkPaidControl.paymentMethod).value,
        PaymentMethod.bankTransfer,
      );

      form.control(MarkPaidControl.proofImageUrl).value = 'https://img.com/1';
      form.control(MarkPaidControl.proofNotes).value = 'Notes';
      expect(form.valid, isTrue);
    });

    test('createRejectReminderForm validates optional notes', () {
      final form = createRejectReminderForm();
      expect(form.valid, isTrue);

      form.control(RejectReminderControl.hostNotes).value = 'Wrong amount';
      expect(form.valid, isTrue);
    });
  });
}
