import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_resource_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_fields.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_settings_panels.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Shared compressed uploader, account image library and URL controls for avatar
/// and sponsor logo; uses the same service and library sheet as tournament banner.
class TournamentResourceImageField extends ConsumerStatefulWidget {
  const TournamentResourceImageField({
    required this.form,
    required this.busy,
    required this.onUploading,
    super.key,
  });
  final FormGroup form;
  final bool busy;
  final ValueChanged<bool> onUploading;
  @override
  ConsumerState<TournamentResourceImageField> createState() =>
      _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<TournamentResourceImageField> {
  bool uploading = false;
  void _setAsset(String? url, String? publicId) {
    widget.form.control(ResourceControl.image).value = url;
    widget.form.control(ResourceControl.imagePublicId).value = publicId;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: ResourceControl.image,
      builder: (context, control, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (control.value?.isNotEmpty == true)
            SizedBox(
              height: 120,
              child: Image.network(
                control.value!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image_not_supported),
              ),
            ),
          ReactiveTextField<String>(
            formControlName: ResourceControl.image,
            decoration: InputDecoration(labelText: l.tournamentManageImageUrl),
            keyboardType: TextInputType.url,
            validationMessages: resourceValidationMessages(l),
            onChanged: (_) =>
                widget.form.control(ResourceControl.imagePublicId).value = null,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.busy || uploading ? null : _pick,
                child: Text(
                  uploading ? l.commonLoading : l.tournamentManageChooseImage,
                ),
              ),
              OutlinedButton(
                onPressed: widget.busy || uploading
                    ? null
                    : () async {
                        final asset =
                            await showModalBottomSheet<TournamentImageAsset>(
                              context: context,
                              useSafeArea: true,
                              isScrollControlled: true,
                              builder: (_) => const TournamentImageLibrarySheet(
                                allCategories: true,
                              ),
                            );
                        if (asset != null && mounted) {
                          _setAsset(asset.url, asset.publicId);
                        }
                      },
                child: Text(l.sessionFormSelectFromGallery),
              ),
              TextButton(
                onPressed: widget.busy || uploading
                    ? null
                    : () => _setAsset(null, null),
                child: Text(l.tournamentManageRemoveImage),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    setState(() => uploading = true);
    widget.onUploading(true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final asset = await ref
          .read(tournamentResourceImageProvider.notifier)
          .upload(bytes, file.name);
      if (mounted && asset != null) {
        _setAsset(asset.url, asset.publicId);
        ref.invalidate(tournamentAllImagesProvider);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionFormUploadFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => uploading = false);
        widget.onUploading(false);
      }
    }
  }
}
