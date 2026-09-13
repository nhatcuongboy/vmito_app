import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentPlayerImportEditor extends ConsumerStatefulWidget {
  const TournamentPlayerImportEditor({required this.tournamentId, super.key});
  final String tournamentId;
  @override
  ConsumerState<TournamentPlayerImportEditor> createState() => _ImportState();
}

class _ImportState extends ConsumerState<TournamentPlayerImportEditor> {
  final form = FormGroup({
    ResourceControl.text: FormControl<String>(
      validators: [Validators.required],
    ),
  });
  List<PlayerImportRow>? rows;
  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(tournamentPlayersProvider(widget.tournamentId));
    return TournamentEditorFrame(
      title: l.tournamentPlayerImport,
      form: form,
      busy: state.busy,
      error: state.error,
      canSave:
          rows?.isNotEmpty == true && rows!.every((row) => row.errors.isEmpty),
      onSave: () async {
        // Revalidate against the latest collection immediately before submission.
        final latest = parsePlayerImport(
          resourceText(form, ResourceControl.text) ?? '',
          state.items,
        );
        setState(() => rows = latest);
        if (latest.isEmpty || latest.any((row) => row.errors.isNotEmpty)) {
          return;
        }
        final saved = await ref
            .read(tournamentPlayersProvider(widget.tournamentId).notifier)
            .import(latest);
        if (saved && context.mounted) Navigator.pop(context);
      },
      children: [
        Text(l.tournamentPlayerImportHelp),
        ReactiveTextField<String>(
          formControlName: ResourceControl.text,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(labelText: l.tournamentPlayerImport),
          validationMessages: resourceValidationMessages(l),
          onChanged: (_) => setState(() => rows = null),
        ),
        OutlinedButton(
          onPressed: () {
            form.markAllAsTouched();
            if (form.invalid || form.pending) return;
            setState(
              () => rows = parsePlayerImport(
                resourceText(form, ResourceControl.text) ?? '',
                state.items,
              ),
            );
          },
          child: Text(l.tournamentPlayerImportPreview),
        ),
        for (final row in rows ?? <PlayerImportRow>[])
          ListTile(
            leading: Text('${row.lineNumber}'),
            title: Text('${row.code} · ${row.name}'),
            subtitle: Text(
              row.errors.isEmpty
                  ? '${resourceGenderLabel(l, row.gender)} · ${row.phone}'
                  : row.errors
                        .map(
                          (e) => switch (e) {
                            PlayerImportError.nameRequired =>
                              l.tournamentPlayerImportNameError,
                            PlayerImportError.gender =>
                              l.tournamentPlayerImportGenderError,
                            PlayerImportError.duplicateCode =>
                              l.tournamentPlayerImportCodeError,
                            PlayerImportError.duplicateName =>
                              l.tournamentPlayerImportDuplicateName,
                            PlayerImportError.columns =>
                              l.tournamentPlayerImportColumnsError,
                          },
                        )
                        .join(' · '),
            ),
            trailing: Icon(
              row.errors.isEmpty
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: row.errors.isEmpty
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}
