import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_management_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

typedef TournamentUpdater = Future<void> Function(Map<String, dynamic> changes);

class TournamentStatusPanel extends StatelessWidget {
  const TournamentStatusPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });

  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = switch (tournament.status) {
      TournamentStatus.preparing => [
        (
          l10n.tournamentManageStart,
          TournamentStatus.inProgress,
          AppIcons.play,
        ),
        (
          l10n.tournamentManageCancelTournament,
          TournamentStatus.cancelled,
          AppIcons.close,
        ),
      ],
      TournamentStatus.inProgress => [
        (
          l10n.tournamentManageFinish,
          TournamentStatus.finished,
          AppIcons.trophy,
        ),
        (
          l10n.tournamentManageCancelTournament,
          TournamentStatus.cancelled,
          AppIcons.close,
        ),
      ],
      TournamentStatus.finished => [
        (
          l10n.tournamentManageReopen,
          TournamentStatus.inProgress,
          AppIcons.refresh,
        ),
      ],
      TournamentStatus.cancelled => [
        (
          l10n.tournamentManageRestore,
          TournamentStatus.preparing,
          AppIcons.refresh,
        ),
      ],
    };
    return _PanelFrame(
      title: l10n.tournamentManageStatus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 7,
              backgroundColor: _statusColor(tournament.status),
            ),
            title: Text(_statusLabel(l10n, tournament.status)),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final action in actions)
                FilledButton.tonalIcon(
                  onPressed: busy
                      ? null
                      : () => _confirmStatus(context, action.$1, action.$2),
                  icon: Icon(action.$3),
                  label: Text(action.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStatus(
    BuildContext context,
    String action,
    TournamentStatus target,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.tournamentManageConfirmStatus,
      content: action,
      confirmLabel: action,
    );
    if (confirmed == true && context.mounted) {
      await onUpdate({'status': target.wireValue});
    }
  }
}

class TournamentNamePanel extends StatefulWidget {
  const TournamentNamePanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  State<TournamentNamePanel> createState() => _TournamentNamePanelState();
}

