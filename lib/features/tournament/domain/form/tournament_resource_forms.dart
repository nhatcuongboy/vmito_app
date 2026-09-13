import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

abstract final class ResourceControl {
  static const name = 'name';
  static const code = 'code';
  static const email = 'email';
  static const phone = 'phone';
  static const image = 'image';
  static const imagePublicId = 'imagePublicId';
  static const gender = 'gender';
  static const level = 'level';
  static const description = 'levelDescription';
  static const notes = 'notes';
  static const userId = 'userId';
  static const website = 'website';
  static const order = 'displayOrder';
  static const query = 'query';
  static const text = 'text';
}

const playerGenders = ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'];

String? resourceText(FormGroup form, String key) {
  final value = (form.control(key).value as String?)?.trim();
  return value == null || value.isEmpty ? null : value;
}

Map<String, dynamic>? resourceUrlValidator(AbstractControl<dynamic> control) {
  final text = control.value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  return uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty
      ? null
      : {'httpUrl': true};
}

FormControl<String> _text(
  String? value, {
  List<Validator<dynamic>> validators = const [],
}) => FormControl<String>(value: value, validators: validators);

Validator<dynamic> get _nameValidator => Validators.delegate(
  (control) => (control.value as String?)?.trim().isNotEmpty == true
      ? null
      : {ValidationMessage.required: true},
);

FormGroup tournamentPlayerForm([TournamentPlayer? player]) => FormGroup({
  ResourceControl.name: _text(player?.name, validators: [_nameValidator]),
  ResourceControl.code: _text(player?.code),
  ResourceControl.email: _text(player?.email, validators: [Validators.email]),
  ResourceControl.phone: _text(player?.phone),
  ResourceControl.image: _text(
    player?.image,
    validators: [Validators.delegate(resourceUrlValidator)],
  ),
  ResourceControl.imagePublicId: _text(player?.imagePublicId),
  ResourceControl.gender: _text(
    player?.gender,
    validators: [
      Validators.delegate(
        (control) =>
            control.value == null ||
                control.value == '' ||
                playerGenders.contains(control.value)
            ? null
            : {'gender': true},
      ),
    ],
  ),
  ResourceControl.level: FormControl<int>(
    value: player?.level,
    validators: [Validators.min(1), Validators.max(10)],
  ),
  ResourceControl.description: _text(player?.levelDescription),
  ResourceControl.notes: _text(player?.notes),
  ResourceControl.userId: _text(player?.userId),
});

class PlayerDraft {
  const PlayerDraft({
    required this.name,
    this.code,
    this.email,
    this.phone,
    this.image,
    this.imagePublicId,
    this.gender,
    this.level,
    this.levelDescription,
    this.notes,
    this.userId,
  });
  factory PlayerDraft.fromForm(FormGroup form) => PlayerDraft(
    name: resourceText(form, ResourceControl.name)!,
    code: resourceText(form, ResourceControl.code),
    email: resourceText(form, ResourceControl.email),
    phone: resourceText(form, ResourceControl.phone),
    image: resourceText(form, ResourceControl.image),
    imagePublicId: resourceText(form, ResourceControl.imagePublicId),
    gender: resourceText(form, ResourceControl.gender),
    level: form.control(ResourceControl.level).value as int?,
    levelDescription: resourceText(form, ResourceControl.description),
    notes: resourceText(form, ResourceControl.notes),
    userId: resourceText(form, ResourceControl.userId),
  );
  final String name;
  final String? code;
  final String? email;
  final String? phone;
  final String? image;
  final String? imagePublicId;
  final String? gender;
  final String? levelDescription;
  final String? notes;
  final String? userId;
  final int? level;

  Map<String, dynamic> toJson({bool update = false}) {
    final json = <String, dynamic>{
      'name': name.trim(), 'code': code,
      'email': email,
      'phone': phone,
      'image': image,
      'imagePublicId': imagePublicId,
      'gender': gender,
      'level': level,
      'levelDescription': levelDescription,
      'userId': userId,
      // The create DTO does not support notes; expose it only when editing.
      if (update) 'notes': notes,
    };
    if (!update) json.removeWhere((key, value) => value == null);
    return json;
  }
}

FormGroup tournamentSponsorForm([TournamentSponsor? sponsor]) => FormGroup({
  ResourceControl.name: _text(sponsor?.name, validators: [_nameValidator]),
  ResourceControl.website: _text(
    sponsor?.website,
    validators: [Validators.delegate(resourceUrlValidator)],
  ),
  ResourceControl.image: _text(
    sponsor?.logo,
    validators: [Validators.delegate(resourceUrlValidator)],
  ),
  ResourceControl.imagePublicId: _text(sponsor?.logoPublicId),
  ResourceControl.order: FormControl<int>(
    value: sponsor?.displayOrder ?? 0,
    validators: [Validators.required, Validators.min(0)],
  ),
});

