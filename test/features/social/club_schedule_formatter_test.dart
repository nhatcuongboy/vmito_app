import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/presentation/club_schedule_formatter.dart';
import 'package:vmito_app/l10n/app_localizations_vi.dart';

void main() {
  final l10n = AppLocalizationsVi();

  test('groups days that share a time range', () {
    final result = formatClubActivitySchedule(
      const [
        ClubSchedule(dayOfWeek: 1, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 2, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 3, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 4, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 5, startTime: '19:00', endTime: '21:00'),
      ],
      l10n,
    );

    expect(result, 'Thứ Hai – Thứ Sáu · 19:00–21:00');
  });

  test('keeps different time ranges visible', () {
    final result = formatClubActivitySchedule(
      const [
        ClubSchedule(dayOfWeek: 1, startTime: '19:00', endTime: '21:00'),
        ClubSchedule(dayOfWeek: 3, startTime: '07:30', endTime: '09:00'),
        ClubSchedule(
          dayOfWeek: 5,
          startTime: '19:00:00',
          endTime: '21:00:00',
          isActive: false,
        ),
      ],
      l10n,
    );

    expect(result, 'Thứ Hai · 19:00–21:00  •  Thứ Tư · 07:30–09:00');
  });
}