class _TournamentNamePanelState extends State<TournamentNamePanel> {
  late final FormGroup form = tournamentNameForm(widget.tournament);

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormPanel(
      title: l10n.tournamentManageName,
      form: form,
      busy: widget.busy,
      onSubmit: () => widget.onUpdate({
        'name': _text(form, TournamentSettingsControl.name),
        'description': _nullableText(
          form,
          TournamentSettingsControl.description,
        ),
      }),
      children: [
        ReactiveTextField<String>(
          formControlName: TournamentSettingsControl.name,
          maxLength: 100,
          decoration: InputDecoration(labelText: l10n.tournamentManageName),
          validationMessages: {
            ValidationMessage.required: (_) => l10n.tournamentManageName,
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ReactiveTextField<String>(
          formControlName: TournamentSettingsControl.description,
          maxLength: 2000,
          minLines: 4,
          maxLines: 7,
          decoration: InputDecoration(
            labelText: l10n.tournamentManageDescription,
          ),
        ),
      ],
    );
  }
}

class TournamentDatesPanel extends StatefulWidget {
  const TournamentDatesPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  State<TournamentDatesPanel> createState() => _TournamentDatesPanelState();
}

class _TournamentDatesPanelState extends State<TournamentDatesPanel> {
  late final FormGroup form = tournamentDatesForm(widget.tournament);

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormPanel(
      title: l10n.tournamentManageDates,
      form: form,
      busy: widget.busy,
      onSubmit: () {
        final start =
            form.control(TournamentSettingsControl.startDate).value as DateTime;
        final end =
            form.control(TournamentSettingsControl.endDate).value as DateTime;
        return widget.onUpdate({
          'startDate': DateTime.utc(
            start.year,
            start.month,
            start.day,
          ).toIso8601String(),
          'endDate': DateTime.utc(
            end.year,
            end.month,
            end.day,
          ).toIso8601String(),
        });
      },
      children: [
        _ReactiveDateField(
          controlName: TournamentSettingsControl.startDate,
          label: l10n.tournamentManageStartDate,
        ),
        const SizedBox(height: AppSpacing.md),
        _ReactiveDateField(
          controlName: TournamentSettingsControl.endDate,
          label: l10n.tournamentManageEndDate,
        ),
        ReactiveFormConsumer(
          builder: (context, form, _) =>
              form.hasError(
                TournamentManagementValidation.endBeforeStart,
              )
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l10n.tournamentCreateEndBeforeStart,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class TournamentVisibilityPanel extends StatefulWidget {
  const TournamentVisibilityPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  State<TournamentVisibilityPanel> createState() =>
      _TournamentVisibilityPanelState();
}

class _TournamentVisibilityPanelState extends State<TournamentVisibilityPanel> {
  late final FormGroup form = tournamentVisibilityForm(widget.tournament);

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormPanel(
      title: l10n.tournamentManageVisibility,
      form: form,
      busy: widget.busy,
      onSubmit: () => widget.onUpdate({
        'isPublished': form.control(TournamentSettingsControl.visibility).value,
      }),
      children: [
        ReactiveSwitchListTile(
          formControlName: TournamentSettingsControl.visibility,
          title: Text(l10n.tournamentManagePublic),
          subtitle: Text(l10n.tournamentManagePrivate),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class TournamentContactPanel extends StatefulWidget {
  const TournamentContactPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  State<TournamentContactPanel> createState() => _TournamentContactPanelState();
}

class _TournamentContactPanelState extends State<TournamentContactPanel> {
  late final FormGroup form = tournamentContactForm(widget.tournament);

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormPanel(
      title: l10n.tournamentManageContact,
      form: form,
      busy: widget.busy,
      onSubmit: () => widget.onUpdate({
        'contactName': _nullableText(
          form,
          TournamentSettingsControl.contactName,
        ),
        'contactEmail': _nullableText(
          form,
          TournamentSettingsControl.contactEmail,
        ),
        'contactPhone': _nullableText(
          form,
          TournamentSettingsControl.contactPhone,
        ),
      }),
      children: [
        _textField(
          TournamentSettingsControl.contactName,
          l10n.tournamentManageContactName,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          TournamentSettingsControl.contactEmail,
          l10n.tournamentManageContactEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        _textField(
          TournamentSettingsControl.contactPhone,
          l10n.tournamentManageContactPhone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class TournamentVideosPanel extends StatefulWidget {
  const TournamentVideosPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;

  @override
  State<TournamentVideosPanel> createState() => _TournamentVideosPanelState();
}

class _TournamentVideosPanelState extends State<TournamentVideosPanel> {
  late final FormGroup form = tournamentVideosForm(widget.tournament);
  FormArray<String> get videos =>
      form.control(TournamentSettingsControl.videos) as FormArray<String>;

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormPanel(
      title: l10n.tournamentManageVideos,
      form: form,
      busy: widget.busy,
      onSubmit: () => widget.onUpdate({
        'youtubeVideoUrls': videos.controls
            .map((control) => control.value?.trim() ?? '')
            .where((url) => url.isNotEmpty)
            .toList(),
      }),
      children: [
        ReactiveFormArray<String>(
          formArrayName: TournamentSettingsControl.videos,
          builder: (context, array, _) => Column(
            children: [
              for (var index = 0; index < array.controls.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: ReactiveTextField<String>(
                          formControl:
                              array.controls[index] as FormControl<String>,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: l10n.tournamentManageVideos,
                          ),
                          validationMessages: {
                            TournamentManagementValidation.invalidYoutubeUrl:
                                (_) => l10n.tournamentManageSaveFailed,
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonDelete,
                        onPressed: array.controls.length == 1
                            ? () => array.controls.first.reset()
                            : () => setState(() => array.removeAt(index)),
                        icon: const Icon(AppIcons.delete),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => videos.add(
                      FormControl<String>(
                        validators: [
                          Validators.delegate((control) {
                            final value =
                                control.value?.toString().trim() ?? '';
                            if (value.isEmpty) return null;
                            final uri = Uri.tryParse(value);
                            final host = uri?.host.toLowerCase() ?? '';
                            return uri?.hasScheme == true &&
                                    (host == 'youtu.be' ||
                                        host == 'youtube.com' ||
                                        host.endsWith('.youtube.com'))
                                ? null
                                : {
                                    TournamentManagementValidation
                                            .invalidYoutubeUrl:
                                        true,
                                  };
                          }),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(AppIcons.add),
                  label: Text(l10n.tournamentManageAddVideo),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TournamentBannerPanel extends ConsumerStatefulWidget {
  const TournamentBannerPanel({
    required this.tournament,
    required this.busy,
    required this.onUpdate,
    required this.onUpload,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final TournamentUpdater onUpdate;
  final Future<({String url, String publicId})> Function(XFile file) onUpload;

  @override
  ConsumerState<TournamentBannerPanel> createState() =>
      _TournamentBannerPanelState();
}

class _TournamentBannerPanelState extends ConsumerState<TournamentBannerPanel> {
  late final FormGroup form = tournamentBannerForm(widget.tournament);
  bool uploading = false;

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url =
        form.control(TournamentSettingsControl.coverPhoto).value as String?;
    return _FormPanel(
      title: l10n.tournamentManageBanner,
      form: form,
      busy: widget.busy || uploading,
      onSubmit: () => widget.onUpdate({
        'coverPhoto': _nullableText(form, TournamentSettingsControl.coverPhoto),
        'coverPhotoPublicId': _nullableText(
          form,
          TournamentSettingsControl.coverPhotoPublicId,
        ),
      }),
      children: [
        if (url?.trim().isNotEmpty ?? false)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 2,
              child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ReactiveTextField<String>(
          formControlName: TournamentSettingsControl.coverPhoto,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l10n.tournamentManageImageUrl),
          validationMessages: {
            TournamentManagementValidation.invalidHttpUrl: (_) =>
                l10n.sessionFormValidationVideo,
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : _pickImage,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.image),
              label: Text(l10n.tournamentManageChooseImage),
            ),
            OutlinedButton.icon(
              onPressed: uploading ? null : _chooseFromLibrary,
              icon: const Icon(AppIcons.grid),
              label: Text(l10n.sessionFormSelectFromGallery),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                form.control(TournamentSettingsControl.coverPhoto).value = '';
                form
                        .control(TournamentSettingsControl.coverPhotoPublicId)
                        .value =
                    '';
              }),
              icon: const Icon(AppIcons.delete),
              label: Text(l10n.tournamentManageRemoveImage),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => uploading = true);
    try {
      final uploaded = await widget.onUpload(file);
      form.control(TournamentSettingsControl.coverPhoto).value = uploaded.url;
      form.control(TournamentSettingsControl.coverPhotoPublicId).value =
          uploaded.publicId;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionFormUploadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _chooseFromLibrary() async {
    final selected = await showModalBottomSheet<TournamentImageAsset>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _TournamentImageLibrarySheet(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      form.control(TournamentSettingsControl.coverPhoto).value = selected.url;
      form.control(TournamentSettingsControl.coverPhotoPublicId).value =
          selected.publicId;
    });
  }
}

class _TournamentImageLibrarySheet extends ConsumerWidget {
  const _TournamentImageLibrarySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final images = ref.watch(tournamentImageLibraryProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.sessionFormSelectFromGallery,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(AppIcons.close),
            ),
          ),
          Expanded(
            child: images.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.sessionFormGalleryError),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(tournamentImageLibraryProvider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(child: Text(l10n.sessionFormGalleryEmpty))
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final image = items[index];
                        return Semantics(
                          button: true,
                          label: l10n.sessionFormSelectFromGallery,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, image),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: CachedNetworkImage(
                                imageUrl: image.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentDeletePanel extends StatefulWidget {
  const TournamentDeletePanel({
    required this.tournament,
    required this.busy,
    required this.onDelete,
    super.key,
  });
  final TournamentDetail tournament;
  final bool busy;
  final Future<void> Function() onDelete;

  @override
  State<TournamentDeletePanel> createState() => _TournamentDeletePanelState();
}

class _TournamentDeletePanelState extends State<TournamentDeletePanel> {
  late final FormGroup form = tournamentDeleteForm(widget.tournament);

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PanelFrame(
      title: l10n.tournamentManageDelete,
      child: AppReactiveForm(
        formGroup: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l10n.tournamentManageDeleteWarning),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ReactiveTextField<String>(
              formControlName: TournamentSettingsControl.confirmName,
              decoration: InputDecoration(
                labelText: l10n.tournamentManageDeleteInstruction,
                helperText: widget.tournament.name,
              ),
              validationMessages: {
                TournamentManagementValidation.tournamentNameMismatch: (_) =>
                    l10n.tournamentManageDeleteMismatch,
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ReactiveFormConsumer(
              builder: (context, form, _) => FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: widget.busy
                    ? null
                    : () async {
                        form.markAllAsTouched();
                        if (form.invalid || form.pending) return;
                        await widget.onDelete();
                      },
                icon: const Icon(AppIcons.delete),
                label: Text(l10n.tournamentManageDelete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.form,
    required this.busy,
    required this.onSubmit,
    required this.children,
  });
  final String title;
  final FormGroup form;
  final bool busy;
  final Future<void> Function() onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: title,
    child: AppReactiveForm(
      formGroup: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          const SizedBox(height: AppSpacing.lg),
          ReactiveFormConsumer(
            builder: (context, form, _) => FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      form.markAllAsTouched();
                      if (form.invalid || form.pending) return;
                      await onSubmit();
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

class _ReactiveDateField extends StatelessWidget {
  const _ReactiveDateField({required this.controlName, required this.label});
  final String controlName;
  final String label;

  @override
  Widget build(BuildContext context) => ReactiveDatePicker<DateTime>(
    formControlName: controlName,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
    builder: (context, picker, _) => InkWell(
      onTap: picker.showPicker,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          picker.value == null
              ? label
              : DateFormat.yMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(picker.value!),
        ),
      ),
    ),
  );
}

ReactiveTextField<String> _textField(
  String controlName,
  String label, {
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
}) => ReactiveTextField<String>(
  formControlName: controlName,
  keyboardType: keyboardType,
  textInputAction: textInputAction,
  decoration: InputDecoration(labelText: label),
);

String _text(FormGroup form, String name) =>
    (form.control(name).value as String? ?? '').trim();
String? _nullableText(FormGroup form, String name) {
  final value = _text(form, name);
  return value.isEmpty ? null : value;
}

Color _statusColor(TournamentStatus status) => switch (status) {
  TournamentStatus.preparing => Colors.grey,
  TournamentStatus.inProgress => AppColors.success,
  TournamentStatus.finished => Colors.blue,
  TournamentStatus.cancelled => AppColors.destructive,
};

String _statusLabel(AppLocalizations l10n, TournamentStatus status) =>
    switch (status) {
      TournamentStatus.preparing => l10n.tournamentStatusPreparing,
      TournamentStatus.inProgress => l10n.tournamentStatusInProgress,
      TournamentStatus.finished => l10n.tournamentStatusFinished,
      TournamentStatus.cancelled => l10n.tournamentStatusCancelled,
    };
