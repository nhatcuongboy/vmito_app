import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_image_field.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class TournamentSponsorEditor extends ConsumerStatefulWidget {
  const TournamentSponsorEditor({
    required this.tournamentId,
    this.sponsor,
    super.key,
  });
  final String tournamentId;
  final TournamentSponsor? sponsor;
  @override
  ConsumerState<TournamentSponsorEditor> createState() => _SponsorEditorState();
}

class _SponsorEditorState extends ConsumerState<TournamentSponsorEditor> {
  late final FormGroup form = tournamentSponsorForm(widget.sponsor);
  bool uploading = false;
  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(tournamentSponsorsProvider(widget.tournamentId));
    return TournamentEditorFrame(
      title: l.tournamentManageSponsors,
      form: form,
      busy: state.busy || uploading,
      error: state.error,
      onSave: () async {
        final saved = await ref
            .read(tournamentSponsorsProvider(widget.tournamentId).notifier)
            .save(SponsorDraft.fromForm(form), id: widget.sponsor?.id);
        if (saved && context.mounted) Navigator.pop(context);
      },
      children: [
        resourceField(
          context,
          ResourceControl.name,
          l.tournamentResourceName,
          required: true,
        ),
        resourceField(
          context,
          ResourceControl.website,
          l.tournamentSponsorWebsite,
          keyboard: TextInputType.url,
        ),
        ReactiveTextField<int>(
          formControlName: ResourceControl.order,
          decoration: InputDecoration(
            label: AppRequiredLabel(l.tournamentSponsorOrder),
          ),
          keyboardType: TextInputType.number,
          validationMessages: resourceValidationMessages(l),
        ),
        TournamentResourceImageField(
          form: form,
          busy: state.busy,
          onUploading: (value) => setState(() => uploading = value),
        ),
      ],
    );
  }
}
