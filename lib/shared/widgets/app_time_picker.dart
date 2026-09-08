import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// Opens the app's 24-hour, wheel-based time picker.
///
/// A wheel is easier to operate precisely on touch screens than the Material
/// clock dial while still preserving minute-level accuracy.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? title,
}) => showModalBottomSheet<TimeOfDay>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => _AppTimePickerSheet(
    initialTime: initialTime,
    title: title,
  ),
);

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({required this.initialTime, this.title});

  final TimeOfDay initialTime;
  final String? title;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      2000,
      1,
      1,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  String get _formattedTime =>
      '${_selected.hour.toString().padLeft(2, '0')}:'
      '${_selected.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      key: const Key('app-time-picker-sheet'),
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: widget.title ?? localizations.timePickerDialHelpText,
            onClose: () => Navigator.of(context).pop(),
          ),
          Semantics(
            liveRegion: true,
            label: _formattedTime,
            child: Text(
              _formattedTime,
              key: const Key('app-time-picker-value'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: theme.textTheme.headlineSmall,
                ),
              ),
              child: CupertinoDatePicker(
                key: const Key('app-time-picker-wheel'),
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _selected,
                use24hFormat: true,
                onDateTimeChanged: (value) => setState(() => _selected = value),
              ),
            ),
          ),
          AppSheetActionBar(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('app-time-picker-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localizations.cancelButtonLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const Key('app-time-picker-confirm'),
                    onPressed: () => Navigator.of(context).pop(
                      TimeOfDay(
                        hour: _selected.hour,
                        minute: _selected.minute,
                      ),
                    ),
                    child: Text(localizations.okButtonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
