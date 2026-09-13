import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_image_field.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_user_search_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TournamentPlayerEditor extends ConsumerStatefulWidget {
  const TournamentPlayerEditor({
    required this.tournamentId,
    this.player,
    super.key,
  });
  final String tournamentId;
  final TournamentPlayer? player;
  @override
  ConsumerState<TournamentPlayerEditor> createState() => _PlayerEditorState();
}

class _PlayerEditorState extends ConsumerState<TournamentPlayerEditor> {
  late final FormGroup form = tournamentPlayerForm(widget.player);
  bool uploading = false;
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
      title: l.tournamentManagePlayers,
      form: form,
      busy: state.busy || uploading,
      error: state.error,
      onSave: () async {
        final saved = await ref
            .read(tournamentPlayersProvider(widget.tournamentId).notifier)
            .save(PlayerDraft.fromForm(form), id: widget.player?.id);
        if (saved && context.mounted) Navigator.pop(context);
      },
      children: [
        resourceField(
          context,
          ResourceControl.name,
          l.tournamentResourceName,
          required: true,
        ),
        resourceField(context, ResourceControl.code, l.tournamentPlayerCode),
        resourceField(
          context,
          ResourceControl.email,
          l.authEmail,
          keyboard: TextInputType.emailAddress,
        ),
        resourceField(
          context,
          ResourceControl.phone,
          l.tournamentManageContactPhone,
          keyboard: TextInputType.phone,
        ),
        ReactiveDropdownField<String>(
          formControlName: ResourceControl.gender,
          decoration: InputDecoration(labelText: l.profileGender),
          items: [
            DropdownMenuItem(value: '', child: Text(l.commonCancel)),
            for (final gender in playerGenders)
              DropdownMenuItem(
                value: gender,
                child: Text(resourceGenderLabel(l, gender)),
              ),
          ],
        ),
        ReactiveTextField<int>(
          formControlName: ResourceControl.level,
          decoration: InputDecoration(labelText: l.profileLevel),
          keyboardType: TextInputType.number,
          validationMessages: resourceValidationMessages(l),
        ),
        resourceField(
          context,
          ResourceControl.description,
          l.profileLevelDescription,
          maxLines: 3,
        ),
        if (widget.player != null)
          resourceField(
            context,
            ResourceControl.notes,
            l.tournamentPlayerNotes,
            maxLines: 3,
          )
        else
          Text(l.tournamentPlayerNotesAfterCreate),
        if (widget.player != null)
          TournamentResourceImageField(
            form: form,
            busy: state.busy,
            onUploading: (value) => setState(() => uploading = value),
          ),
        ReactiveValueListenableBuilder<String>(
          formControlName: ResourceControl.userId,
          builder: (context, control, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${l.tournamentPlayerAccount}: ${control.value ?? '—'}'),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final user =
                          await showModalBottomSheet<TournamentUserOption>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => const TournamentUserSearchSheet(),
                          );
                      if (user != null && mounted) {
                        form.control(ResourceControl.userId).value = user.id;
                      }
                    },
                    child: Text(l.tournamentManageSearchUsers),
                  ),
                  TextButton(
                    onPressed: control.value == null
                        ? null
                        : () =>
                              form.control(ResourceControl.userId).value = null,
                    child: Text(l.tournamentPlayerUnlink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
