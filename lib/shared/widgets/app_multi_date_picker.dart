import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_multi_date_picker_calendar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// Opens a month calendar that toggles many dates on and off in one sitting,
/// instead of the caller re-opening a single-date picker for each day.
Future<List<DateTime>?> showAppMultiDatePicker({
  required BuildContext context,
  required List<DateTime> initialDates,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) => showModalBottomSheet<List<DateTime>>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => _AppMultiDatePickerSheet(
    initialDates: initialDates,
    firstDate: firstDate,
    lastDate: lastDate,
    title: title,
  ),
);

class _AppMultiDatePickerSheet extends StatefulWidget {
  const _AppMultiDatePickerSheet({
    required this.initialDates,
    required this.firstDate,
    required this.lastDate,
    this.title,
  });

  final List<DateTime> initialDates;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? title;

  @override
  State<_AppMultiDatePickerSheet> createState() =>
      _AppMultiDatePickerSheetState();
}

class _AppMultiDatePickerSheetState extends State<_AppMultiDatePickerSheet> {
  late final Set<DateTime> _selected = {
    for (final date in widget.initialDates) DateUtils.dateOnly(date),
  };
  late DateTime _visibleMonth = DateUtils.dateOnly(
    _selected.isNotEmpty ? _selected.first : widget.firstDate,
  );

  void _shiftMonth(int delta) => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
  });

  void _toggle(DateTime day) {
    final inRange =
        !day.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !day.isAfter(DateUtils.dateOnly(widget.lastDate));
    if (!inRange) return;
    setState(() {
      _selected.contains(day) ? _selected.remove(day) : _selected.add(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              AppSheetHeader(
                title: widget.title ?? l10n.sessionFormSpecificDates,
                subtitle: _selected.isEmpty
                    ? null
                    : l10n.sessionFilterSelectedCount(_selected.length),
                showCloseButton: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('multi-date-picker-clear'),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                      child: Text(l10n.homeSearchClearAll),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('multi-date-picker-done'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_selected.toList()..sort()),
                      child: Text(l10n.commonDone),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppMultiDateCalendar(
                    visibleMonth: _visibleMonth,
                    selected: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onShiftMonth: _shiftMonth,
                    onToggleDate: _toggle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
