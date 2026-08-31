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

    expect(result, 'Thứ 2 – Thứ 6 · 19:00–21:00');
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

    expect(result, 'Thứ 2 · 19:00–21:00\nThứ 4 · 07:30–09:00');
  });

  test('orders days from Monday and puts each time range on its own line', () {
    final result = formatClubActivitySchedule(
      const [
        ClubSchedule(dayOfWeek: 0, startTime: '15:00', endTime: '18:00'),
        ClubSchedule(dayOfWeek: 6, startTime: '15:00', endTime: '18:00'),
        ClubSchedule(dayOfWeek: 1, startTime: '20:00', endTime: '22:00'),
      ],
      l10n,
    );

    expect(
      result,
      'Thứ 2 · 20:00–22:00\nThứ 7, Chủ nhật · 15:00–18:00',
    );
  });
}
