import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_tiebreaker_picker.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

typedef FormatConfigChanged = void Function(String key, Object? value);

/// Core of vmito-fe `RoundRobinConfigForm`: standing points and tiebreaker
/// order. Advanced points, head-to-head tiebreakers, statistics and standings
/// columns stay web-only and are carried through untouched.
class TournamentFormatRoundRobinSection extends StatelessWidget {
  const TournamentFormatRoundRobinSection({
    required this.values,
    required this.onChanged,
    super.key,
  });

  final Map<String, dynamic> values;
  final FormatConfigChanged onChanged;

  List<Map<String, dynamic>> get _tiebreakers => [
    for (final item in (values['tiebreakers'] as List?) ?? const [])
      if (item is Map<String, dynamic>) item,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tiebreakers = _tiebreakers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tournamentFormatGroupStage, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (key, label) in [
          ('winPoints', l10n.tournamentFormatMatchWin),
          ('tiePoints', l10n.tournamentFormatMatchTie),
          ('lossPoints', l10n.tournamentFormatMatchLoss),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _PointsField(
              label: label,
              value: (values[key] as num?)?.toInt() ?? 0,
              onChanged: (points) => onChanged(key, points),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.tournamentFormatTiebreakers, style: textTheme.titleSmall),
        Text(l10n.tournamentFormatTiebreakersDesc, style: textTheme.bodySmall),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            final next = [...tiebreakers];
            next.insert(to, next.removeAt(from));
            onChanged('tiebreakers', next);
          },
          children: [
            for (final (index, item) in tiebreakers.indexed)
              _tiebreakerTile(context, index, item),
          ],
        ),
        OutlinedButton(
          onPressed: () => _selectTiebreakers(context, tiebreakers),
          child: Text(l10n.tournamentFormatSelectTiebreakers),
        ),
      ],
    );
  }

  Widget _tiebreakerTile(
    BuildContext context,
    int index,
    Map<String, dynamic> item,
  ) {
    final id = item['id']?.toString() ?? '';
    final (label, description) = tournamentTiebreakerCopy(
      AppLocalizations.of(context),
      id,
    );
    // Long-press anywhere on the row, or drag the handle straight away.
    return ReorderableDelayedDragStartListener(
      key: ValueKey(id),
      index: index,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
        title: Text(label),
        subtitle: description.isEmpty ? null : Text(description),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(AppIcons.sortOrder),
        ),
      ),
    );
  }

  Future<void> _selectTiebreakers(
    BuildContext context,
    List<Map<String, dynamic>> current,
  ) async {
    final selected = await showTournamentTiebreakerPicker(
      context,
      selected: {for (final item in current) item['id']?.toString() ?? ''},
    );
    if (selected == null) return;
    // Unlike the web modal, keep the order the host already arranged and
    // append new picks in catalogue order.
    onChanged('tiebreakers', [
      for (final item in current)
        if (selected.contains(item['id'])) item,
      for (final id in TournamentFormatConfig.tiebreakerIds)
        if (selected.contains(id) && !current.any((item) => item['id'] == id))
          TournamentFormatConfig.tiebreaker(id),
    ]);
  }
}

class _PointsField extends StatelessWidget {
  const _PointsField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = {
      for (var n = 0; n <= TournamentFormatConfig.maxStandingPoints; n++) n,
      // A value saved outside the web's 0–20 range must still render.
      value,
    }.toList()..sort();
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final n in options)
          DropdownMenuItem(
            value: n,
            child: Text(l10n.tournamentFormatPoints(n)),
          ),
      ],
      onChanged: (points) {
        if (points != null) onChanged(points);
      },
    );
  }
}
