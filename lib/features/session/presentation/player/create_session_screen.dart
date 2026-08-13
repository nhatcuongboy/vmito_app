import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/application/player/create_session_controller.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';
import 'package:vmito_app/features/session/domain/form/ai_location_resolver.dart';
import 'package:vmito_app/features/session/domain/form/session_form_defaults.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_errors.dart';
import 'package:vmito_app/features/session/domain/form/session_form_state.dart';
import 'package:vmito_app/features/session/domain/form/session_form_submission.dart';
import 'package:vmito_app/features/session/domain/form/session_form_utils.dart';
import 'package:vmito_app/features/session/domain/form/session_form_validator.dart';
import 'package:vmito_app/features/session/domain/form/session_reactive_form.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/presentation/widgets/level_band_picker.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

const _wideFormBreakpoint = 768.0;
const _maxFormWidth = 896.0;

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({
    this.initialSession,
    this.editingSessionId,
    this.isClone = false,
    super.key,
  });

  final Session? initialSession;
  final String? editingSessionId;
  final bool isClone;

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  late final SessionFormState _baseState;
  late final FormGroup _form;
  final _scrollController = ScrollController();
  final _sectionKeys = <SessionFormField, GlobalKey>{
    for (final field in SessionFormField.values) field: GlobalKey(),
  };
  List<Venue> _venues = const [];
  bool _venuesLoading = false;
  bool _isUploading = false;
  bool _advancedOpen = false;
  bool _feeOpen = false;
  bool _bulkOpen = false;
  String? _localError;

  bool get _isEditing => widget.editingSessionId != null;

  @override
  void initState() {
    super.initState();
    final userName = ref.read(authControllerProvider).user?.name;
    _baseState = widget.initialSession == null
        ? SessionFormDefaults.create(hostName: userName)
        : SessionFormDefaults.fromSession(
            widget.initialSession!,
            isClone: widget.isClone,
            hostName: userName,
          );
    _form = createSessionReactiveForm(_baseState);
    _feeOpen = _baseState.feeEnabled;
    unawaited(_loadVenues());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadVenues([String keyword = '']) async {
    setState(() => _venuesLoading = true);
    final sport = _form.sessionValue<SessionSportType>(
      SessionFormControl.sportType,
    );
    try {
      final result = await ref
          .read(venueServiceProvider)
          .browse(
            VenueFilter(
              keyword: keyword,
              sportType: sport == SessionSportType.pickleball
                  ? 'PICKLEBALL'
                  : 'BADMINTON',
              sortBy: keyword.trim().isEmpty ? 'distance' : 'relevance',
            ),
            page: 1,
            limit: 30,
          );
      if (mounted) setState(() => _venues = result.venues);
    } on Object {
      if (mounted) setState(() => _venues = const []);
    } finally {
      if (mounted) setState(() => _venuesLoading = false);
    }
  }

  bool get _canAccessHostFeatures {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return false;
    if (user.role == UserRole.host || user.role == UserRole.admin) return true;
    final vip = ref
        .watch(sessionFeatureFlagsProvider)
        .asData
        ?.value['PLAYER_VIP_ENABLED'];
    return vip == true &&
        (user.role == UserRole.player || user.role == UserRole.referee);
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _clearDomainErrors();
    _form.markAllAsTouched();
    final snapshot = _form.toSessionFormState(base: _baseState);
    final domainErrors = validateSessionForm(snapshot, now: DateTime.now());
    if (domainErrors.isNotEmpty) {
      _applyDomainErrors(domainErrors);
      return;
    }
    if (_form.invalid || _form.pending || _isUploading) return;

    setState(() => _localError = null);
    final controller = ref.read(createSessionControllerProvider.notifier);
    Session? session;
    if (_isEditing) {
      session = await controller.update(
        widget.editingSessionId!,
        SessionFormSubmission.toRequest(snapshot),
      );
    } else if (snapshot.shouldCreateBulk) {
      final result = await controller.submitBulk(
        SessionFormSubmission.toBulkRequest(snapshot),
      );
      session = result?.sessions.isNotEmpty == true
          ? result!.sessions.first
          : null;
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).sessionFormBulkCreated(
                result.sessionsCreated,
              ),
            ),
          ),
        );
      }
    } else {
      session = await controller.submit(
        SessionFormSubmission.toRequest(snapshot),
      );
    }

    if (!mounted || session == null) return;
    if (_isEditing) {
      context.pop(session);
    } else {
      context.pushReplacement(AppRoutes.sessionDetail(session.id));
    }
  }

  void _clearDomainErrors() {
    for (final name in [
      SessionFormControl.name,
      SessionFormControl.venueId,
      SessionFormControl.customLocationName,
      SessionFormControl.hostName,
      SessionFormControl.startTimeOfDay,
      SessionFormControl.endTimeOfDay,
      SessionFormControl.multiDayStart,
      SessionFormControl.multiDayEnd,
      SessionFormControl.courts,
      SessionFormControl.maxPlayers,
      SessionFormControl.referenceVideo,
    ]) {
      final control = _form.control(name);
      if (control.hasError('domain')) control.removeError('domain');
    }
  }

  void _applyDomainErrors(SessionFormErrors errors) {
    final field = errors.orderedFields.first;
    final target = switch (field) {
      SessionFormField.name => SessionFormControl.name,
      SessionFormField.venue => SessionFormControl.venueId,
      SessionFormField.customLocation => SessionFormControl.customLocationName,
      SessionFormField.hostName ||
      SessionFormField.hostPhone => SessionFormControl.hostName,
      SessionFormField.startTime =>
        _form.sessionValue<bool>(SessionFormControl.isMultiDay) == true
            ? SessionFormControl.multiDayStart
            : SessionFormControl.startTimeOfDay,
      SessionFormField.endTime =>
        _form.sessionValue<bool>(SessionFormControl.isMultiDay) == true
            ? SessionFormControl.multiDayEnd
            : SessionFormControl.endTimeOfDay,
      SessionFormField.courts => SessionFormControl.courts,
      SessionFormField.maxPlayersPerCourt => SessionFormControl.maxPlayers,
      SessionFormField.referenceVideoUrl => SessionFormControl.referenceVideo,
    };
    _form.control(target).setErrors({'domain': true});
    setState(() => _localError = _domainErrorText(errors[field]!));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKeys[field]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.12,
        );
      }
    });
  }

  String _domainErrorText(SessionFormErrorCode code) {
    final l10n = AppLocalizations.of(context);
    return switch (code) {
      SessionFormErrorCode.sessionNameRequired =>
        l10n.createSessionNameRequired,
      SessionFormErrorCode.locationRequired =>
        l10n.sessionFormValidationLocation,
      SessionFormErrorCode.customLocationRequired =>
        l10n.sessionFormValidationCustomLocation,
      SessionFormErrorCode.hostNameRequired => l10n.sessionFormValidationHost,
      SessionFormErrorCode.startTimeRequired ||
      SessionFormErrorCode.startTimeMustBeInFuture =>
        l10n.sessionFormValidationStart,
      SessionFormErrorCode.endTimeRequired ||
      SessionFormErrorCode.endTimeMustBeAfterStartTime =>
        l10n.sessionFormValidationEnd,
      SessionFormErrorCode.atLeastOneCourt ||
      SessionFormErrorCode.courtNumberMin ||
      SessionFormErrorCode.courtNumberUnique =>
        l10n.sessionFormValidationCourts,
      SessionFormErrorCode.maxPlayersPerCourtMin ||
      SessionFormErrorCode.maxPlayersPerCourtMax =>
        l10n.sessionFormValidationPlayers,
      SessionFormErrorCode.referenceVideoUrlInvalid =>
        l10n.sessionFormValidationVideo,
    };
  }

  Future<void> _showVenuePicker() async {
    final l10n = AppLocalizations.of(context);
    var query = '';
    Timer? debounce;
    final venue = await showModalBottomSheet<Venue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.sessionFormSearchVenue,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    query = value;
                    debounce?.cancel();
                    debounce = Timer(
                      const Duration(milliseconds: 300),
                      () async {
                        await _loadVenues(value);
                        if (sheetContext.mounted) setSheetState(() {});
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: _venuesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          for (final item in _venues)
                            ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(item.name),
                              subtitle: item.addressLabel.isEmpty
                                  ? null
                                  : Text(item.addressLabel),
                              onTap: () => Navigator.pop(sheetContext, item),
                            ),
                          if (_venues.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.sessionFormNoVenue,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ListTile(
                            leading: const Icon(
                              Icons.add_location_alt_outlined,
                            ),
                            title: Text(l10n.sessionFormUseCustomLocation),
                            subtitle: query.trim().isEmpty ? null : Text(query),
                            onTap: () {
                              _form
                                      .control(SessionFormControl.locationKind)
                                      .value =
                                  SessionLocationKind.custom;
                              _form.control(SessionFormControl.venueId).value =
                                  '';
                              if (query.trim().isNotEmpty) {
                                _form
                                    .control(
                                      SessionFormControl.customLocationName,
                                    )
                                    .value = query
                                    .trim();
                              }
                              Navigator.pop(sheetContext);
                              setState(() {});
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.add_business_outlined),
                            title: Text(l10n.sessionFormSuggestVenue),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              unawaited(_suggestVenue(query));
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    debounce?.cancel();
    if (venue == null) return;
    _form
      ..control(SessionFormControl.locationKind).value =
          SessionLocationKind.venue
      ..control(SessionFormControl.venueId).value = venue.id
      ..control(SessionFormControl.venueLabel).value = venue.name
      ..control(SessionFormControl.venueSublabel).value = venue.addressLabel
      ..control(SessionFormControl.customLocationFromAi).value = false;
    setState(() {});
  }

  Future<void> _suggestVenue(String initialName) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initialName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionFormSuggestVenue),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            label: AppRequiredLabel(l10n.sessionFormCustomLocationName),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.sessionFormCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.sessionFormSuggestVenue),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.length < 2 || !mounted) return;
    try {
      await ref
          .read(venueServiceProvider)
          .createRequest(
            type: 'CREATE',
            payload: {'name': name},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionFormSuggestVenue)),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _localError = _safeError(error));
    }
  }

  Future<void> _showAddressPicker() async {
    final l10n = AppLocalizations.of(context);
    var suggestions = <PlaceSuggestion>[];
    var loading = false;
    Timer? debounce;
    final selected = await showModalBottomSheet<PlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.sessionFormSearchAddress,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (query) {
                    debounce?.cancel();
                    debounce = Timer(
                      const Duration(milliseconds: 300),
                      () async {
                        setSheetState(() => loading = true);
                        try {
                          suggestions = await ref
                              .read(sessionFormServiceProvider)
                              .autocompletePlaces(
                                input: query,
                                language: Localizations.localeOf(
                                  context,
                                ).languageCode,
                              );
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => loading = false);
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              if (loading) const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(item.primaryText),
                      subtitle: item.secondaryText.isEmpty
                          ? null
                          : Text(item.secondaryText),
                      onTap: () => Navigator.pop(sheetContext, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    debounce?.cancel();
    if (selected == null || !mounted) return;
    final details = await ref
        .read(sessionFormServiceProvider)
        .placeDetails(
          placeId: selected.placeId,
          language: Localizations.localeOf(context).languageCode,
        );
    _form
      ..control(SessionFormControl.customLocationAddress).value =
          details.address
      ..control(SessionFormControl.customLocationPlaceId).value =
          details.placeId
      ..control(SessionFormControl.customLocationLat).value = details.latitude
      ..control(SessionFormControl.customLocationLng).value = details.longitude
      ..control(SessionFormControl.customLocationDistrict).value =
          details.district ?? ''
      ..control(SessionFormControl.customLocationCity).value =
          details.city ?? '';
    setState(() {});
  }

  Future<void> _showAiDialog() async {
    final data = await showDialog<ExtractedSessionData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AiSessionDialog(),
    );
    if (data == null || !mounted) return;
    _applyAiData(data);
  }

  Future<void> _applyAiData(ExtractedSessionData data) async {
    void setIfText(String control, String? value) {
      if (value?.trim().isNotEmpty ?? false)
        _form.control(control).value = value;
    }

    setIfText(SessionFormControl.name, data.name);
    setIfText(SessionFormControl.description, data.description);
    setIfText(SessionFormControl.hostName, data.hostName);
    setIfText(SessionFormControl.hostPhone, data.hostPhone);
    setIfText(SessionFormControl.shuttlecock, data.shuttlecock);
    if (data.sportType != null) {
      _form.control(SessionFormControl.sportType).value = data.sportType;
      await _loadVenues();
    }
    if (data.maxPlayersPerCourt != null) {
      _form.control(SessionFormControl.maxPlayers).value =
          data.maxPlayersPerCourt;
    }
    if (data.startTime != null) {
      final start = data.startTime!;
      _form
        ..control(SessionFormControl.sessionDate).value = DateTime(
          start.year,
          start.month,
          start.day,
        )
        ..control(SessionFormControl.startTimeOfDay).value =
            SessionFormUtils.timeOfDay(start);
    }
    if (data.endTime != null) {
      _form.control(SessionFormControl.endTimeOfDay).value =
          SessionFormUtils.timeOfDay(data.endTime!);
    }
    if (data.requiredLevels.isNotEmpty) {
      _form
        ..control(SessionFormControl.allLevels).value = false
        ..control(SessionFormControl.requiredLevels).value =
            data.requiredLevels;
    }
    if ((data.numberOfCourts ?? 0) > 0) {
      final array =
          _form.control(SessionFormControl.courts)
              as FormArray<Map<String, Object?>>;
      array.clear();
      for (final court in SessionFormUtils.buildCourtsFromAiData(
        numberOfCourts: data.numberOfCourts!,
        courtNames: data.courtNames,
        nextKey: nextDraftKey,
      )) {
        array.add(sessionCourtForm(court));
      }
    }
    if (data.feeConfig case final fee?) {
      _form.control(SessionFormControl.feeEnabled).value = true;
      _form
          .control(SessionFormControl.feeType)
          .value = fee['feeType'] == 'SPLIT_EVENLY'
          ? FeeType.splitEvenly
          : FeeType.fixed;
      _form.control(SessionFormControl.maleFee).value = (fee['maleFee'] as num?)
          ?.toInt();
      _form.control(SessionFormControl.femaleFee).value =
          (fee['femaleFee'] as num?)?.toInt();
      _form.control(SessionFormControl.feeNotes).value =
          fee['notes'] as String? ?? '';
      _feeOpen = true;
    }

    final venue = data.venue;
    final resolution = resolveAiLocation(
      venueId: data.venueId,
      location: data.location,
      venueName: venue['name'] as String?,
      venueAddress: (venue['newAddress'] ?? venue['address']) as String?,
      venueDistrict: venue['district'] as String?,
      venueNewDistrict: venue['newDistrict'] as String?,
      venueCity: venue['city'] as String?,
      venueNewCity: venue['newCity'] as String?,
    );
    switch (resolution) {
      case AiVenueLocation(:final venueId):
        Venue? match;
        for (final venue in _venues) {
          if (venue.id == venueId) match = venue;
        }
        final Venue resolved =
            match ?? await ref.read(venueDetailProvider(venueId).future);
        _form
          ..control(SessionFormControl.locationKind).value =
              SessionLocationKind.venue
          ..control(SessionFormControl.venueId).value = venueId
          ..control(SessionFormControl.venueLabel).value = resolved.name
          ..control(SessionFormControl.venueSublabel).value =
              resolved.addressLabel
          ..control(SessionFormControl.customLocationFromAi).value = false;
      case AiCustomLocation(
        :final name,
        :final address,
        :final district,
        :final city,
      ):
        _form
          ..control(SessionFormControl.locationKind).value =
              SessionLocationKind.custom
          ..control(SessionFormControl.venueId).value = ''
          ..control(SessionFormControl.customLocationName).value = name
          ..control(SessionFormControl.customLocationAddress).value =
              address ?? ''
          ..control(SessionFormControl.customLocationDistrict).value =
              district ?? ''
          ..control(SessionFormControl.customLocationCity).value = city ?? ''
          ..control(SessionFormControl.customLocationFromAi).value = true;
      case AiNoLocation():
        break;
    }
    setState(() {});
  }

  Future<void> _pickImages() async {
    final current =
        _form.sessionValue<List<SessionImageDraft>>(
          SessionFormControl.images,
        ) ??
        const [];
    final remaining = 5 - current.length;
    if (remaining <= 0 || _isUploading) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final uploads = <SessionImageDraft>[];
      for (final file in picked.take(remaining)) {
        final uploaded = await ref
            .read(sessionFormServiceProvider)
            .uploadImage(
              bytes: await file.readAsBytes(),
              filename: file.name,
            );
        uploads.add(
          SessionImageDraft(
            key: nextDraftKey(),
            localPath: file.path,
            url: uploaded.url,
            publicId: uploaded.publicId,
          ),
        );
      }
      final next = [...current, ...uploads];
      _form.control(SessionFormControl.images).value = next;
      if (_form.sessionValue<String>(SessionFormControl.bannerPublicId) ==
              null &&
          next.isNotEmpty) {
        _form.control(SessionFormControl.bannerPublicId).value =
            next.first.publicId;
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submitState = ref.watch(createSessionControllerProvider);
    final isSubmitting = submitState.isLoading;
    final clubs = _canAccessHostFeatures
        ? ref.watch(managedClubsProvider).asData?.value ?? const <ClubSummary>[]
        : const <ClubSummary>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideFormBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditing
                  ? l10n.editSessionTitle
                  : widget.isClone
                  ? l10n.cloneSessionTitle
                  : l10n.createSessionTitle,
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : _SubmitBar(
                  label: _isEditing
                      ? l10n.editSessionSave
                      : l10n.createSessionSubmit,
                  busy: isSubmitting || _isUploading,
                  onSubmit: _submit,
                ),
          body: ReactiveForm(
            formGroup: _form,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxFormWidth),
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    wide ? AppSpacing.xxl : 120,
                  ),
                  children: [
                    _BasicSection(
                      key: _sectionKeys[SessionFormField.name],
                      form: _form,
                      canEditVenue: _baseState.canEditTime,
                      onAi: _isEditing ? null : _showAiDialog,
                      onVenue: _showVenuePicker,
                      onCustomAddress: AppConfig.hasGooglePlaces
                          ? _showAddressPicker
                          : null,
                      onSportChanged: _loadVenues,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _HostSection(
                      key: _sectionKeys[SessionFormField.hostName],
                      wide: wide,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TimeSection(
                      key: _sectionKeys[SessionFormField.startTime],
                      form: _form,
                      wide: wide,
                      enabled: _baseState.canEditTime && !isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CourtsSection(
                      key: _sectionKeys[SessionFormField.courts],
                      form: _form,
                      enabled: _baseState.canEditCourts && !isSubmitting,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LevelSection(form: _form),
                    const SizedBox(height: AppSpacing.lg),
                    _FeeSection(
                      form: _form,
                      open: _feeOpen,
                      wide: wide,
                      onOpenChanged: (value) =>
                          setState(() => _feeOpen = value),
                    ),
                    if (!_isEditing && _canAccessHostFeatures) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _BulkSection(
                        form: _form,
                        open: _bulkOpen,
                        onOpenChanged: (value) =>
                            setState(() => _bulkOpen = value),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _AdvancedSection(
                      key: _sectionKeys[SessionFormField.referenceVideoUrl],
                      form: _form,
                      open: _advancedOpen,
                      wide: wide,
                      canHost: _canAccessHostFeatures,
                      clubs: clubs,
                      uploading: _isUploading,
                      onPickImages: _pickImages,
                      onOpenChanged: (value) =>
                          setState(() => _advancedOpen = value),
                    ),
                    if (_localError != null || submitState.hasError) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _localError ?? _safeError(submitState.error),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (wide) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SubmitBar(
                        label: _isEditing
                            ? l10n.editSessionSave
                            : l10n.createSessionSubmit,
                        busy: isSubmitting || _isUploading,
                        onSubmit: _submit,
                        inline: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _safeError(Object? error) {
    final text = error?.toString().replaceFirst('Exception: ', '') ?? '';
    return text.length > 180 ? text.substring(0, 180) : text;
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _BasicSection extends StatelessWidget {
  const _BasicSection({
    required this.form,
    required this.canEditVenue,
    required this.onVenue,
    required this.onSportChanged,
    this.onCustomAddress,
    this.onAi,
    super.key,
  });
  final FormGroup form;
  final bool canEditVenue;
  final VoidCallback? onAi;
  final VoidCallback onVenue;
  final VoidCallback? onCustomAddress;
  final Future<void> Function([String keyword]) onSportChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormCard(
      title: l10n.sessionFormBasicInfo,
      action: onAi == null
          ? null
          : OutlinedButton.icon(
              onPressed: onAi,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(l10n.sessionFormCreateByAi),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                minimumSize: const Size(0, 40),
                shape: const StadiumBorder(),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReactiveTextField<String>(
            key: const Key('create-session-name'),
            formControlName: SessionFormControl.name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              label: AppRequiredLabel(l10n.createSessionName),
              hintText: l10n.sessionFormNamePlaceholder,
            ),
            validationMessages: {
              ValidationMessage.required: (_) => l10n.createSessionNameRequired,
              'domain': (_) => l10n.createSessionNameRequired,
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ReactiveTextField<String>(
            formControlName: SessionFormControl.description,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.createSessionDescription,
              hintText: l10n.sessionFormDescriptionPlaceholder,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppRequiredLabel(l10n.sessionFormSport),
          const SizedBox(height: AppSpacing.sm),
          ReactiveValueListenableBuilder<SessionSportType>(
            formControlName: SessionFormControl.sportType,
            builder: (context, control, _) => SegmentedButton<SessionSportType>(
              segments: [
                ButtonSegment(
                  value: SessionSportType.badminton,
                  icon: const Text('🏸'),
                  label: Text(l10n.sessionFormBadminton),
                ),
                ButtonSegment(
                  value: SessionSportType.pickleball,
                  icon: const Text('🏓'),
                  label: Text(l10n.sessionFormPickleball),
                ),
              ],
              selected: {control.value ?? SessionSportType.badminton},
              onSelectionChanged: canEditVenue
                  ? (selection) {
                      control.value = selection.first;
                      form
                        ..control(SessionFormControl.venueId).value = ''
                        ..control(SessionFormControl.venueLabel).value = '';
                      onSportChanged();
                    }
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppRequiredLabel(l10n.createSessionLocation),
          const SizedBox(height: AppSpacing.sm),
          ReactiveValueListenableBuilder<String>(
            formControlName: SessionFormControl.venueLabel,
            builder: (context, labelControl, _) => InkWell(
              onTap: canEditVenue ? onVenue : null,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText:
                      form
                          .control(SessionFormControl.venueId)
                          .hasError('domain')
                      ? l10n.sessionFormValidationLocation
                      : null,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down),
                ),
                child: Text(
                  (labelControl.value?.isNotEmpty ?? false)
                      ? labelControl.value!
                      : form.sessionValue<SessionLocationKind>(
                              SessionFormControl.locationKind,
                            ) ==
                            SessionLocationKind.custom
                      ? form.sessionValue<String>(
                              SessionFormControl.customLocationName,
                            ) ??
                            l10n.sessionFormUseCustomLocation
                      : l10n.sessionFormSelectVenue,
                ),
              ),
            ),
          ),
          ReactiveValueListenableBuilder<SessionLocationKind>(
            formControlName: SessionFormControl.locationKind,
            builder: (context, control, _) {
              if (control.value != SessionLocationKind.custom) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .07),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .25),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.sessionFormTemporaryLocation),
                    const SizedBox(height: AppSpacing.sm),
                    ReactiveValueListenableBuilder<bool>(
                      formControlName: SessionFormControl.customLocationFromAi,
                      builder: (context, warning, _) => warning.value == true
                          ? Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                l10n.sessionFormAiLocationWarning,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    ReactiveTextField<String>(
                      formControlName: SessionFormControl.customLocationName,
                      decoration: InputDecoration(
                        label: AppRequiredLabel(
                          l10n.sessionFormCustomLocationName,
                        ),
                      ),
                      validationMessages: {
                        'domain': (_) =>
                            l10n.sessionFormValidationCustomLocation,
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ReactiveTextField<String>(
                      formControlName: SessionFormControl.customLocationAddress,
                      readOnly: onCustomAddress != null,
                      onTap: onCustomAddress == null
                          ? null
                          : (_) => onCustomAddress!(),
                      decoration: InputDecoration(
                        labelText:
                            '${l10n.sessionFormCustomLocationAddress} (${l10n.sessionFormRecommended})',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      onChanged: (_) {
                        form
                          ..control(
                            SessionFormControl.customLocationPlaceId,
                          ).value = ''
                          ..control(
                            SessionFormControl.customLocationLat,
                          ).value = null
                          ..control(
                            SessionFormControl.customLocationLng,
                          ).value = null;
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HostSection extends StatelessWidget {
  const _HostSection({required this.wide, super.key});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameField = ReactiveTextField<String>(
      formControlName: SessionFormControl.hostName,
      decoration: InputDecoration(
        label: AppRequiredLabel(l10n.sessionFormHostName),
      ),
      validationMessages: {
        ValidationMessage.required: (_) => l10n.sessionFormValidationHost,
        'domain': (_) => l10n.sessionFormValidationHost,
      },
    );
    final phoneField = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReactiveTextField<String>(
          formControlName: SessionFormControl.hostPhone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l10n.sessionFormHostPhone),
        ),
        ReactiveCheckboxListTile(
          formControlName: SessionFormControl.allowZaloContact,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.sessionFormAllowZalo),
        ),
      ],
    );
    return _FormCard(
      title: l10n.sessionFormHostInfo,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: nameField),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: phoneField),
              ],
            )
          : Column(
              children: [
                nameField,
                const SizedBox(height: AppSpacing.md),
                phoneField,
              ],
            ),
    );
  }
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({
    required this.form,
    required this.wide,
    required this.enabled,
    super.key,
  });
  final FormGroup form;
  final bool wide;
  final bool enabled;

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );

  Future<Duration?> _pickTime(BuildContext context, Duration? initial) async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initial?.inHours ?? TimeOfDay.now().hour,
        minute: initial?.inMinutes.remainder(60) ?? 0,
      ),
    );
    return value == null
        ? null
        : Duration(hours: value.hour, minutes: value.minute);
  }

  String _date(DateTime? value) => value == null
      ? '—'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _time(Duration? value) => value == null
      ? '—'
      : '${value.inHours.toString().padLeft(2, '0')}:${value.inMinutes.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormCard(
      title: l10n.sessionFormTime,
      action: SizedBox(
        width: 150,
        child: ReactiveSwitchListTile(
          formControlName: SessionFormControl.isMultiDay,
          title: Text(
            l10n.sessionFormMultiDay,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          contentPadding: EdgeInsets.zero,
          dense: true,
          onChanged: enabled ? null : (_) {},
        ),
      ),
      child: ReactiveValueListenableBuilder<bool>(
        formControlName: SessionFormControl.isMultiDay,
        builder: (context, multi, _) {
          if (multi.value == true) {
            return _AdaptiveFields(
              wide: wide,
              children: [
                _ValuePicker<DateTime>(
                  label: l10n.createSessionStart,
                  control:
                      form.control(SessionFormControl.multiDayStart)
                          as FormControl<DateTime>,
                  formatter: _dateTime,
                  enabled: enabled,
                  onPick: (current) => _pickDateTime(context, current),
                ),
                _ValuePicker<DateTime>(
                  label: l10n.sessionFormEnd,
                  control:
                      form.control(SessionFormControl.multiDayEnd)
                          as FormControl<DateTime>,
                  formatter: _dateTime,
                  enabled: enabled,
                  onPick: (current) => _pickDateTime(context, current),
                ),
              ],
            );
          }
          return _AdaptiveFields(
            wide: wide,
            children: [
              _ValuePicker<DateTime>(
                label: l10n.sessionFormDate,
                control:
                    form.control(SessionFormControl.sessionDate)
                        as FormControl<DateTime>,
                formatter: _date,
                enabled: enabled,
                onPick: (current) => _pickDate(context, current),
              ),
              _ValuePicker<Duration>(
                label: l10n.createSessionStart,
                control:
                    form.control(SessionFormControl.startTimeOfDay)
                        as FormControl<Duration>,
                formatter: _time,
                enabled: enabled,
                onPick: (current) => _pickTime(context, current),
              ),
              _ValuePicker<Duration>(
                label: l10n.sessionFormEnd,
                control:
                    form.control(SessionFormControl.endTimeOfDay)
                        as FormControl<Duration>,
                formatter: _time,
                enabled: enabled,
                onPick: (current) => _pickTime(context, current),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateTime(DateTime? value) => value == null
      ? '—'
      : '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? current,
  ) async {
    final date = await _pickDate(context, current);
    if (date == null || !context.mounted) return null;
    final time = await _pickTime(
      context,
      current == null ? null : SessionFormUtils.timeOfDay(current),
    );
    if (time == null) return null;
    return SessionFormUtils.combineDateTime(date, time);
  }
}

class _ValuePicker<T> extends StatelessWidget {
  const _ValuePicker({
    required this.label,
    required this.control,
    required this.formatter,
    required this.enabled,
    required this.onPick,
  });
  final String label;
  final FormControl<T> control;
  final String Function(T?) formatter;
  final bool enabled;
  final Future<T?> Function(T?) onPick;
  @override
  Widget build(BuildContext context) => ReactiveValueListenableBuilder<T>(
    formControl: control,
    builder: (context, field, _) => InkWell(
      onTap: enabled
          ? () async {
              final value = await onPick(field.value);
              if (value != null) field.value = value;
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          label: AppRequiredLabel(label),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          errorText: field.hasError('domain')
              ? AppLocalizations.of(context).sessionFormValidationStart
              : null,
        ),
        child: Text(formatter(field.value)),
      ),
    ),
  );
}

class _AdaptiveFields extends StatelessWidget {
  const _AdaptiveFields({required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: children[i]),
            ],
          ],
        )
      : Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              children[i],
            ],
          ],
        );
}

class _CourtsSection extends StatelessWidget {
  const _CourtsSection({required this.form, required this.enabled, super.key});
  final FormGroup form;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormCard(
      title: l10n.sessionFormCourts,
      child: ReactiveFormArray<Map<String, Object?>>(
        formArrayName: SessionFormControl.courts,
        builder: (context, array, _) => Column(
          children: [
            for (var index = 0; index < array.controls.length; index++) ...[
              if (index > 0) const Divider(height: AppSpacing.lg * 2),
              ReactiveForm(
                formGroup: array.controls[index] as FormGroup,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: ReactiveTextField<int>(
                        key: ValueKey('court-number-$index'),
                        formControlName: SessionFormControl.courtNumber,
                        valueAccessor: IntValueAccessor(),
                        keyboardType: TextInputType.number,
                        readOnly: !enabled,
                        decoration: InputDecoration(
                          label: AppRequiredLabel(l10n.sessionFormCourtNumber),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ReactiveTextField<String>(
                        formControlName: SessionFormControl.courtName,
                        readOnly: !enabled,
                        decoration: InputDecoration(
                          labelText: l10n.sessionFormCourtName,
                          hintText: l10n.sessionFormCourtNamePlaceholder,
                        ),
                      ),
                    ),
                    if (array.controls.length > 1 && enabled)
                      IconButton(
                        key: ValueKey('remove-court-$index'),
                        tooltip: l10n.sessionFormRemoveCourtTitle,
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _remove(context, array, index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            ],
            if (array.hasError('domain'))
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.sessionFormValidationCourts,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('add-court'),
              onPressed: enabled
                  ? () => array.add(
                      sessionCourtForm(
                        SessionCourtDraft(
                          key: nextDraftKey(),
                          courtNumber: array.controls.length + 1,
                        ),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.sessionFormAddCourt),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    FormArray<Map<String, Object?>> array,
    int index,
  ) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionFormRemoveCourtTitle),
        content: Text(l10n.sessionFormRemoveCourtMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.sessionFormCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sessionFormRemoveCourtTitle),
          ),
        ],
      ),
    );
    if (yes == true) array.removeAt(index);
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.form});
  final FormGroup form;
  @override
  Widget build(BuildContext context) => _FormCard(
    title: AppLocalizations.of(context).sessionFormLevels,
    child: ReactiveValueListenableBuilder<List<int>>(
      formControlName: SessionFormControl.requiredLevels,
      builder: (context, control, _) => Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilterChip(
              label: Text(AppLocalizations.of(context).sessionFormAllLevels),
              selected: control.value?.isEmpty ?? true,
              onSelected: (_) {
                control.value = const [];
                form.control(SessionFormControl.allLevels).value = true;
              },
            ),
          ),
          LevelBandPicker(
            selected: control.value ?? const [],
            onChanged: (levels) {
              control.value = levels;
              form.control(SessionFormControl.allLevels).value = levels.isEmpty;
            },
          ),
        ],
      ),
    ),
  );
}

class _FeeSection extends StatelessWidget {
  const _FeeSection({
    required this.form,
    required this.open,
    required this.wide,
    required this.onOpenChanged,
  });
  final FormGroup form;
  final bool open;
  final bool wide;
  final ValueChanged<bool> onOpenChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ReactiveSwitchListTile(
            key: const Key('fee-enabled'),
            formControlName: SessionFormControl.feeEnabled,
            title: Text(
              l10n.sessionFormFee,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: ReactiveValueListenableBuilder<bool>(
              formControlName: SessionFormControl.feeEnabled,
              builder: (context, enabled, _) => Text(
                enabled.value == true
                    ? l10n.sessionFormFeeEnabled
                    : l10n.sessionFormFeeDisabled,
              ),
            ),
            secondary: const Icon(Icons.attach_money),
            onChanged: (control) => onOpenChanged(control.value == true),
          ),
          ReactiveValueListenableBuilder<bool>(
            formControlName: SessionFormControl.feeEnabled,
            builder: (context, enabled, _) => AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: enabled.value == true && open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.sessionFormFeeType),
                    const SizedBox(height: AppSpacing.sm),
                    ReactiveValueListenableBuilder<FeeType>(
                      formControlName: SessionFormControl.feeType,
                      builder: (context, type, _) => SegmentedButton<FeeType>(
                        segments: [
                          ButtonSegment(
                            value: FeeType.fixed,
                            label: Text(l10n.sessionFormFeeFixed),
                          ),
                          ButtonSegment(
                            value: FeeType.splitEvenly,
                            label: Text(l10n.sessionFormFeeSplit),
                          ),
                        ],
                        selected: {type.value ?? FeeType.fixed},
                        onSelectionChanged: (value) => type.value = value.first,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveValueListenableBuilder<FeeType>(
                      formControlName: SessionFormControl.feeType,
                      builder: (context, type, _) =>
                          type.value == FeeType.splitEvenly
                          ? Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .08),
                              child: Text(l10n.sessionFormFeeSplitDescription),
                            )
                          : _AdaptiveFields(
                              wide: wide,
                              children: [
                                ReactiveTextField<int>(
                                  formControlName: SessionFormControl.maleFee,
                                  valueAccessor: IntValueAccessor(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.createSessionFeeMale,
                                    suffixText: 'VND',
                                  ),
                                ),
                                ReactiveTextField<int>(
                                  formControlName: SessionFormControl.femaleFee,
                                  valueAccessor: IntValueAccessor(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.createSessionFeeFemale,
                                    suffixText: 'VND',
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveTextField<String>(
                      formControlName: SessionFormControl.feeNotes,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.sessionFormFeeNotes,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkSection extends StatelessWidget {
  const _BulkSection({
    required this.form,
    required this.open,
    required this.onOpenChanged,
  });
  final FormGroup form;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ReactiveSwitchListTile(
            key: const Key('bulk-enabled'),
            formControlName: SessionFormControl.bulkEnabled,
            title: Text(
              l10n.sessionFormBulk,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(l10n.sessionFormBulkDisabled),
            secondary: const Icon(Icons.calendar_month_outlined),
            onChanged: (control) => onOpenChanged(control.value == true),
          ),
          ReactiveValueListenableBuilder<bool>(
            formControlName: SessionFormControl.bulkEnabled,
            builder: (context, enabled, _) => enabled.value == true && open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        ReactiveValueListenableBuilder<BulkCreationMode>(
                          formControlName: SessionFormControl.bulkMode,
                          builder: (context, mode, _) =>
                              SegmentedButton<BulkCreationMode>(
                                segments: [
                                  ButtonSegment(
                                    value: BulkCreationMode.specificDates,
                                    label: Text(l10n.sessionFormSpecificDates),
                                  ),
                                  ButtonSegment(
                                    value: BulkCreationMode.recurringWeekdays,
                                    label: Text(l10n.sessionFormRecurring),
                                  ),
                                ],
                                selected: {
                                  mode.value ?? BulkCreationMode.specificDates,
                                },
                                onSelectionChanged: (value) =>
                                    mode.value = value.first,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ReactiveValueListenableBuilder<BulkCreationMode>(
                          formControlName: SessionFormControl.bulkMode,
                          builder: (context, mode, _) =>
                              mode.value == BulkCreationMode.recurringWeekdays
                              ? _RecurringFields(form: form)
                              : _SpecificDateFields(form: form),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SpecificDateFields extends StatelessWidget {
  const _SpecificDateFields({required this.form});
  final FormGroup form;
  @override
  Widget build(BuildContext context) =>
      ReactiveValueListenableBuilder<List<DateTime>>(
        formControlName: SessionFormControl.bulkDates,
        builder: (context, dates, _) => Column(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: SessionFormSubmission.maxBulkDate(DateTime.now()),
                );
                if (date == null) return;
                final list = [...?dates.value];
                if (!list.any((item) => DateUtils.isSameDay(item, date)))
                  list.add(date);
                dates.value = list..sort();
              },
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).sessionFormAddDate),
            ),
            if (dates.value?.isNotEmpty ?? false)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final date in dates.value!)
                    InputChip(
                      label: Text('${date.day}/${date.month}/${date.year}'),
                      onDeleted: () =>
                          dates.value = [...dates.value!]..remove(date),
                    ),
                ],
              ),
          ],
        ),
      );
}

class _RecurringFields extends StatelessWidget {
  const _RecurringFields({required this.form});
  final FormGroup form;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ReactiveValueListenableBuilder<List<int>>(
        formControlName: SessionFormControl.bulkWeekdays,
        builder: (context, days, _) => Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (var value = 1; value <= 7; value++)
              FilterChip(
                label: Text(
                  MaterialLocalizations.of(context).narrowWeekdays[value % 7],
                ),
                selected: days.value?.contains(value % 7) ?? false,
                onSelected: (selected) {
                  final next = [...?days.value];
                  selected ? next.add(value % 7) : next.remove(value % 7);
                  days.value = next;
                },
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ReactiveTextField<int>(
        formControlName: SessionFormControl.bulkWeeks,
        valueAccessor: IntValueAccessor(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).sessionFormWeekCount,
        ),
      ),
    ],
  );
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.form,
    required this.open,
    required this.wide,
    required this.canHost,
    required this.clubs,
    required this.uploading,
    required this.onPickImages,
    required this.onOpenChanged,
    super.key,
  });
  final FormGroup form;
  final bool open;
  final bool wide;
  final bool canHost;
  final List<ClubSummary> clubs;
  final bool uploading;
  final VoidCallback onPickImages;
  final ValueChanged<bool> onOpenChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: () => onOpenChanged(!open),
            leading: const Icon(Icons.settings_outlined),
            title: Text(
              l10n.sessionFormAdvanced,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: Icon(
              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImageGallery(
                    form: form,
                    uploading: uploading,
                    onPick: onPickImages,
                  ),
                  if (canHost) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.sessionFormCourtAppearance,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ReactiveValueListenableBuilder<String>(
                      formControlName: SessionFormControl.courtColor,
                      builder: (context, color, _) => Wrap(
                        spacing: AppSpacing.md,
                        children: [
                          for (final hex in SessionFormUtils.courtColors)
                            ChoiceChip(
                              label: Container(
                                width: 36,
                                height: 24,
                                color: _hexColor(hex),
                              ),
                              selected: color.value == hex,
                              onSelected: (_) => color.value = hex,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.sessionFormMatchType,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ReactiveValueListenableBuilder<MatchType>(
                    formControlName: SessionFormControl.matchType,
                    builder: (context, type, _) => SegmentedButton<MatchType>(
                      segments: [
                        ButtonSegment(
                          value: MatchType.doubles,
                          icon: const Icon(Icons.groups_2_outlined),
                          label: Text(l10n.sessionFormDoubles),
                        ),
                        ButtonSegment(
                          value: MatchType.singles,
                          icon: const Icon(Icons.person_outline),
                          label: Text(l10n.sessionFormSingles),
                        ),
                      ],
                      selected: {type.value ?? MatchType.doubles},
                      onSelectionChanged: (value) => type.value = value.first,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AdaptiveFields(
                    wide: wide,
                    children: [
                      ReactiveTextField<String>(
                        formControlName: SessionFormControl.shuttlecock,
                        decoration: InputDecoration(
                          labelText: l10n.sessionFormShuttlecock,
                        ),
                      ),
                      ReactiveTextField<int>(
                        formControlName: SessionFormControl.maxPlayers,
                        valueAccessor: IntValueAccessor(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.createSessionMaxPerCourt,
                        ),
                        validationMessages: {
                          ValidationMessage.min: (_) =>
                              l10n.sessionFormValidationPlayers,
                          ValidationMessage.max: (_) =>
                              l10n.sessionFormValidationPlayers,
                          'domain': (_) => l10n.sessionFormValidationPlayers,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReactiveTextField<String>(
                    formControlName: SessionFormControl.referenceVideo,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.sessionFormReferenceVideo,
                    ),
                    validationMessages: {
                      'domain': (_) => l10n.sessionFormValidationVideo,
                    },
                  ),
                  if (canHost) ...[
                    const SizedBox(height: AppSpacing.md),
                    ReactiveDropdownField<String>(
                      formControlName: SessionFormControl.clubId,
                      decoration: InputDecoration(
                        labelText: l10n.sessionFormDefaultClub,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.sessionFormNoClub),
                        ),
                        for (final club in clubs)
                          DropdownMenuItem(
                            value: club.id,
                            child: Text(club.name),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String value) =>
      Color(int.parse('FF${value.substring(1)}', radix: 16));
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.form,
    required this.uploading,
    required this.onPick,
  });
  final FormGroup form;
  final bool uploading;
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ReactiveValueListenableBuilder<List<SessionImageDraft>>(
      formControlName: SessionFormControl.images,
      builder: (context, images, _) {
        final list = images.value ?? const [];
        final banner = form.sessionValue<String>(
          SessionFormControl.bannerPublicId,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${l10n.sessionFormImages} (${list.length}/5)'),
                ),
                OutlinedButton.icon(
                  onPressed: uploading || list.length >= 5 ? null : onPick,
                  icon: uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(l10n.sessionFormAddImages),
                ),
              ],
            ),
            if (list.isNotEmpty)
              SizedBox(
                height: 124,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final next = [...list];
                    final item = next.removeAt(oldIndex);
                    next.insert(newIndex, item);
                    images.value = next;
                  },
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final selected = item.publicId == banner;
                    return Container(
                      key: ValueKey(item.key),
                      width: 112,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: selected ? 3 : 1,
                        ),
                        image: DecorationImage(
                          image: item.localPath != null
                              ? FileImage(File(item.localPath!))
                              : NetworkImage(item.url!) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ColoredBox(
                          color: Colors.black54,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: l10n.sessionFormBanner,
                                onPressed: () {
                                  form
                                          .control(
                                            SessionFormControl.bannerPublicId,
                                          )
                                          .value =
                                      item.publicId;
                                  images.value = [...list];
                                },
                                icon: Icon(
                                  selected ? Icons.star : Icons.star_border,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final next = [...list]..removeAt(index);
                                  images.value = next;
                                  if (selected) {
                                    form
                                        .control(
                                          SessionFormControl.bannerPublicId,
                                        )
                                        .value = next.isEmpty
                                        ? null
                                        : next.first.publicId;
                                  }
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.label,
    required this.busy,
    required this.onSubmit,
    this.inline = false,
  });
  final String label;
  final bool busy;
  final VoidCallback onSubmit;
  final bool inline;
  @override
  Widget build(BuildContext context) => Material(
    elevation: inline ? 0 : 8,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(inline ? 0 : AppSpacing.md),
        child: FilledButton(
          key: const Key('create-session-submit'),
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    ),
  );
}

class _AiSessionDialog extends ConsumerStatefulWidget {
  const _AiSessionDialog();
  @override
  ConsumerState<_AiSessionDialog> createState() => _AiSessionDialogState();
}

class _AiSessionDialogState extends ConsumerState<_AiSessionDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.sessionFormAiTitle)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sessionFormAiDescription),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              minLines: 8,
              maxLines: 12,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: l10n.sessionFormAiInput,
                alignLabelWithHint: true,
              ),
            ),
            TextButton.icon(
              onPressed: _loading
                  ? null
                  : () => _controller.text =
                        'Tên kèo: \nMô tả: \nHost: \nSĐT: \nTên sân: \nĐịa chỉ: \nNgày: \nThời gian: \nSố lượng sân: \nTrình độ: \nPhí: ',
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.sessionFormAiTemplate),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.sessionFormCancel),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _loading
                ? l10n.sessionFormAiGenerating
                : l10n.sessionFormAiGenerate,
          ),
        ),
      ],
    );
  }

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context);
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sessionFormAiEmpty)));
      return;
    }
    setState(() => _loading = true);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final result = await ref
          .read(sessionFormServiceProvider)
          .extractSession(
            articleContent: _controller.text.trim(),
            language: locale == 'zh' ? 'cn' : locale,
          );
      if (mounted) Navigator.pop(context, result);
    } on Object {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.sessionFormAiFailed)));
      }
    }
  }
}
