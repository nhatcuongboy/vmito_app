import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/location/google_places_service.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/form/post_composer_reactive_form.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _maxPostImages = 5;

/// Mobile counterpart of the web create-post modal.
class PostComposerSheet extends ConsumerStatefulWidget {
  const PostComposerSheet({
    required this.userName,
    required this.onSubmit,
    super.key,
    this.userImage,
  });

  final String userName;
  final String? userImage;
  final Future<void> Function(PostComposerDraft draft) onSubmit;

  @override
  ConsumerState<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<PostComposerSheet> {
  final FormGroup _form = createPostComposerReactiveForm();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();
  final _locationController = TextEditingController();
  final _locationFocusNode = FocusNode();
  final _locationSuggestions = <PlaceSuggestion>[];
  StreamSubscription<dynamic>? _formSubscription;
  Timer? _locationDebounce;
  bool _isUploading = false;
  bool _isSubmitting = false;
  bool _showingLocationPanel = false;
  bool _isSearchingLocations = false;

  List<PostImageDraft> get _images =>
      _form.control(PostComposerFormControl.images).value
          as List<PostImageDraft>? ??
      const [];

  PostLocationDraft? get _location =>
      _form.control(PostComposerFormControl.location).value
          as PostLocationDraft?;

  bool get _hasDraft {
    final content =
        _form.control(PostComposerFormControl.content).value as String? ?? '';
    return content.trim().isNotEmpty || _images.isNotEmpty || _location != null;
  }

  @override
  void initState() {
    super.initState();
    _formSubscription = _form.valueChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_formSubscription?.cancel() ?? Future<void>.value());
    _locationDebounce?.cancel();
    _scrollController.dispose();
    _locationController.dispose();
    _locationFocusNode.dispose();
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<bool>(
      canPop: !_hasDraft && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .94,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: _showingLocationPanel
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: l10n.socialCreatePost,
                          onPressed: _isSubmitting ? null : _closeLocationPanel,
                          icon: const Icon(AppIcons.arrowBack),
                        ),
                        Text(l10n.socialAddLocation),
                      ],
                    )
                  : Text(l10n.socialCreatePost),
              centerTitle: !_showingLocationPanel,
              actions: [
                IconButton(
                  key: const Key('post-composer-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _isSubmitting ? null : _requestClose,
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            body: _showingLocationPanel
                ? _buildLocationPanel(context)
                : ReactiveForm(
                    formGroup: _form,
                    child: _buildComposer(context),
                  ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: FilledButton(
                  key: const Key('post-composer-submit'),
                  onPressed: _isSubmitting || _isUploading || _form.invalid
                      ? null
                      : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.socialPublish),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PostAvatar(name: widget.userName, imageUrl: widget.userImage),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.userName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ReactiveTextField<String>(
            key: const Key('post-content-field'),
            formControlName: PostComposerFormControl.content,
            autofocus: true,
            minLines: 6,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: l10n.socialComposerNameHint(widget.userName),
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            validationMessages: {
              ValidationMessage.required: (_) => l10n.socialContentRequired,
            },
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PostImageGrid(images: _images, onChanged: _setImages),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: palette.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Text(
                      l10n.socialAddToPost,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('post-composer-add-device-images'),
                  tooltip: l10n.socialAddPhotos,
                  color: theme.colorScheme.primary,
                  onPressed: _isUploading || _images.length >= _maxPostImages
                      ? null
                      : _pickDeviceImages,
                  icon: _isUploading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.imagePlus),
                ),
                IconButton(
                  key: const Key('post-composer-open-image-library'),
                  tooltip: l10n.socialSelectFromGallery,
                  color: theme.colorScheme.primary,
                  onPressed: _isUploading || _images.length >= _maxPostImages
                      ? null
                      : _openImageLibrary,
                  icon: const Icon(AppIcons.image),
                ),
                IconButton(
                  key: const Key('post-composer-open-location'),
                  tooltip: l10n.socialAddLocation,
                  color: _location == null
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  onPressed: _isSubmitting ? null : _openLocationPanel,
                  icon: const Icon(AppIcons.location),
                ),
              ],
            ),
          ),
          if (_location case final location?) ...[
            const SizedBox(height: AppSpacing.sm),
            _SelectedLocationCard(
              location: location,
              onRemove: _isSubmitting ? null : _removeLocation,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _locationController,
            focusNode: _locationFocusNode,
            autofocus: true,
            enabled: !_isSearchingLocations && AppConfig.hasGooglePlaces,
            decoration: InputDecoration(
              hintText: AppConfig.hasGooglePlaces
                  ? l10n.socialLocationPlaceholder
                  : l10n.socialLocationSearchFailed,
              prefixIcon: const Icon(AppIcons.search),
              suffixIcon: _isSearchingLocations
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _scheduleLocationSearch,
          ),
        ),
        if (_location case final location?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _SelectedLocationCard(
              location: location,
              onRemove: _removeLocation,
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _locationSuggestions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final suggestion = _locationSuggestions[index];
              return ListTile(
                leading: const Icon(AppIcons.location),
                title: Text(suggestion.primaryText),
                subtitle: suggestion.secondaryText.isEmpty
                    ? null
                    : Text(suggestion.secondaryText),
                onTap: _isSearchingLocations
                    ? null
                    : () => _selectLocation(suggestion),
              );
            },
          ),
        ),
      ],
    );
  }

  void _setImages(List<PostImageDraft> images) {
    _form.control(PostComposerFormControl.images).value =
        List<PostImageDraft>.unmodifiable(images);
  }

  Future<void> _pickDeviceImages() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      limit: _maxPostImages - _images.length,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() => _isUploading = true);
    final uploaded = <PostImageDraft>[];
    try {
      for (final image in picked) {
        uploaded.add(
          await ref
              .read(socialServiceProvider)
              .uploadPostImage(
                bytes: await image.readAsBytes(),
                filename: image.name.isEmpty
                    ? 'post-${DateTime.now().millisecondsSinceEpoch}.jpg'
                    : image.name,
              ),
        );
      }
      if (mounted) {
        _setImages([..._images, ...uploaded]);
      }
    } on Object {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).socialImageUploadFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openImageLibrary() async {
    final selected = await showModalBottomSheet<List<PostImageDraft>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PostImageLibrarySheet(initialSelection: _images),
    );
    if (selected != null && mounted) {
      _setImages(selected);
    }
  }

  void _openLocationPanel() {
    setState(() => _showingLocationPanel = true);
  }

  void _closeLocationPanel() {
    _locationDebounce?.cancel();
    setState(() {
      _showingLocationPanel = false;
      _locationSuggestions.clear();
      _locationController.clear();
      _isSearchingLocations = false;
    });
  }

  void _removeLocation() {
    _form.control(PostComposerFormControl.location).value = null;
  }

  void _scheduleLocationSearch(String query) {
    _locationDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(_locationSuggestions.clear);
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchLocations(query));
    });
  }

  Future<void> _searchLocations(String query) async {
    if (!AppConfig.hasGooglePlaces) return;
    setState(() => _isSearchingLocations = true);
    try {
      final suggestions = await ref
          .read(googlePlacesServiceProvider)
          .autocomplete(
            input: query,
            language: Localizations.localeOf(context).languageCode,
          );
      if (mounted && _locationController.text == query) {
        setState(() {
          _locationSuggestions
            ..clear()
            ..addAll(suggestions);
        });
      }
    } on Object {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).socialLocationSearchFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocations = false);
      }
    }
  }

  Future<void> _selectLocation(PlaceSuggestion suggestion) async {
    setState(() => _isSearchingLocations = true);
    try {
      final details = await ref
          .read(googlePlacesServiceProvider)
          .details(
            placeId: suggestion.placeId,
            language: Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      final latitude = details.latitude;
      final longitude = details.longitude;
      if (latitude == null || longitude == null) {
        _showMessage(AppLocalizations.of(context).socialLocationUnavailable);
        return;
      }
      _form.control(PostComposerFormControl.location).value = PostLocationDraft(
        name: suggestion.primaryText,
        address: details.address,
        latitude: latitude,
        longitude: longitude,
      );
      _closeLocationPanel();
    } on Object {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).socialLocationSearchFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocations = false);
      }
    }
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _isUploading || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(postComposerDraftFromForm(_form));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).socialPostCreateFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _requestClose() async {
    if (_isSubmitting) return;
    if (!_hasDraft) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.socialPostDiscardTitle),
        content: Text(l10n.socialPostDiscardDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.socialPostKeepEditing),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.socialPostDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({required this.location, required this.onRemove});

  final PostLocationDraft location;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(AppIcons.location, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location.address != location.name)
                    Text(
                      location.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).socialRemoveLocation,
            onPressed: onRemove,
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    );
  }
}

