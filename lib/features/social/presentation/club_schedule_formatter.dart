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
            '${_formatDays(group.days, l10n)} · '
            '${group.start}–${group.end}',
      )
      .join('  •  ');
}

String _formatTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 2) return value.trim().isEmpty ? '—' : value.trim();

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value.trim();

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _formatDays(Set<int> values, AppLocalizations l10n) {
  final days = values.toList()..sort();
  final names = [
    l10n.socialSunday,
    l10n.socialMonday,
    l10n.socialTuesday,
    l10n.socialWednesday,
    l10n.socialThursday,
    l10n.socialFriday,
    l10n.socialSaturday,
  ];
  final ranges = <String>[];
  var index = 0;

  while (index < days.length) {
    var end = index;
    while (end + 1 < days.length && days[end + 1] == days[end] + 1) {
      end++;
    }

    final length = end - index + 1;
    ranges.add(
      length >= 3
          ? '${names[days[index]]} – ${names[days[end]]}'
          : [for (var i = index; i <= end; i++) names[days[i]]].join(', '),
    );
    index = end + 1;
  }

  return ranges.join(', ');
}

class _ScheduleGroup {
  _ScheduleGroup({required this.start, required this.end});

  final String start;
  final String end;
  final days = <int>{};

  int get firstDay => days.reduce((a, b) => a < b ? a : b);
}
