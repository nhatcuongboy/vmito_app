import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';

/// The month-navigation header, weekday row, and day grid for
/// `showAppMultiDatePicker`. Purely presentational — selection state lives
/// in the caller, which owns the picked-dates set and the visible month.
class AppMultiDateCalendar extends StatelessWidget {
  const AppMultiDateCalendar({
    required this.visibleMonth,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onShiftMonth,
    required this.onToggleDate,
    super.key,
  });

  final DateTime visibleMonth;
  final Set<DateTime> selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<int> onShiftMonth;
  final ValueChanged<DateTime> onToggleDate;

  bool get _canGoBack =>
      visibleMonth.isAfter(DateTime(firstDate.year, firstDate.month));
  bool get _canGoForward =>
      visibleMonth.isBefore(DateTime(lastDate.year, lastDate.month));

  bool _inRange(DateTime day) =>
      !day.isBefore(DateUtils.dateOnly(firstDate)) &&
      !day.isAfter(DateUtils.dateOnly(lastDate));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final daysInMonth = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    // Monday-first grid, matching the weekday chips used elsewhere in the
    // create-session form (`_RecurringFields`).
    final leadingBlanks =
        DateTime(visibleMonth.year, visibleMonth.month).weekday - 1;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('multi-date-picker-prev-month'),
              icon: const Icon(AppIcons.chevronLeft),
              onPressed: _canGoBack ? () => onShiftMonth(-1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat.yMMMM(
                    Localizations.localeOf(context).toString(),
                  ).format(visibleMonth),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('multi-date-picker-next-month'),
              icon: const Icon(AppIcons.chevronRight),
              onPressed: _canGoForward ? () => onShiftMonth(1) : null,
            ),
          ],
        ),
        Row(
          children: [
            for (final index in const [1, 2, 3, 4, 5, 6, 0])
              Expanded(
                child: Center(
                  child: Text(
                    MaterialLocalizations.of(context).narrowWeekdays[index],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final date = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              index - leadingBlanks + 1,
            );
            return _DayCell(
              date: date,
              selected: selected.contains(date),
              enabled: _inRange(date),
              onTap: onToggleDate,
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final scheme = theme.colorScheme;
    final isToday = DateUtils.isSameDay(
      date,
      DateUtils.dateOnly(DateTime.now()),
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: CircleBorder(
          side: !selected && isToday
              ? BorderSide(color: scheme.primary)
              : BorderSide.none,
        ),
        child: InkWell(
          key: Key(
            'multi-date-picker-day-${date.year}-${date.month}-${date.day}',
          ),
          customBorder: const CircleBorder(),
          onTap: enabled ? () => onTap(date) : null,
          child: Center(
            child: Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: !enabled
                    ? palette.mutedForeground.withValues(alpha: .35)
                    : selected
                    ? scheme.onPrimary
                    : scheme.onSurface,
                fontWeight: selected || isToday
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
