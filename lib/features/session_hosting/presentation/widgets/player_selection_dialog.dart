import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class PlayerSelectionDialog extends StatefulWidget {
  const PlayerSelectionDialog({required this.players, super.key});

  final List<SessionPlayer> players;

  @override
  State<PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _selected.length == 2 || _selected.length == 4;
    return AlertDialog(
      title: Text(l10n.hostManageAssign),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.hostManageChooseTwoOrFour),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final player in widget.players)
                    CheckboxListTile(
                      value: _selected.contains(player.id),
                      title: Text(l10n.playerName(player)),
                      subtitle: Text(
                        l10n.playerNumbered(player.playerNumber ?? 0),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          if (_selected.length < 4) _selected.add(player.id);
                        } else {
                          _selected.remove(player.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('confirm-player-selection'),
          onPressed: valid
              ? () => Navigator.pop(context, _selected.toList())
              : null,
          child: Text(l10n.hostManageAssign),
        ),
      ],
    );
  }
}