class _PostImageGrid extends StatelessWidget {
  const _PostImageGrid({required this.images, required this.onChanged});

  final List<PostImageDraft> images;
  final ValueChanged<List<PostImageDraft>> onChanged;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.25,
    ),
    itemCount: images.length,
    itemBuilder: (context, index) {
      final image = images[index];
      return DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) {
          final reordered = [...images];
          final moving = reordered.removeAt(details.data);
          reordered.insert(index, moving);
          onChanged(reordered);
        },
        builder: (context, _, _) => LongPressDraggable<int>(
          data: index,
          feedback: Material(
            child: SizedBox(
              width: 150,
              height: 120,
              child: _PostImageTile(image: image, onRemove: null),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: .35,
            child: _PostImageTile(image: image, onRemove: null),
          ),
          child: _PostImageTile(
            image: image,
            onRemove: () => onChanged([
              for (var itemIndex = 0; itemIndex < images.length; itemIndex++)
                if (itemIndex != index) images[itemIndex],
            ]),
          ),
        ),
      );
    },
  );
}

class _PostImageTile extends StatelessWidget {
  const _PostImageTile({required this.image, required this.onRemove});

  final PostImageDraft image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: image.url, fit: BoxFit.cover),
        if (onRemove != null)
          Align(
            alignment: Alignment.topRight,
            child: IconButton.filledTonal(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(AppIcons.close, size: 18),
            ),
          ),
        const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xs),
            child: Icon(Icons.drag_handle, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _PostImageLibrarySheet extends ConsumerStatefulWidget {
  const _PostImageLibrarySheet({required this.initialSelection});

  final List<PostImageDraft> initialSelection;

  @override
  ConsumerState<_PostImageLibrarySheet> createState() =>
      _PostImageLibrarySheetState();
}

class _PostImageLibrarySheetState
    extends ConsumerState<_PostImageLibrarySheet> {
  final _images = <PostImageDraft>[];
  late final Map<String, PostImageDraft> _selected;
  var _page = 0;
  var _totalPages = 1;
  var _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final image in widget.initialSelection) image.publicId: image,
    };
    unawaited(_loadPage(1));
  }

  Future<void> _loadPage(int page) async {
    if (_loading || page > _totalPages && _page > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(socialServiceProvider)
          .postImages(page: page);
      if (!mounted) return;
      setState(() {
        final ids = _images.map((image) => image.publicId).toSet();
        _images.addAll(result.items.where((image) => ids.add(image.publicId)));
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(PostImageDraft image) {
    if (_selected.remove(image.publicId) != null) {
      setState(() {});
      return;
    }
    if (_selected.length >= _maxPostImages) return;
    setState(() => _selected[image.publicId] = image);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.socialImageLibraryTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(l10n.socialImageSelection(_selected.length)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildContent(context)),
            if (_page < _totalPages)
              TextButton(
                onPressed: _loading ? null : () => _loadPage(_page + 1),
                child: Text(l10n.commonLoadMore),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _selected.values.toList(growable: false),
                      ),
                      child: Text(l10n.commonConfirm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _images.isEmpty) {
      return Center(child: Text(l10n.socialImageLibraryFailed));
    }
    if (_images.isEmpty) {
      return Center(child: Text(l10n.socialImageLibraryEmpty));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        final selected = _selected.containsKey(image.publicId);
        return InkWell(
          onTap: () => _toggle(image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: image.url, fit: BoxFit.cover),
              if (selected)
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: CircleAvatar(
                      radius: 12,
                      child: Icon(AppIcons.check, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
