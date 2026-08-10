import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/registration/domain/registration_player_draft.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  group('RegistrationPlayerDraft.toRegisterJson', () {
    test('the "me" row carries userId', () {
      const draft = RegistrationPlayerDraft(
        isMe: true,
        name: 'Cường',
        level: 4,
      );

      expect(draft.toRegisterJson('u1')['userId'], 'u1');
    });

    test('a guest row omits userId entirely', () {
      // Not `null` — the key must be absent. Sending any id on a guest row
      // trips the backend's "already registered" guard, which is exactly what
      // add-guest has to avoid.
      const draft = RegistrationPlayerDraft(
        isMe: false,
        name: 'Bạn của Cường',
        level: 4,
      );

      expect(draft.toRegisterJson('u1').containsKey('userId'), isFalse);
    });

    test('a "me" row with no signed-in id still omits userId', () {
      const draft = RegistrationPlayerDraft(isMe: true, name: 'X', level: 1);

      expect(draft.toRegisterJson(null).containsKey('userId'), isFalse);
    });

    test('trims name and phone', () {
      const draft = RegistrationPlayerDraft(
        isMe: true,
        name: '  Cường  ',
        phone: '  0901234567 ',
        level: 4,
      );

      final json = draft.toRegisterJson('u1');
      expect(json['name'], 'Cường');
      expect(json['phone'], '0901234567');
    });

    test('blank optional fields are omitted, not sent empty', () {
      const draft = RegistrationPlayerDraft(
        isMe: true,
        name: 'Cường',
        phone: '   ',
        levelDescription: '  ',
        level: 4,
      );

      final json = draft.toRegisterJson('u1');
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('levelDescription'), isFalse);
    });

    test('level is omitted while unchosen', () {
      const draft = RegistrationPlayerDraft(isMe: true, name: 'Cường');

      expect(draft.toRegisterJson('u1').containsKey('level'), isFalse);
    });

    test('never sends playerNumber — the backend assigns it', () {
      const draft = RegistrationPlayerDraft(
        isMe: true,
        name: 'Cường',
        level: 4,
      );

      expect(draft.toRegisterJson('u1').containsKey('playerNumber'), isFalse);
    });

    test('gender goes out as the wire enum', () {
      const cases = {
        Gender.male: 'MALE',
        Gender.female: 'FEMALE',
        Gender.other: 'OTHER',
      };

      for (final entry in cases.entries) {
        final draft = RegistrationPlayerDraft(
          isMe: true,
          name: 'X',
          gender: entry.key,
          level: 1,
        );
        expect(draft.toRegisterJson('u1')['gender'], entry.value);
      }
    });
  });

  test('copyWith keeps isMe — a guest row can never become the me row', () {
    const guest = RegistrationPlayerDraft(isMe: false);

    expect(guest.copyWith(name: 'X').isMe, isFalse);
  });
}
