import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The overall column of vmito-fe `SelectTiebreakersModal`. Resolves to the
/// chosen ids, or null when dismissed.
Future<Set<String>?> showTournamentTiebreakerPicker(
  BuildContext context, {
  required Set<String> selected,
}) => showModalBottomSheet<Set<String>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _TiebreakerPicker(initial: selected),
);

class _TiebreakerPicker extends StatefulWidget {
  const _TiebreakerPicker({required this.initial});

  final Set<String> initial;

  @override
  State<_TiebreakerPicker> createState() => _TiebreakerPickerState();
}

class _TiebreakerPickerState extends State<_TiebreakerPicker> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.tournamentFormatSelectTiebreakers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                for (final id in TournamentFormatConfig.tiebreakerIds)
                  _option(l10n, id),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(l10n.commonConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(AppLocalizations l10n, String id) {
    final (label, description) = tournamentTiebreakerCopy(l10n, id);
    return CheckboxListTile(
      value: _selected.contains(id),
      title: Text(label),
      subtitle: Text(description),
      onChanged: (checked) => setState(
        () => checked == true ? _selected.add(id) : _selected.remove(id),
      ),
    );
  }
}
