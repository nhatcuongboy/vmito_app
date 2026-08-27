import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_presentation.dart';
import 'package:vmito_app/l10n/app_localizations_vi.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('uses the weekday and full date once for a non-relative session', () {
    final session = Session(
      id: 'session-1',
      name: 'Mạnh mẽ nào',
      status: SessionStatus.preparing,
      startTime: DateTime(2026, 8, 28, 14),
    );

    final label = sessionDetailDateLabel(
      session,
      AppLocalizationsVi(),
      'vi',
    );

    expect(label, 'Th 6, 28/8/2026');
  });
}
