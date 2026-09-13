import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

void main() {
  test('player mapping preserves account and usage metadata', () {
    final player = TournamentPlayer.fromJson({
      'id': 'p',
      'name': 'An',
      'code': 'A1',
      'userId': 'u',
      'user': {'name': 'Linked'},
      'notes': 'note',
      'level': 4,
      '_count': {'registrations': 2, 'pairMembers': 3},
    });
    expect(player.matches('linked'), isTrue);
    expect(player.matches(' a1 '), isTrue);
    expect(player.registrationCount, 2);
    expect(player.pairCount, 3);
    expect(player.notes, 'note');
    expect(TournamentPlayer.fromJson({}).id, '');
  });

  test('player validators and payload distinguish omission from clearing', () {
    final form = tournamentPlayerForm();
    addTearDown(form.dispose);
    form.control(ResourceControl.name).value = '   ';
    expect(form.valid, isFalse);
    form.control(ResourceControl.name).value = ' An ';
    form.control(ResourceControl.email).value = 'invalid';
    expect(form.valid, isFalse);
    form.control(ResourceControl.email).value = null;
    form.control(ResourceControl.level).value = 11;
    expect(form.valid, isFalse);
    form.control(ResourceControl.level).value = 1;
    expect(form.valid, isTrue);
    final draft = PlayerDraft.fromForm(form);
    expect(draft.toJson(), {'name': 'An', 'level': 1});
    expect(draft.toJson(update: true)['userId'], isNull);
    expect(draft.toJson(update: true).containsKey('notes'), isTrue);
    expect(draft.toJson().containsKey('notes'), isFalse);
  });

  test('sponsor validates protocol and order; keeps image public ID', () {
    final model = TournamentSponsor.fromJson({
      'id': 's',
      'name': 'Sponsor',
      'logoPublicId': 'asset',
      'displayOrder': 2,
    });
    final form = tournamentSponsorForm(model);
    addTearDown(form.dispose);
    expect(SponsorDraft.fromForm(form).logoPublicId, 'asset');
    form.control(ResourceControl.website).value = 'javascript:alert(1)';
    expect(form.valid, isFalse);
    form.control(ResourceControl.website).value = 'https://example.com';
    form.control(ResourceControl.order).value = -1;
    expect(form.valid, isFalse);
    form.control(ResourceControl.order).value = 0;
    expect(form.valid, isTrue);
    expect(const SponsorDraft(name: 'A').toJson(update: true), {
      'name': 'A',
      'website': null,
      'logo': null,
      'logoPublicId': null,
      'displayOrder': 0,
    });
  });

  group('text import', () {
    test('preserves source line numbers, quoted commas and blank codes', () {
      final rows = parsePlayerImport(
        '\ncode,name,gender,phone\n\n,"An, B",Nam,0123\nC2\tChi\t女\t0456',
        [],
      );
      expect(rows.map((r) => r.lineNumber), [4, 5]);
      expect(rows.first.name, 'An, B');
      expect(rows.first.toJson(), {
        'lineNumber': 4,
        'name': 'An, B',
        'gender': 'MALE',
        'phone': '0123',
      });
      expect(rows.last.gender, 'FEMALE');
      expect(rows.every((r) => r.errors.isEmpty), isTrue);
    });
    test('flags existing and batch duplicates case-insensitively', () {
      final rows = parsePlayerImport('a1,AN\nX,Chi\nx,chi', [
        const TournamentPlayer(id: 'p', name: 'An', code: 'A1'),
      ]);
      expect(rows.first.errors, {
        PlayerImportError.duplicateCode,
        PlayerImportError.duplicateName,
      });
      expect(rows.last.errors, {
        PlayerImportError.duplicateCode,
        PlayerImportError.duplicateName,
      });
    });
    test(
      'rejects malformed quotes, columns, missing names and unknown gender',
      () {
        expect(parsePlayerImport('A,,bad,12,extra', []).single.errors, {
          PlayerImportError.nameRequired,
          PlayerImportError.gender,
          PlayerImportError.columns,
        });
        expect(
          parsePlayerImport('A,"An', []).single.errors,
          contains(PlayerImportError.columns),
        );
        expect(parsePlayerImport(' \n ', []), isEmpty);
      },
    );
    test('handles escaped quotes and localized genders', () {
      expect(parsePlayerImport('A,"An ""B""",Nữ', []).single.name, 'An "B"');
      expect(normalizePlayerGender('không muốn tiết lộ'), 'PREFER_NOT_TO_SAY');
      expect(normalizePlayerGender('OTHER'), 'OTHER');
    });
  });
}
