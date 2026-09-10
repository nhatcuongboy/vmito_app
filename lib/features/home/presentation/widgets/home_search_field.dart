import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The pill-shaped query field in the search screen's app bar.
///
/// Every border state is spelled out: leaving `focusedBorder` to the theme
/// swapped the pill for the theme's 8 px rounded rectangle on focus.
/// Must sit under a `ReactiveForm` that owns [formControlName].
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    required this.formControlName,
    required this.focusNode,
    required this.hintText,
    required this.showClear,
    required this.hasError,
    required this.onSubmitted,
    required this.onClear,
    super.key,
  });

  static const double height = 44;

  final String formControlName;
  final FocusNode focusNode;
  final String hintText;
  final bool showClear;
  final bool hasError;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    OutlineInputBorder pill([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: side,
        );
    final errorBorder = pill(
      BorderSide(color: theme.colorScheme.error, width: 1.5),
    );
    return SizedBox(
      height: height,
      child: ReactiveTextField<String>(
        key: const Key('home-search-field'),
        formControlName: formControlName,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (_) => onSubmitted(),
        // The inline message under the app bar replaces the field's own
        // error text, which would not fit inside a 44 pt pill.
        showErrors: (_) => false,
        validationMessages: {
          ValidationMessage.required: (_) => l10n.homeSearchRequired,
        },
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: palette.mutedForeground,
          ),
          prefixIcon: Icon(
            AppIcons.search,
            size: 20,
            color: palette.mutedForeground,
          ),
          prefixIconConstraints: const BoxConstraints.tightFor(
            width: height,
            height: height,
          ),
          suffixIcon: showClear
              ? IconButton(
                  key: const Key('home-search-clear-query'),
                  tooltip: l10n.homeSearchClearQuery,
                  icon: Icon(
                    AppIcons.cancel,
                    size: 20,
                    color: palette.mutedForeground,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.only(right: AppSpacing.md),
          border: hasError ? errorBorder : pill(),
          enabledBorder: hasError ? errorBorder : pill(),
          focusedBorder: hasError
              ? errorBorder
              : pill(
                  BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.55),
                  ),
                ),
        ),
      ),
    );
  }
}
