import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/api/generated/openapi.models.swagger.dart';

/// Guards the codegen pipeline, and pins the one behaviour of it that will bite.
///
/// These DTOs come from `openapi/openapi.json` via `swagger_dart_code_generator`.
/// Regenerate with `tool/sync_openapi.sh` then `dart run build_runner build`.
void main() {
  group('generated DTOs decode', () {
    test('a simple DTO round-trips', () {
      const json = {'email': 'a@example.com', 'password': 'secret'};

      final dto = LoginDto.fromJson(json);

      expect(dto.email, 'a@example.com');
      expect(dto.password, 'secret');
      expect(dto.toJson(), json);
    });
  });

  group('every numeric field is a double', () {
    // TypeScript has one number type, so the @nestjs/swagger CLI plugin emits
    // `type: number` for every numeric field — there is not a single
    // `type: integer` in the document. The Dart generator maps that to
    // `double`. This is wire-level reality, not a preference.
    test('an integer in JSON decodes to double', () {
      final dto = JoinByCodeDto.fromJson({
        'sessionCode': 'ABC123',
        'name': 'Nguyễn Văn A',
        'level': 3,
      });

      expect(dto.level, isA<double>());
      expect(dto.level, 3.0);
    });

    test('PlayerLevel is numeric, never a generated enum', () {
      // The values are non-contiguous — 1-8, then 9 = BEGINNER_MINUS,
      // 10 = BEGINNER_PLUS — so an enum would silently reorder them.
      // Confirmed here: 9 and 10 survive as their own values and stay ordered.
      final levels =
          [9, 10, 1]
              .map(
                (v) => JoinByCodeDto.fromJson({
                  'sessionCode': 'X',
                  'name': 'A',
                  'level': v,
                }),
              )
              .map((dto) => dto.level!.toInt())
              .toList()
            ..sort();

      expect(levels, [1, 9, 10]);
    });

    test('formatting a double straight to text produces "3.0", not "3"', () {
      final dto = JoinByCodeDto.fromJson({
        'sessionCode': 'X',
        'name': 'A',
        'level': 3,
      });

      // This is the trap. Services must convert to int at the boundary before
      // anything reaches the UI — especially VND amounts, which must render
      // with decimalDigits: 0.
      expect('${dto.level}', '3.0');
      expect('${dto.level!.toInt()}', '3');
    });
  });
}
