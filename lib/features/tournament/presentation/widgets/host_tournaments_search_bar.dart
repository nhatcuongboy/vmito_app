import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The pill search field of the web `HostTournamentsHeader`.
///
/// On web the trailing sliders button has no handler; here it opens sorting,
/// the only list control mobile web lacks. A dot marks a non-default sort.
class HostTournamentsSearchBar extends StatefulWidget {
  const HostTournamentsSearchBar({
    required this.onChanged,
    required this.onSortPressed,
    this.isSortActive = false,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onSortPressed;
  final bool isSortActive;

  @override
  State<HostTournamentsSearchBar> createState() =>
      _HostTournamentsSearchBarState();
}

class _HostTournamentsSearchBarState extends State<HostTournamentsSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    const noBorder = InputBorder.none;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(AppIcons.search, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              key: const Key('host-tournaments-search'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                widget.onChanged(value);
                setState(() {});
              },
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: l10n.tournamentSearchHint,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: noBorder,
                enabledBorder: noBorder,
                focusedBorder: noBorder,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: l10n.hostTournamentsClearSearch,
              visualDensity: VisualDensity.compact,
              onPressed: _clear,
              icon: const Icon(AppIcons.close, size: 18),
            ),
          IconButton(
            key: const Key('host-tournaments-sort'),
            tooltip: l10n.homeDiscoverySortBy,
            onPressed: widget.onSortPressed,
            icon: Badge(
              isLabelVisible: widget.isSortActive,
              smallSize: 7,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                AppIcons.filter,
                size: 18,
                color: widget.isSortActive
                    ? theme.colorScheme.primary
                    : palette.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