class SponsorDraft {
  const SponsorDraft({
    required this.name,
    this.website,
    this.logo,
    this.logoPublicId,
    this.displayOrder = 0,
  });
  factory SponsorDraft.fromForm(FormGroup form) => SponsorDraft(
    name: resourceText(form, ResourceControl.name)!,
    website: resourceText(form, ResourceControl.website),
    logo: resourceText(form, ResourceControl.image),
    logoPublicId: resourceText(form, ResourceControl.imagePublicId),
    displayOrder: form.control(ResourceControl.order).value as int,
  );
  final String name;
  final String? website;
  final String? logo;
  final String? logoPublicId;
  final int displayOrder;
  Map<String, dynamic> toJson({bool update = false}) {
    final json = <String, dynamic>{
      'name': name.trim(),
      'website': website,
      'logo': logo,
      'logoPublicId': logoPublicId,
      'displayOrder': displayOrder,
    };
    if (!update) json.removeWhere((key, value) => value == null);
    return json;
  }
}

enum PlayerImportError {
  nameRequired,
  gender,
  duplicateCode,
  duplicateName,
  columns,
}

class PlayerImportRow {
  const PlayerImportRow({
    required this.lineNumber,
    required this.name,
    required this.code,
    required this.gender,
    required this.phone,
    required this.errors,
  });
  final int lineNumber;
  final String name;
  final String code;
  final String phone;
  final String? gender;
  final Set<PlayerImportError> errors;
  Map<String, dynamic> toJson() => {
    'lineNumber': lineNumber,
    'name': name,
    if (code.isNotEmpty) 'code': code,
    if (gender != null) 'gender': gender,
    if (phone.isNotEmpty) 'phone': phone,
  };
}

String? normalizePlayerGender(String value) =>
    switch (value.trim().toLowerCase()) {
      'm' || 'male' || 'man' || 'nam' || '男' => 'MALE',
      'f' || 'female' || 'woman' || 'nu' || 'nữ' || '女' => 'FEMALE',
      'o' || 'other' || 'khac' || 'khác' || '其他' => 'OTHER',
      'prefer not to say' ||
      'prefer_not_to_say' ||
      'khong tiet lo' ||
      'không tiết lộ' ||
      'khong muon tiet lo' ||
      'không muốn tiết lộ' ||
      '不愿透露' => 'PREFER_NOT_TO_SAY',
      _ => null,
    };

/// Pasted comma/tab-delimited text, not a file importer. Empty codes are left for
/// the backend to allocate atomically; original line numbers survive blank lines.
List<PlayerImportRow> parsePlayerImport(
  String text,
  List<TournamentPlayer> existing,
) {
  final codes = existing
      .map((p) => p.code?.trim().toLowerCase())
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .toSet();
  final names = existing.map((p) => p.name.trim().toLowerCase()).toSet();
  final result = <PlayerImportRow>[];
  final lines = text.split(RegExp(r'\r?\n'));
  var first = true;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final parsed = _columns(lines[i]);
    final values = parsed.values;
    if (first &&
        values.length >= 2 &&
        ['code', 'mã', 'ma', '编号'].contains(values[0].toLowerCase()) &&
        [
          'name',
          'tên',
          'ten',
          'họ tên',
          'ho ten',
          '姓名',
        ].contains(values[1].toLowerCase())) {
      first = false;
      continue;
    }
    first = false;
    String at(int index) => index < values.length ? values[index] : '';
    final code = at(0);
    final name = at(1);
    final rawGender = at(2);
    final phone = at(3);
    final gender = normalizePlayerGender(rawGender);
    final errors = <PlayerImportError>{
      if (name.isEmpty) PlayerImportError.nameRequired,
      if (rawGender.isNotEmpty && gender == null) PlayerImportError.gender,
      if (!parsed.valid || values.length < 2 || values.length > 4)
        PlayerImportError.columns,
      if (code.isNotEmpty && !codes.add(code.toLowerCase()))
        PlayerImportError.duplicateCode,
      if (name.isNotEmpty && !names.add(name.toLowerCase()))
        PlayerImportError.duplicateName,
    };
    result.add(
      PlayerImportRow(
        lineNumber: i + 1,
        name: name,
        code: code,
        gender: gender,
        phone: phone,
        errors: Set.unmodifiable(errors),
      ),
    );
  }
  return List.unmodifiable(result);
}

({List<String> values, bool valid}) _columns(String line) {
  if (line.contains('\t')) {
    return (
      values: line.split('\t').map((v) => v.trim()).toList(),
      valid: true,
    );
  }
  final values = <String>[];
  var buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    if (line[i] == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (line[i] == ',' && !quoted) {
      values.add(buffer.toString().trim());
      buffer = StringBuffer();
    } else {
      buffer.write(line[i]);
    }
  }
  values.add(buffer.toString().trim());
  return (values: values, valid: !quoted);
}
