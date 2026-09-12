import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// One choice offered by [AppPickerField] and [showAppPickerSheet].
///
/// [display] overrides the default `Text(label)` rendering, both in the
/// closed field and in the sheet's list — for options that read better as
/// something else, e.g. a colour-coded `SkillLevelBadge`.
class AppPickerOption<T> {
  const AppPickerOption({
    required this.value,
    required this.label,
    this.display,
  });

  final T value;
  final String label;
  final Widget? display;
}

/// A form field styled like [TextFormField] that opens a bottom sheet list
/// to choose one of its options, instead of a native dropdown menu.
///
/// Mobile-idiomatic replacement for `DropdownButtonFormField`: it matches the
/// bottom-sheet pattern already used across the app for short option lists
/// (theme mode, sort order, city), gives each option a full-width, thumb-size
/// tap target, and lets an option render as something richer than plain text
/// via [AppPickerOption.display].
class AppPickerField<T> extends FormField<T> {
  AppPickerField({
    required String label,
    required List<AppPickerOption<T>> options,
    required ValueChanged<T> onChanged,
    super.key,
    super.initialValue,
    super.validator,
    String? hintText,
  }) : super(
         builder: (state) {
           final theme = Theme.of(state.context);
           final palette = theme.extension<AppPalette>()!;
           final selected = options.firstWhereOrNull(
             (option) => option.value == state.value,
           );
           return InkWell(
             borderRadius: BorderRadius.circular(AppRadius.xl),
             onTap: () async {
               final picked = await showAppPickerSheet<T>(
                 state.context,
                 title: label,
                 options: options,
                 selected: state.value,
               );
               if (picked == null) return;
               state.didChange(picked);
               onChanged(picked);
             },
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: label,
                 isDense: true,
                 errorText: state.errorText,
                 suffixIcon: const Icon(AppIcons.chevronDown, size: 20),
               ),
               child: SizedBox(
                 height: 24,
                 child: Align(
                   alignment: Alignment.centerLeft,
                   child: selected == null
                       ? Text(
                           hintText ?? '',
                           style: TextStyle(color: palette.mutedForeground),
                         )
                       : selected.display ?? Text(selected.label),
                 ),
               ),
             ),
           );
         },
       );
}

/// Shows the bottom sheet list backing [AppPickerField], and any other
/// single-choice picker that wants the same look without a form field.
Future<T?> showAppPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppPickerOption<T>> options,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(title: title, showCloseButton: false),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final option in options)
                  ListTile(
                    title: option.display ?? Text(option.label),
                    trailing: option.value == selected
                        ? Icon(
                            AppIcons.check,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    selected: option.value == selected,
                    onTap: () => Navigator.of(context).pop(option.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
