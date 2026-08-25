import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Filters the player list by name or shirt number.
///
/// Uncontrolled on purpose: it owns its `TextEditingController` and reports
/// changes upward. Rebuilding it from state on every keystroke would fight the
/// cursor.
class PlayerSearchField extends StatefulWidget {
  const PlayerSearchField({
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final ValueChanged<String> onChanged;

  /// Shrinks padding, icon and text so the field can sit beside a header
  /// instead of taking its own full-width row.
  final bool compact;

  @override
  State<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<PlayerSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final iconSize = widget.compact ? 15.0 : 20.0;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: widget.compact ? Theme.of(context).textTheme.bodySmall : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        hintText: l10n.courtSearchPlayers,
        hintStyle: widget.compact
            ? Theme.of(context).textTheme.bodySmall
            : null,
        prefixIconConstraints: widget.compact
            ? const BoxConstraints(minWidth: 28, minHeight: 28)
            : const BoxConstraints(minWidth: 36, minHeight: 36),
        prefixIcon: Icon(AppIcons.search, size: iconSize),
        suffixIconConstraints: widget.compact
            ? const BoxConstraints(minWidth: 24, minHeight: 24)
            : const BoxConstraints(minWidth: 32, minHeight: 32),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(AppIcons.close, size: widget.compact ? 14 : 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
