import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/address_display.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/club_user_option.dart';
import 'package:vmito_app/features/social/domain/form/club_form.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/level_badge_picker.dart';

class ClubFormScreen extends ConsumerWidget {
  const ClubFormScreen({this.clubId, super.key});

  final String? clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clubId == null) return const _ClubForm();
    final club = ref.watch(managedClubProvider(clubId!));
    return club.when(
      data: (value) => _ClubForm(initialClub: value),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(managedClubProvider(clubId!)),
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ClubForm extends ConsumerStatefulWidget {
  const _ClubForm({this.initialClub});

  final ClubSummary? initialClub;

  @override
  ConsumerState<_ClubForm> createState() => _ClubFormState();
}

class _ClubFormState extends ConsumerState<_ClubForm> {
  late final FormGroup _form;
  final _imagePicker = ImagePicker();
  final _venueGroups = <ClubVenueGroupDraft>[];
  final _venues = <String, Venue>{};
  bool _uploadingImages = false;
  bool _uploadingLogo = false;
  bool _socialLinksOpen = false;

  bool get _editing => widget.initialClub != null;

  @override
  void initState() {
    super.initState();
    final club = widget.initialClub;
    final user = ref.read(currentUserProvider);
    final hostName = club?.hostName ?? user?.displayName ?? '';
    _form = createClubForm(
      hostName: hostName,
      name: club?.name,
      description: club?.description,
      location: club?.location,
      maxMembers: club?.maxMembers,
      joinPolicy: club?.joinPolicy ?? 'APPROVAL_REQUIRED',
      isPublic: club?.isPublic ?? true,
      selectedHostUserId: club?.hostId,
      requiredLevels: club?.requiredLevels ?? const [],
      images: club?.images ?? const [],
      imagePublicIds: club?.imagePublicIds ?? const [],
      logo: club?.logo,
      logoPublicId: club?.logoPublicId,
      socialLinks: club?.socialLinks ?? const {},
    );
    _seedVenueState(club);
  }

  void _seedVenueState(ClubSummary? club) {
    final venue = club?.defaultVenue;
    if (venue?.id == null) return;
    final venueId = venue!.id!;
    _venues[venueId] = Venue(
      id: venueId,
      name: venue.name,
      address: venue.address,
    );
    _venueGroups.add(
      ClubVenueGroupDraft(
        id: _newId(),
        venueId: venueId,
        schedules: [
          for (final schedule in club!.schedules)
            ClubScheduleDraft(
              id: _newId(),
              dayOfWeek: schedule.dayOfWeek,
              startTime: schedule.startTime,
              endTime: schedule.endTime,
              isActive: schedule.isActive,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(clubManagementControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l10n.clubEdit : l10n.clubCreate)),
      body: LayoutBuilder(
        builder: (context, constraints) => AppReactiveForm(
          formGroup: _form,
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  constraints.maxWidth < 720 ? 112 : AppSpacing.md,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildForm(
                        context,
                        constraints.maxWidth,
                        saving: saving,
                      ),
                    ),
                  ),
                ],
              ),
              if (constraints.maxWidth < 720)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _SubmitBar(
                    saving: saving,
                    editing: _editing,
                    onPressed: saving ? null : _save,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    double width, {
    required bool saving,
  }) {
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final wide = width >= 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormCard(
          title: l10n.clubBasicInformation,
          children: [
            ReactiveTextField<String>(
              key: const Key('club-name-field'),
              formControlName: ClubFormControl.name,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                label: AppRequiredLabel(l10n.clubName),
                hintText: l10n.clubNamePlaceholder,
              ),
              validationMessages: {
                ValidationMessage.required: (_) => l10n.clubNameRequired,
                ValidationMessage.maxLength: (_) => l10n.clubNameTooLong,
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ReactiveTextField<String>(
              key: const Key('club-host-name-field'),
              formControlName: ClubFormControl.hostName,
              maxLength: 100,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                label: AppRequiredLabel(l10n.clubHostName),
                hintText: l10n.clubHostNamePlaceholder,
              ),
              validationMessages: {
                ValidationMessage.required: (_) => l10n.clubHostNameRequired,
                ValidationMessage.maxLength: (_) => l10n.clubHostNameTooLong,
              },
            ),
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.md),
              _HostUserField(form: _form, onPick: _pickHostUser),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _LevelRequirementsCard(form: _form),
        const SizedBox(height: AppSpacing.md),
        _FormCard(
          title: l10n.clubDescription,
          children: [
            ReactiveTextField<String>(
              formControlName: ClubFormControl.description,
              maxLength: 5000,
              minLines: 4,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l10n.clubDescriptionPlaceholder,
                alignLabelWithHint: true,
              ),
              validationMessages: {
                ValidationMessage.maxLength: (_) => l10n.clubDescriptionTooLong,
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ClubMediaCard(
          form: _form,
          uploadingImages: _uploadingImages,
          uploadingLogo: _uploadingLogo,
          onPickImages: _pickImages,
          onPickLogo: _pickLogo,
          onOpenImageLibrary: () => _openImageLibrary(maxSelection: 10),
          onOpenLogoLibrary: () => _openImageLibrary(maxSelection: 1),
          onRemoveImage: _removeImage,
          onSetBanner: (index) =>
              _form.control(ClubFormControl.bannerIndex).value = index,
          onRemoveLogo: _removeLogo,
          onReorderImages: _reorderImages,
        ),
        const SizedBox(height: AppSpacing.md),
        _ClubVenueScheduleCard(
          groups: _venueGroups,
          venues: _venues,
          wide: wide,
          onAddVenue: _addVenue,
          onRemoveVenue: _removeVenue,
          onPickVenue: _pickVenue,
          onAddSchedule: _addSchedule,
          onRemoveSchedule: _removeSchedule,
          onUpdateSchedule: _updateSchedule,
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialLinksCard(
          form: _form,
          open: _socialLinksOpen,
          onChanged: (value) => setState(() => _socialLinksOpen = value),
        ),
        if (width >= 720) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineSubmitButton(
            saving: saving,
            editing: _editing,
            onPressed: saving ? null : _save,
          ),
        ],
      ],
    );
  }

  Future<void> _pickHostUser() async {
    final user = await showModalBottomSheet<ClubHostUserOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _HostUserPickerSheet(),
    );
    if (user == null || !mounted) return;
    _form.control(ClubFormControl.hostUserId).value = user.id;
    _form.control(ClubFormControl.hostName).value = user.name;
  }

  Future<void> _pickImages() async {
    if (_uploadingImages) return;
    final remaining = 10 - _images.length;
    if (remaining <= 0) return;
    final picked = await _imagePicker.pickMultiImage(limit: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploadingImages = true);
    try {
      final uploaded = <ClubImageAsset>[];
      for (final file in picked.take(remaining)) {
        final result = await ref
            .read(socialServiceProvider)
            .uploadClubImage(
              bytes: await file.readAsBytes(),
              filename: file.name,
              logo: false,
            );
        uploaded.add(
          ClubImageAsset(id: '', url: result.url, publicId: result.publicId),
        );
      }
      _appendImages(uploaded);
    } on Object {
      if (mounted) {
        _showError(AppLocalizations.of(context).clubImageUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  Future<void> _pickLogo() async {
    if (_uploadingLogo) return;
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _uploadingLogo = true);
    try {
      final result = await ref
          .read(socialServiceProvider)
          .uploadClubImage(
            bytes: await picked.readAsBytes(),
            filename: picked.name,
            logo: true,
          );
      _setLogo(
        ClubImageAsset(id: '', url: result.url, publicId: result.publicId),
      );
    } on Object {
      if (mounted) {
        _showError(AppLocalizations.of(context).clubImageUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _openImageLibrary({required int maxSelection}) async {
    final selected = await showModalBottomSheet<List<ClubImageAsset>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ClubImageLibrarySheet(
        maxSelection: maxSelection,
        category: maxSelection == 1 ? 'CLUB' : 'CLUB_COVER',
        initialSelection: maxSelection == 1
            ? [_logoAsset].whereType<ClubImageAsset>().toList()
            : _imageAssets,
      ),
    );
    if (selected == null || !mounted) return;
    if (maxSelection == 1) {
      _setLogo(selected.isEmpty ? null : selected.first);
    } else {
      _setImages(selected);
    }
  }

  void _appendImages(List<ClubImageAsset> additions) {
    final current = _imageAssets;
    final ids = current.map((image) => image.publicId).toSet();
    _setImages([
      ...current,
      ...additions.where((image) => ids.add(image.publicId)),
    ]);
  }

  void _setImages(List<ClubImageAsset> images) {
    final urls = images.map((image) => image.url).toList(growable: false);
    final publicIds = images
        .map((image) => image.publicId)
        .toList(growable: false);
    _form.control(ClubFormControl.images).value = urls;
    _form.control(ClubFormControl.imagePublicIds).value = publicIds;
    if (images.isEmpty) {
      _form.control(ClubFormControl.bannerIndex).value = 0;
    } else if (_bannerIndex >= images.length) {
      _form.control(ClubFormControl.bannerIndex).value = images.length - 1;
    }
  }

  void _setLogo(ClubImageAsset? image) {
    _form.control(ClubFormControl.logo).value = image?.url ?? '';
    _form.control(ClubFormControl.logoPublicId).value = image?.publicId ?? '';
  }

  void _removeImage(int index) {
    final next = _imageAssets..removeAt(index);
    _setImages(next);
  }

  void _removeLogo() => _setLogo(null);

  void _reorderImages(int oldIndex, int newIndex) {
    final next = _imageAssets;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _setImages(next);
    if (_bannerIndex == oldIndex) {
      _form.control(ClubFormControl.bannerIndex).value = newIndex;
    }
  }

  List<ClubImageAsset> get _imageAssets => [
    for (var index = 0; index < _images.length; index++)
      ClubImageAsset(
        id: '',
        url: _images[index],
        publicId: index < _imagePublicIds.length ? _imagePublicIds[index] : '',
      ),
  ];

  ClubImageAsset? get _logoAsset {
    final url = _form.control(ClubFormControl.logo).value as String? ?? '';
    if (url.isEmpty) return null;
    return ClubImageAsset(
      id: '',
      url: url,
      publicId:
          _form.control(ClubFormControl.logoPublicId).value as String? ?? '',
    );
  }

  List<String> get _images =>
      (_form.control(ClubFormControl.images).value as List<String>?) ??
      const [];

  List<String> get _imagePublicIds =>
      (_form.control(ClubFormControl.imagePublicIds).value as List<String>?) ??
      const [];

  int get _bannerIndex =>
      (_form.control(ClubFormControl.bannerIndex).value as int?) ?? 0;

  void _addVenue() => setState(
    () => _venueGroups.add(ClubVenueGroupDraft(id: _newId())),
  );

  void _removeVenue(String groupId) => setState(
    () => _venueGroups.removeWhere((group) => group.id == groupId),
  );

  Future<void> _pickVenue(String groupId) async {
    final venue = await showModalBottomSheet<Venue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VenuePickerSheet(
        excludedVenueIds: {
          for (final group in _venueGroups)
            if (group.id != groupId && group.venueId.isNotEmpty) group.venueId,
        },
      ),
    );
    if (venue == null || !mounted) return;
    setState(() {
      _venues[venue.id] = venue;
      final index = _venueGroups.indexWhere((group) => group.id == groupId);
      if (index >= 0) {
        _venueGroups[index] = _venueGroups[index].copyWith(venueId: venue.id);
      }
    });
  }

  void _addSchedule(String groupId) => setState(() {
    final index = _venueGroups.indexWhere((group) => group.id == groupId);
    if (index < 0) return;
    final group = _venueGroups[index];
    _venueGroups[index] = group.copyWith(
      schedules: [
        ...group.schedules,
        ClubScheduleDraft(
          id: _newId(),
          dayOfWeek: 1,
          startTime: '19:00',
          endTime: '21:00',
        ),
      ],
    );
  });

  void _removeSchedule(String groupId, String scheduleId) => setState(() {
    final index = _venueGroups.indexWhere((group) => group.id == groupId);
    if (index < 0) return;
    final group = _venueGroups[index];
    _venueGroups[index] = group.copyWith(
      schedules: group.schedules
          .where((item) => item.id != scheduleId)
          .toList(),
    );
  });

  Future<void> _updateSchedule(
    String groupId,
    String scheduleId,
    Map<String, Object?> changes,
  ) async {
    final groupIndex = _venueGroups.indexWhere((group) => group.id == groupId);
    if (groupIndex < 0) return;
    final group = _venueGroups[groupIndex];
    final scheduleIndex = group.schedules.indexWhere(
      (item) => item.id == scheduleId,
    );
    if (scheduleIndex < 0) return;
    final current = group.schedules[scheduleIndex];
    var startTime = current.startTime;
    var endTime = current.endTime;
    if (changes.containsKey('startTime') || changes.containsKey('endTime')) {
      final isStart = changes.containsKey('startTime');
      final selected = await showTimePicker(
        context: context,
        initialTime: _parseTime(isStart ? startTime : endTime),
      );
      if (selected == null || !mounted) return;
      final result =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        startTime = result;
      } else {
        endTime = result;
      }
    }
    setState(() {
      final next = [...group.schedules];
      next[scheduleIndex] = ClubScheduleDraft(
        id: current.id,
        dayOfWeek: changes['dayOfWeek'] as int? ?? current.dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        isActive: changes['isActive'] as bool? ?? current.isActive,
      );
      _venueGroups[groupIndex] = group.copyWith(schedules: next);
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 19,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
  }

  Future<void> _save() async {
    _form.markAllAsTouched();
    final venueValidation = validateClubVenueSchedule(_venueGroups);
    if (_form.invalid || _form.pending || !venueValidation.isValid) {
      if (!venueValidation.isValid) {
        _showError(AppLocalizations.of(context).clubVenueValidationSummary);
      }
      return;
    }
    try {
      final club = await ref
          .read(clubManagementControllerProvider.notifier)
          .saveClub(_draftFromForm(), clubId: widget.initialClub?.id);
      if (!mounted) return;
      if (_editing) {
        context.pop();
      } else {
        context.go(AppRoutes.clubDetail(club.slug ?? club.id));
      }
    } on Object {
      if (mounted) {
        _showError(
          _editing
              ? AppLocalizations.of(context).clubUpdateFailed
              : AppLocalizations.of(context).clubCreateFailed,
        );
      }
    }
  }

  ClubDraft _draftFromForm() {
    String value(String key) => _form.control(key).value as String? ?? '';
    final maxMembers = int.tryParse(value(ClubFormControl.maxMembers).trim());
    final selectedHostUserId = value(ClubFormControl.hostUserId).trim();
    final schedules = <Map<String, dynamic>>[];
    for (final group in _venueGroups) {
      final venue = _venues[group.venueId];
      final notes = venue == null ? null : '${venue.name} | ${venue.address}';
      for (final schedule in group.schedules) {
        schedules.add({
          'dayOfWeek': schedule.dayOfWeek,
          'startTime': schedule.startTime,
          'endTime': schedule.endTime,
          if (notes?.isNotEmpty ?? false) 'notes': notes,
          'isActive': schedule.isActive,
        });
      }
    }
    final socialControls = {
      'facebook': ClubFormControl.socialFacebook,
      'zalo': ClubFormControl.socialZalo,
      'tiktok': ClubFormControl.socialTiktok,
      'youtube': ClubFormControl.socialYoutube,
      'website': ClubFormControl.socialWebsite,
      'other': ClubFormControl.socialOther,
    };
    final links = <String, String>{
      for (final entry in socialControls.entries)
        if (value(entry.value).trim().isNotEmpty)
          entry.key: value(entry.value).trim(),
    };
    return ClubDraft(
      name: value(ClubFormControl.name),
      hostName: value(ClubFormControl.hostName),
      hostUserId: selectedHostUserId.isEmpty ? null : selectedHostUserId,
      description: value(ClubFormControl.description),
      location: value(ClubFormControl.location),
      maxMembers: maxMembers,
      defaultVenueId: _venueGroups.isEmpty
          ? null
          : _venueGroups.first.venueId.trim().isEmpty
          ? null
          : _venueGroups.first.venueId,
      joinPolicy: value(ClubFormControl.joinPolicy),
      isPublic: _form.control(ClubFormControl.isPublic).value as bool? ?? true,
      image: _images.isEmpty
          ? null
          : _images[_bannerIndex.clamp(0, _images.length - 1)],
      imagePublicId: _imagePublicIds.isEmpty
          ? null
          : _imagePublicIds[_bannerIndex.clamp(0, _imagePublicIds.length - 1)],
      images: _images,
      imagePublicIds: _imagePublicIds,
      logo: value(ClubFormControl.logo),
      logoPublicId: value(ClubFormControl.logoPublicId),
      requiredLevels:
          ((_form.control(ClubFormControl.requiredLevels).value
                      as List<int>?) ??
                  const [])
              .toList(growable: false),
      schedules: schedules,
      socialLinks: links,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.saving,
    required this.editing,
    required this.onPressed,
  });

  final bool saving;
  final bool editing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 8,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('club-save-button'),
                onPressed: onPressed,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(editing ? AppIcons.save : AppIcons.add),
                label: Text(editing ? l10n.commonSave : l10n.clubCreate),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSubmitButton extends StatelessWidget {
  const _InlineSubmitButton({
    required this.saving,
    required this.editing,
    required this.onPressed,
  });

  final bool saving;
  final bool editing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        key: const Key('club-save-button'),
        onPressed: onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(editing ? AppIcons.save : AppIcons.add),
        label: Text(editing ? l10n.commonSave : l10n.clubCreate),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _HostUserField extends StatelessWidget {
  const _HostUserField({required this.form, required this.onPick});

  final FormGroup form;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: ClubFormControl.hostUserId,
      builder: (context, value, _) => OutlinedButton.icon(
        key: const Key('club-host-user-button'),
        onPressed: onPick,
        icon: const Icon(AppIcons.search),
        label: Text(
          value.value?.isNotEmpty == true
              ? form.control(ClubFormControl.hostName).value as String? ??
                    l10n.clubSelectHostUser
              : l10n.clubSelectHostUser,
        ),
      ),
    );
  }
}

class _LevelRequirementsCard extends StatelessWidget {
  const _LevelRequirementsCard({required this.form});

  final FormGroup form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: l10n.clubRequiredLevels,
              trailing: IconButton(
                tooltip: l10n.levelDescriptionsTitle,
                onPressed: () => showLevelDescriptions(context),
                icon: const Icon(AppIcons.info),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ReactiveValueListenableBuilder<List<int>>(
              formControlName: ClubFormControl.requiredLevels,
              builder: (context, value, _) {
                final selected = value.value ?? const <int>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LevelBadgePicker(
                      selectedLevels: selected,
                      allLevelsLabel: l10n.clubAllLevels,
                      allLevelsKey: const Key('club-all-levels'),
                      levelKeyPrefix: 'club-level',
                      onChanged: (levels) =>
                          form.control(ClubFormControl.requiredLevels).value =
                              levels,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubMediaCard extends StatelessWidget {
  const _ClubMediaCard({
    required this.form,
    required this.uploadingImages,
    required this.uploadingLogo,
    required this.onPickImages,
    required this.onPickLogo,
    required this.onOpenImageLibrary,
    required this.onOpenLogoLibrary,
    required this.onRemoveImage,
    required this.onSetBanner,
    required this.onRemoveLogo,
    required this.onReorderImages,
  });

  final FormGroup form;
  final bool uploadingImages;
  final bool uploadingLogo;
  final VoidCallback onPickImages;
  final VoidCallback onPickLogo;
  final VoidCallback onOpenImageLibrary;
  final VoidCallback onOpenLogoLibrary;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onSetBanner;
  final VoidCallback onRemoveLogo;
  final void Function(int oldIndex, int newIndex) onReorderImages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: l10n.clubMediaTitle,
              description: l10n.clubMediaDescription,
            ),
            const SizedBox(height: AppSpacing.md),
            ReactiveValueListenableBuilder<List<String>>(
              formControlName: ClubFormControl.images,
              builder: (context, value, _) {
                final images = value.value ?? const <String>[];
                final banner =
                    form.control(ClubFormControl.bannerIndex).value as int? ??
                    0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l10n.clubCoverPhotos)),
                        Text('${images.length}/10'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (images.isEmpty)
                      _EmptyMediaState(
                        label: l10n.clubNoImages,
                        onUpload: onPickImages,
                        onLibrary: onOpenImageLibrary,
                        loading: uploadingImages,
                      )
                    else ...[
                      SizedBox(
                        height: 124,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          onReorderItem: onReorderImages,
                          itemBuilder: (context, index) => _ImageTile(
                            key: ValueKey('club-image-$index-${images[index]}'),
                            url: images[index],
                            selected: index == banner,
                            onSelect: () => onSetBanner(index),
                            onRemove: () => onRemoveImage(index),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _MediaActions(
                        loading: uploadingImages,
                        disabled: images.length >= 10,
                        onUpload: onPickImages,
                        onLibrary: onOpenImageLibrary,
                      ),
                    ],
                  ],
                );
              },
            ),
            const Divider(height: AppSpacing.xl),
            ReactiveValueListenableBuilder<String>(
              formControlName: ClubFormControl.logo,
              builder: (context, value, _) {
                final logo = value.value ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.clubLogoTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.clubLogoDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (logo.isEmpty)
                      _EmptyMediaState(
                        label: l10n.clubNoLogo,
                        onUpload: onPickLogo,
                        onLibrary: onOpenLogoLibrary,
                        loading: uploadingLogo,
                      )
                    else
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: CachedNetworkImage(
                              imageUrl: logo,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  const Icon(AppIcons.imageOff),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                OutlinedButton(
                                  onPressed: uploadingLogo ? null : onPickLogo,
                                  child: Text(l10n.clubUploadLogo),
                                ),
                                TextButton(
                                  onPressed: onRemoveLogo,
                                  child: Text(l10n.commonRemove),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required super.key,
    required this.url,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final String url;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    margin: const EdgeInsets.only(right: AppSpacing.sm),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        width: 3,
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const ColoredBox(
            color: Colors.black12,
            child: Icon(AppIcons.imageOff),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(
            color: Colors.black54,
            child: Row(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).clubSetCover,
                  onPressed: onSelect,
                  icon: Icon(
                    selected ? AppIcons.star : Icons.star_border,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).commonRemove,
                  onPressed: onRemove,
                  icon: const Icon(
                    AppIcons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState({
    required this.label,
    required this.onUpload,
    required this.onLibrary,
    required this.loading,
  });

  final String label;
  final VoidCallback onUpload;
  final VoidCallback onLibrary;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      children: [
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        _MediaActions(
          loading: loading,
          disabled: false,
          onUpload: onUpload,
          onLibrary: onLibrary,
        ),
      ],
    ),
  );
}

class _MediaActions extends StatelessWidget {
  const _MediaActions({
    required this.loading,
    required this.disabled,
    required this.onUpload,
    required this.onLibrary,
  });

  final bool loading;
  final bool disabled;
  final VoidCallback onUpload;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: loading || disabled ? null : onUpload,
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.upload, size: 18),
          label: Text(l10n.clubUploadImage),
        ),
        OutlinedButton(
          onPressed: loading ? null : onLibrary,
          child: Text(l10n.clubSelectFromGallery),
        ),
      ],
    );
  }
}

class _ClubVenueScheduleCard extends StatelessWidget {
  const _ClubVenueScheduleCard({
    required this.groups,
    required this.venues,
    required this.wide,
    required this.onAddVenue,
    required this.onRemoveVenue,
    required this.onPickVenue,
    required this.onAddSchedule,
    required this.onRemoveSchedule,
    required this.onUpdateSchedule,
  });

  final List<ClubVenueGroupDraft> groups;
  final Map<String, Venue> venues;
  final bool wide;
  final VoidCallback onAddVenue;
  final ValueChanged<String> onRemoveVenue;
  final ValueChanged<String> onPickVenue;
  final ValueChanged<String> onAddSchedule;
  final void Function(String, String) onRemoveSchedule;
  final Future<void> Function(String, String, Map<String, Object?>)
  onUpdateSchedule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: l10n.clubVenueTitle,
              description: l10n.clubVenueDescription,
            ),
            const SizedBox(height: AppSpacing.md),
            if (groups.isEmpty)
              OutlinedButton.icon(
                key: const Key('club-add-venue'),
                onPressed: onAddVenue,
                icon: const Icon(AppIcons.addLocation),
                label: Text(l10n.clubAddVenue),
              )
            else ...[
              for (var index = 0; index < groups.length; index++) ...[
                _VenueGroupCard(
                  group: groups[index],
                  venue: venues[groups[index].venueId],
                  number: index + 1,
                  wide: wide,
                  onRemove: () => onRemoveVenue(groups[index].id),
                  onPickVenue: () => onPickVenue(groups[index].id),
                  onAddSchedule: () => onAddSchedule(groups[index].id),
                  onRemoveSchedule: (scheduleId) =>
                      onRemoveSchedule(groups[index].id, scheduleId),
                  onUpdateSchedule: (scheduleId, values) =>
                      onUpdateSchedule(groups[index].id, scheduleId, values),
                ),
                if (index != groups.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onAddVenue,
                icon: const Icon(AppIcons.add),
                label: Text(l10n.clubAddAnotherVenue),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VenueGroupCard extends ConsumerWidget {
  const _VenueGroupCard({
    required this.group,
    required this.venue,
    required this.number,
    required this.wide,
    required this.onRemove,
    required this.onPickVenue,
    required this.onAddSchedule,
    required this.onRemoveSchedule,
    required this.onUpdateSchedule,
  });

  final ClubVenueGroupDraft group;
  final Venue? venue;
  final int number;
  final bool wide;
  final VoidCallback onRemove;
  final VoidCallback onPickVenue;
  final VoidCallback onAddSchedule;
  final ValueChanged<String> onRemoveSchedule;
  final void Function(String, Map<String, Object?>) onUpdateSchedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.clubVenueNumber(number),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.clubRemoveVenue,
                onPressed: onRemove,
                icon: const Icon(AppIcons.delete),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: ValueKey('club-select-venue-${group.id}'),
            onPressed: onPickVenue,
            icon: const Icon(AppIcons.location),
            label: Text(venue?.name ?? l10n.clubSelectVenue),
          ),
          if (venue?.hasAddressData ?? false)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                resolveAppAddress(
                  showNewAddress: showNewAddress,
                  address: venue!.address,
                  district: venue!.district,
                  city: venue!.city,
                  newAddress: venue!.newAddress,
                ).text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.clubScheduleTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: onAddSchedule,
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(l10n.clubAddSchedule),
              ),
            ],
          ),
          if (group.schedules.isEmpty)
            Text(
              l10n.clubNoSchedules,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final schedule in group.schedules)
              _ScheduleRow(
                schedule: schedule,
                wide: wide,
                onRemove: () => onRemoveSchedule(schedule.id),
                onUpdate: (values) => onUpdateSchedule(schedule.id, values),
              ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.wide,
    required this.onRemove,
    required this.onUpdate,
  });

  final ClubScheduleDraft schedule;
  final bool wide;
  final VoidCallback onRemove;
  final ValueChanged<Map<String, Object?>> onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = [
      l10n.socialSunday,
      l10n.socialMonday,
      l10n.socialTuesday,
      l10n.socialWednesday,
      l10n.socialThursday,
      l10n.socialFriday,
      l10n.socialSaturday,
    ];
    final day = DropdownButtonFormField<int>(
      initialValue: schedule.dayOfWeek,
      decoration: InputDecoration(labelText: l10n.clubDayOfWeek),
      items: [
        for (var index = 0; index < days.length; index++)
          DropdownMenuItem(value: index, child: Text(days[index])),
      ],
      onChanged: (value) => onUpdate({'dayOfWeek': value}),
    );
    final start = _TimeButton(
      label: l10n.clubStartTime,
      value: schedule.startTime,
      onChanged: (value) => onUpdate({'startTime': value}),
    );
    final end = _TimeButton(
      label: l10n.clubEndTime,
      value: schedule.endTime,
      onChanged: (value) => onUpdate({'endTime': value}),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          if (wide)
            Row(
              children: [
                Expanded(child: day),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: start),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: end),
                IconButton(
                  tooltip: l10n.clubRemoveSchedule,
                  onPressed: onRemove,
                  icon: const Icon(AppIcons.delete),
                ),
              ],
            )
          else ...[
            day,
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: start),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: end),
                IconButton(
                  tooltip: l10n.clubRemoveSchedule,
                  onPressed: onRemove,
                  icon: const Icon(AppIcons.delete),
                ),
              ],
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: schedule.isActive,
            onChanged: (value) => onUpdate({'isActive': value}),
            title: Text(
              schedule.isActive
                  ? l10n.clubScheduleActive
                  : l10n.clubScheduleInactive,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () async {
      final parts = value.split(':');
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 19,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
        ),
      );
      if (time != null) {
        onChanged(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        );
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value),
      ],
    ),
  );
}

class _SocialLinksCard extends StatelessWidget {
  const _SocialLinksCard({
    required this.form,
    required this.open,
    required this.onChanged,
  });

  final FormGroup form;
  final bool open;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final links = <(String, String)>[
      ('facebook', l10n.clubSocialFacebook),
      ('zalo', l10n.clubSocialZalo),
      ('tiktok', l10n.clubSocialTiktok),
      ('youtube', l10n.clubSocialYoutube),
      ('website', l10n.clubSocialWebsite),
      ('other', l10n.clubSocialOther),
    ];
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => onChanged(!open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _SectionHeader(
                title: l10n.clubSocialLinksTitle,
                description: l10n.clubSocialLinksDescription,
                trailing: Icon(
                  open ? AppIcons.chevronUp : AppIcons.chevronDown,
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (final link in links) ...[
                    _SocialLinkField(form: form, name: link.$1, label: link.$2),
                    if (link != links.last)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (trailing == null)
          titleWidget
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleWidget),
              trailing!,
            ],
          ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SocialLinkField extends StatelessWidget {
  const _SocialLinkField({
    required this.form,
    required this.name,
    required this.label,
  });

  final FormGroup form;
  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    final controlName = switch (name) {
      'facebook' => ClubFormControl.socialFacebook,
      'zalo' => ClubFormControl.socialZalo,
      'tiktok' => ClubFormControl.socialTiktok,
      'youtube' => ClubFormControl.socialYoutube,
      'website' => ClubFormControl.socialWebsite,
      _ => ClubFormControl.socialOther,
    };
    return ReactiveTextField<String>(
      formControlName: controlName,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: label,
        hintText: AppLocalizations.of(context).clubLinkPlaceholder,
      ),
    );
  }
}

class _HostUserPickerSheet extends ConsumerStatefulWidget {
  const _HostUserPickerSheet();

  @override
  ConsumerState<_HostUserPickerSheet> createState() =>
      _HostUserPickerSheetState();
}

class _HostUserPickerSheetState extends ConsumerState<_HostUserPickerSheet> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(clubHostUsersProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.clubSearchHostUser,
                  prefixIcon: const Icon(AppIcons.search),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _query = value);
                  });
                },
              ),
            ),
            Expanded(
              child: users.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(clubHostUsersProvider(_query)),
                ),
                data: (items) => items.isEmpty
                    ? Center(child: Text(l10n.clubNoHostUsers))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: item.image == null
                                  ? null
                                  : CachedNetworkImageProvider(item.image!),
                              child: item.image == null
                                  ? const Icon(AppIcons.profile)
                                  : null,
                            ),
                            title: Text(item.name),
                            subtitle: Text(item.email),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenuePickerSheet extends ConsumerStatefulWidget {
  const _VenuePickerSheet({required this.excludedVenueIds});

  final Set<String> excludedVenueIds;

  @override
  ConsumerState<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends ConsumerState<_VenuePickerSheet> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final venues = ref.watch(clubVenueSearchProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.clubSearchVenue,
                  prefixIcon: const Icon(AppIcons.search),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _query = value);
                  });
                },
              ),
            ),
            Expanded(
              child: venues.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(clubVenueSearchProvider(_query)),
                ),
                data: (items) {
                  final filtered = items
                      .where(
                        (item) => !widget.excludedVenueIds.contains(item.id),
                      )
                      .toList();
                  return filtered.isEmpty
                      ? Center(child: Text(l10n.clubNoVenuesFound))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final venue = filtered[index];
                            return ListTile(
                              leading: const Icon(AppIcons.location),
                              title: Text(venue.name),
                              subtitle:
                                  venue
                                      .addressLabel(
                                        showNewAddress: ref
                                            .read(
                                              locationPreferencesControllerProvider,
                                            )
                                            .showNewAddress,
                                      )
                                      .isEmpty
                                  ? null
                                  : Text(
                                      venue.addressLabel(
                                        showNewAddress: ref
                                            .read(
                                              locationPreferencesControllerProvider,
                                            )
                                            .showNewAddress,
                                      ),
                                    ),
                              onTap: () => Navigator.pop(context, venue),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubImageLibrarySheet extends ConsumerStatefulWidget {
  const _ClubImageLibrarySheet({
    required this.maxSelection,
    required this.category,
    required this.initialSelection,
  });

  final int maxSelection;
  final String category;
  final List<ClubImageAsset> initialSelection;

  @override
  ConsumerState<_ClubImageLibrarySheet> createState() =>
      _ClubImageLibrarySheetState();
}

class _ClubImageLibrarySheetState
    extends ConsumerState<_ClubImageLibrarySheet> {
  final _images = <ClubImageAsset>[];
  late final Map<String, ClubImageAsset> _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final image in widget.initialSelection) image.publicId: image,
    };
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final images = await ref
          .read(socialServiceProvider)
          .myImages(category: widget.category);
      if (mounted) setState(() => _images.addAll(images));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(ClubImageAsset image) {
    if (_selected.remove(image.publicId) != null) {
      setState(() {});
      return;
    }
    if (_selected.length >= widget.maxSelection) return;
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.clubSelectFromGallery,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _images.isEmpty
                  ? Center(child: Text(l10n.clubGalleryEmpty))
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
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
                              CachedNetworkImage(
                                imageUrl: image.url,
                                fit: BoxFit.cover,
                              ),
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
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, _selected.values.toList()),
                  child: Text(l10n.commonConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
