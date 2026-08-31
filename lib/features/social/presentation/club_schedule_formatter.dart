import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Formats recurring club schedules into a compact card-friendly summary.
///
/// Days sharing a time range are grouped together, while different time
/// ranges remain visible as separate entries.
String? formatClubActivitySchedule(
  Iterable<ClubSchedule> schedules,
  AppLocalizations l10n,
) {
  final groups = <String, _ScheduleGroup>{};
  for (final schedule in schedules) {
    if (!schedule.isActive ||
        schedule.dayOfWeek < 0 ||
        schedule.dayOfWeek > 6) {
      continue;
    }

    final start = _formatTime(schedule.startTime);
    final end = _formatTime(schedule.endTime);
    final key = '$start|$end';
    final group = groups.putIfAbsent(
      key,
      () => _ScheduleGroup(start: start, end: end),
    );
    group.days.add(schedule.dayOfWeek);
  }

  if (groups.isEmpty) return null;

  final sortedGroups = groups.values.toList()
    ..sort((a, b) {
      final dayComparison = a.firstDay.compareTo(b.firstDay);
      return dayComparison != 0 ? dayComparison : a.start.compareTo(b.start);
    });

  return sortedGroups
      .map(
        (group) =>
            '${_formatDays(group.days)} · '
            '${group.start}–${group.end}',
      )
      .join('\n');
}

String _formatTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 2) return value.trim().isEmpty ? '—' : value.trim();

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value.trim();

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _formatDays(Set<int> values) {
  final days = values.toList()
    ..sort((a, b) => _vietnameseDayIndex(a).compareTo(_vietnameseDayIndex(b)));
  final ranges = <String>[];
  var index = 0;

  while (index < days.length) {
    var end = index;
    while (end + 1 < days.length &&
        _vietnameseDayIndex(days[end + 1]) ==
            _vietnameseDayIndex(days[end]) + 1) {
      end++;
    }

    final length = end - index + 1;
    ranges.add(
      length >= 3
          ? '${_formatDay(days[index])} – ${_formatDay(days[end])}'
          : [
              for (var i = index; i <= end; i++) _formatDay(days[i]),
            ].join(', '),
    );
    index = end + 1;
  }

  return ranges.join(', ');
}

String _formatDay(int day) => switch (day) {
  0 => 'Chủ nhật',
  1 => 'Thứ 2',
  2 => 'Thứ 3',
  3 => 'Thứ 4',
  4 => 'Thứ 5',
  5 => 'Thứ 6',
  6 => 'Thứ 7',
  _ => '—',
};

int _vietnameseDayIndex(int day) => (day + 6) % 7;

class _ScheduleGroup {
  _ScheduleGroup({required this.start, required this.end});

  final String start;
  final String end;
  final days = <int>{};

  int get firstDay =>
      days.map(_vietnameseDayIndex).reduce((a, b) => a < b ? a : b);
}
