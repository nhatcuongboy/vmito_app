import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/google_places_attribution.dart';
import 'package:vmito_app/core/location/google_places_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/reference/presentation/level_descriptions_sheet.dart';
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
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_form_submit_bar.dart';
import 'package:vmito_app/shared/widgets/app_multi_date_picker.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/app_time_picker.dart';
import 'package:vmito_app/shared/widgets/level_badge_picker.dart';

const _wideFormBreakpoint = 768.0;
const _maxFormWidth = 896.0;

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({
    this.initialSession,
    this.editingSessionId,
    this.isClone = false,
    this.modalPresentation = false,
    super.key,
  });

  final Session? initialSession;
  final String? editingSessionId;
  final bool isClone;
  final bool modalPresentation;

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

  bool get _isEditing => widget.editingSessionId != null;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>(() {
        if (mounted) {
          ref.read(createSessionControllerProvider.notifier).reset();
        }
      }),
    );
    final userName = ref.read(authControllerProvider).user?.name;
    _baseState = widget.initialSession == null
        ? SessionFormDefaults.create(hostName: userName)
        : SessionFormDefaults.fromSession(
            widget.initialSession!,
            isClone: widget.isClone,
            hostName: userName,
            showNewAddress: ref
                .read(locationPreferencesControllerProvider)
                .showNewAddress,
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
      unawaited(HapticFeedback.lightImpact());
      _applyDomainErrors(domainErrors);
      return;
    }
    if (_form.invalid || _form.pending || _isUploading) {
      if (_form.invalid) {
        unawaited(HapticFeedback.lightImpact());
        _scrollToFirstInvalidSection();
      }
      return;
    }

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
      if (widget.modalPresentation) {
        Navigator.of(context).pop(session);
      } else {
        context.pop(session);
      }
    } else {
      context.pushReplacement(AppRoutes.manageSession(session.id));
    }
  }

  void _clearDomainErrors() {
    for (final name in [
      SessionFormControl.name,
      SessionFormControl.venueId,
      SessionFormControl.customLocationName,
      SessionFormControl.hostName,
      SessionFormControl.hostPhone,
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
      SessionFormField.hostName => SessionFormControl.hostName,
      SessionFormField.hostPhone => SessionFormControl.hostPhone,
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
      _form.focus(target);
    });
  }

  void _scrollToFirstInvalidSection() {
    // Returns the first invalid control name for the given field, or null.
    String? firstInvalidControl(SessionFormField field) {
      final controls = switch (field) {
        SessionFormField.name => [SessionFormControl.name],
        SessionFormField.venue => [SessionFormControl.venueId],
        SessionFormField.customLocation => [
          SessionFormControl.customLocationName,
        ],
        SessionFormField.hostName => [SessionFormControl.hostName],
        SessionFormField.hostPhone => [SessionFormControl.hostPhone],
        SessionFormField.startTime => [
          SessionFormControl.startTimeOfDay,
          SessionFormControl.multiDayStart,
        ],
        SessionFormField.endTime => [
          SessionFormControl.endTimeOfDay,
          SessionFormControl.multiDayEnd,
        ],
        SessionFormField.courts => [SessionFormControl.courts],
        SessionFormField.maxPlayersPerCourt => [SessionFormControl.maxPlayers],
        SessionFormField.referenceVideoUrl => [
          SessionFormControl.referenceVideo,
        ],
      };
      for (final name in controls) {
        try {
          if (_form.control(name).invalid) return name;
        } catch (_) {}
      }
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final field in SessionFormField.values) {
        final invalidControl = firstInvalidControl(field);
        if (invalidControl == null) continue;
        final context = _sectionKeys[field]?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: 0.12,
          );
        }
        _form.focus(invalidControl);
        return;
      }
    });
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
                              title: Text(
                                item.name.trim().toLowerCase().startsWith('sân')
                                    ? item.name.trim()
                                    : 'Sân ${item.name.trim()}',
                              ),
                              subtitle:
                                  item
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
                                      item.addressLabel(
                                        showNewAddress: ref
                                            .read(
                                              locationPreferencesControllerProvider,
                                            )
                                            .showNewAddress,
                                      ),
                                    ),
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
      ..control(SessionFormControl.venueSublabel).value = venue.addressLabel(
        showNewAddress: ref
            .read(locationPreferencesControllerProvider)
            .showNewAddress,
      )
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              label: AppRequiredLabel(l10n.sessionFormCustomLocationName),
            ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_safeError(error))),
        );
      }
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
                              .read(googlePlacesServiceProvider)
                              .autocomplete(
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
              if (suggestions.isNotEmpty) const GooglePlacesAttribution(),
            ],
          ),
        ),
      ),
    );
    debounce?.cancel();
    if (selected == null || !mounted) return;
    final details = await ref
        .read(googlePlacesServiceProvider)
        .details(
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

  Future<void> _showAiSheet() async {
    final data = await showModalBottomSheet<ExtractedSessionData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _AiSessionSheet(),
    );
    if (data == null || !mounted) return;
    _applyAiData(data);
  }

  Future<void> _applyAiData(ExtractedSessionData data) async {
    void setIfText(String control, String? value) {
      if (value?.trim().isNotEmpty ?? false) {
        _form.control(control).value = value;
      }
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
          ..control(SessionFormControl.venueSublabel).value = resolved
              .addressLabel(
                showNewAddress: ref
                    .read(locationPreferencesControllerProvider)
                    .showNewAddress,
              )
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

  Future<void> _showImageLibrary() async {
    final current =
        _form.sessionValue<List<SessionImageDraft>>(
          SessionFormControl.images,
        ) ??
        const [];
    final selected = await showModalBottomSheet<List<UserImageAsset>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AccountImageLibrarySheet(
        initialSelection: [
          for (final image in current)
            if ((image.url?.isNotEmpty ?? false) &&
                (image.publicId?.isNotEmpty ?? false))
              UserImageAsset(
                id: '',
                url: image.url!,
                publicId: image.publicId!,
              ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    final existing = {
      for (final image in current)
        if (image.publicId != null) image.publicId!: image,
    };
    final next = [
      for (final image in selected)
        existing[image.publicId] ??
            SessionImageDraft(
              key: nextDraftKey(),
              url: image.url,
              publicId: image.publicId,
            ),
    ];
    final banner = _form.sessionValue<String>(
      SessionFormControl.bannerPublicId,
    );
    _form.control(SessionFormControl.images).value = next;
    if (banner == null || !next.any((image) => image.publicId == banner)) {
      _form.control(SessionFormControl.bannerPublicId).value = next.isEmpty
          ? null
          : next.first.publicId;
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
        final wide =
            !widget.modalPresentation &&
            constraints.maxWidth >= _wideFormBreakpoint;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.modalPresentation,
            titleSpacing: widget.modalPresentation ? AppSpacing.md : null,
            title: Text(
              _isEditing
                  ? l10n.editSessionTitle
                  : widget.isClone
                  ? l10n.cloneSessionTitle
                  : l10n.createSessionTitle,
              style: widget.modalPresentation
                  ? AppSheetHeader.titleTextStyle(context)
                  : null,
            ),
            actions: [
              if (!_isEditing && !widget.modalPresentation)
                _AiAppBarAction(
                  label: l10n.sessionFormCreateByAi,
                  onPressed: _showAiSheet,
                ),
              if (widget.modalPresentation)
                IconButton(
                  key: const Key('session-edit-modal-close'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(AppIcons.close),
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: AppReactiveForm<void>(
            formGroup: _form,
            // The submit button lives in `body`, not `bottomNavigationBar`:
            // `body` shrinks above the software keyboard (the Scaffold
            // default `resizeToAvoidBottomInset: true`), so an
            // `Align(bottomCenter)` here stays visible while typing.
            // `bottomNavigationBar` does not get that treatment and would be
            // covered by the keyboard instead.
            child: Stack(
              children: [
                Center(
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
                          onVenue: _showVenuePicker,
                          onCustomAddress: _showAddressPicker,
                          onSportChanged: _loadVenues,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _HostSection(
                          key: _sectionKeys[SessionFormField.hostName],
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
                          canHost: _canAccessHostFeatures,
                          clubs: clubs,
                          uploading: _isUploading,
                          onPickImages: _pickImages,
                          onOpenLibrary: _showImageLibrary,
                          onOpenChanged: (value) =>
                              setState(() => _advancedOpen = value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _InternalSection(),
                        if (wide) ...[
                          const SizedBox(height: AppSpacing.lg),
                          AppFormSubmitBar(
                            label: _isEditing
                                ? l10n.editSessionSave
                                : l10n.createSessionSubmit,
                            icon: _isEditing ? AppIcons.save : AppIcons.add,
                            busy: isSubmitting || _isUploading,
                            onSubmit: _submit,
                            inline: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!wide)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AppFormSubmitBar(
                      buttonKey: const Key('create-session-submit'),
                      label: _isEditing
                          ? l10n.editSessionSave
                          : l10n.createSessionSubmit,
                      icon: _isEditing ? AppIcons.save : AppIcons.add,
                      busy: isSubmitting || _isUploading,
                      onSubmit: _submit,
                    ),
                  ),
              ],
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

class _AiAppBarAction extends StatelessWidget {
  const _AiAppBarAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      key: const Key('create-session-ai'),
      onPressed: onPressed,
      icon: const Icon(AppIcons.sparkles, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.deepPurple,
        side: BorderSide(color: Colors.deepPurple.withValues(alpha: .4)),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _DisabledLockBadge extends StatelessWidget {
  const _DisabledLockBadge();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.muted.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
      ),
      child: Icon(
        AppIcons.lock,
        size: 13,
        color: palette.mutedForeground,
      ),
    );
  }
}

class _BasicSection extends StatelessWidget {
  const _BasicSection({
    required this.form,
    required this.canEditVenue,
    required this.onVenue,
    required this.onSportChanged,
    this.onCustomAddress,
    super.key,
  });
  final FormGroup form;
  final bool canEditVenue;
  final VoidCallback onVenue;
  final VoidCallback? onCustomAddress;
  final Future<void> Function([String keyword]) onSportChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormCard(
      title: l10n.sessionFormBasicInfo,
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
            builder: (context, control, _) => Row(
              children: [
                Expanded(
                  child: _SportOption(
                    type: SessionSportType.badminton,
                    icon: Image.asset(
                      'assets/icons/shuttlecock.png',
                      width: 22,
                      height: 22,
                    ),
                    label: l10n.sessionFormBadminton,
                    selected:
                        (control.value ?? SessionSportType.badminton) ==
                        SessionSportType.badminton,
                    enabled: canEditVenue,
                    onSelected: () {
                      control.value = SessionSportType.badminton;
                      form
                        ..control(SessionFormControl.venueId).value = ''
                        ..control(SessionFormControl.venueLabel).value = '';
                      unawaited(onSportChanged());
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SportOption(
                    type: SessionSportType.pickleball,
                    icon: Icon(
                      Icons.sports_tennis,
                      size: 20,
                      color:
                          (control.value ?? SessionSportType.badminton) ==
                              SessionSportType.pickleball
                          ? Colors.white
                          : null,
                    ),
                    label: l10n.sessionFormPickleball,
                    selected:
                        (control.value ?? SessionSportType.badminton) ==
                        SessionSportType.pickleball,
                    enabled: canEditVenue,
                    onSelected: () {
                      control.value = SessionSportType.pickleball;
                      form
                        ..control(SessionFormControl.venueId).value = ''
                        ..control(SessionFormControl.venueLabel).value = '';
                      unawaited(onSportChanged());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ReactiveValueListenableBuilder<SessionLocationKind>(
            formControlName: SessionFormControl.locationKind,
            builder: (context, control, _) {
              final custom = control.value == SessionLocationKind.custom;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppRequiredLabel(l10n.createSessionLocation),
                      ),
                      Text(
                        l10n.sessionFormCustomLocationToggle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: canEditVenue
                              ? Theme.of(
                                  context,
                                ).extension<AppPalette>()!.mutedForeground
                              : Theme.of(context)
                                    .extension<AppPalette>()!
                                    .mutedForeground
                                    .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          key: const Key('custom-location-switch'),
                          value: custom,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: canEditVenue
                              ? (value) => control.value = value
                                    ? SessionLocationKind.custom
                                    : SessionLocationKind.venue
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (!custom) ...[
                    ReactiveValueListenableBuilder<String>(
                      formControlName: SessionFormControl.venueLabel,
                      builder: (context, labelControl, _) {
                        final rawLabel = labelControl.value;
                        final hasValue = rawLabel?.isNotEmpty ?? false;
                        final displayLabel = hasValue
                            ? (rawLabel!.trim().toLowerCase().startsWith('sân')
                                  ? rawLabel.trim()
                                  : 'Sân ${rawLabel.trim()}')
                            : l10n.sessionFormSelectVenue;

                        return InkWell(
                          key: const Key('venue-picker'),
                          mouseCursor: canEditVenue
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          onTap: canEditVenue ? onVenue : null,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              enabled: canEditVenue,
                              errorText:
                                  form
                                      .control(SessionFormControl.venueId)
                                      .hasError('domain')
                                  ? l10n.sessionFormValidationLocation
                                  : null,
                              suffixIcon: Icon(
                                AppIcons.chevronDown,
                                color: canEditVenue
                                    ? null
                                    : Theme.of(context)
                                          .extension<AppPalette>()!
                                          .mutedForeground
                                          .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              displayLabel,
                              style: TextStyle(
                                color: canEditVenue
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(
                                            context,
                                          )
                                          .extension<AppPalette>()!
                                          .mutedForeground,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ReactiveValueListenableBuilder<String>(
                      formControlName: SessionFormControl.venueSublabel,
                      builder: (context, sublabelControl, _) {
                        final sublabel = sublabelControl.value;
                        if (sublabel == null || sublabel.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final palette = Theme.of(
                          context,
                        ).extension<AppPalette>()!;
                        return Padding(
                          key: const Key('venue-sublabel'),
                          padding: const EdgeInsets.only(
                            top: AppSpacing.xs,
                            left: AppSpacing.xs,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                AppIcons.location,
                                size: 14,
                                color: palette.mutedForeground,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  sublabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: palette.mutedForeground,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else
                    Container(
                      key: const Key('custom-location-fields'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: canEditVenue
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .07)
                            : Theme.of(context)
                                  .extension<AppPalette>()!
                                  .muted
                                  .withValues(alpha: .5),
                        border: Border.all(
                          color: canEditVenue
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .25)
                              : Theme.of(context)
                                    .extension<AppPalette>()!
                                    .border
                                    .withValues(alpha: .6),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sessionFormTemporaryLocation,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: canEditVenue
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                            .extension<AppPalette>()!
                                            .mutedForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ReactiveValueListenableBuilder<bool>(
                            formControlName:
                                SessionFormControl.customLocationFromAi,
                            builder: (context, warning, _) =>
                                warning.value == true
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      l10n.sessionFormAiLocationWarning,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          ReactiveTextField<String>(
                            formControlName:
                                SessionFormControl.customLocationName,
                            readOnly: !canEditVenue,
                            style: TextStyle(
                              color: canEditVenue
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).extension<AppPalette>()!.mutedForeground,
                            ),
                            decoration: InputDecoration(
                              enabled: canEditVenue,
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
                            formControlName:
                                SessionFormControl.customLocationAddress,
                            readOnly: !canEditVenue || onCustomAddress != null,
                            onTap: !canEditVenue || onCustomAddress == null
                                ? null
                                : (_) => onCustomAddress!(),
                            style: TextStyle(
                              color: canEditVenue
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).extension<AppPalette>()!.mutedForeground,
                            ),
                            decoration: InputDecoration(
                              enabled: canEditVenue,
                              labelText:
                                  '${l10n.sessionFormCustomLocationAddress} (${l10n.sessionFormRecommended})',
                              prefixIcon: Icon(
                                AppIcons.location,
                                color: canEditVenue
                                    ? null
                                    : Theme.of(context)
                                          .extension<AppPalette>()!
                                          .mutedForeground
                                          .withValues(alpha: 0.6),
                              ),
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
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InternalSection extends StatelessWidget {
  const _InternalSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ReactiveValueListenableBuilder<bool>(
          formControlName: SessionFormControl.isInternal,
          builder: (context, control, _) {
            final isInternal = control.value ?? false;
            return InkWell(
              onTap: () => control.value = !isInternal,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sessionFormInternalTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          l10n.sessionFormInternalSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      key: const Key('internal-session-switch'),
                      value: isInternal,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) => control.value = value,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SportOption extends StatelessWidget {
  const _SportOption({
    required this.type,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final SessionSportType type;
  final Widget icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    const selectedColor = Colors.green;

    final Color backgroundColor;
    final BorderSide borderSide;
    final Color? textColor;

    if (!enabled) {
      if (selected) {
        backgroundColor = selectedColor.withValues(alpha: 0.14);
        borderSide = BorderSide(
          color: selectedColor.withValues(alpha: 0.35),
          width: 1.5,
        );
        textColor = selectedColor.withValues(alpha: 0.75);
      } else {
        backgroundColor = palette.muted.withValues(alpha: 0.45);
        borderSide = BorderSide(
          color: palette.border.withValues(alpha: 0.4),
        );
        textColor = palette.mutedForeground.withValues(alpha: 0.6);
      }
    } else {
      if (selected) {
        backgroundColor = selectedColor;
        borderSide = const BorderSide(color: selectedColor);
        textColor = Colors.white;
      } else {
        backgroundColor = Colors.transparent;
        borderSide = BorderSide(color: palette.border, width: 2);
        textColor = null;
      }
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('sport-${type.name}'),
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: enabled ? onSelected : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: enabled ? 1.0 : (selected ? 0.7 : 0.4),
                    child: icon,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HostSection extends StatelessWidget {
  const _HostSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _FormCard(
      title: l10n.sessionFormHostInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledField(
            key: const Key('host-name-field'),
            label: AppRequiredLabel(l10n.sessionFormHostName),
            child: ReactiveTextField<String>(
              formControlName: SessionFormControl.hostName,
              validationMessages: {
                ValidationMessage.required: (_) =>
                    l10n.sessionFormValidationHost,
                'domain': (_) => l10n.sessionFormValidationHost,
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            key: const Key('host-phone-field'),
            label: Text(l10n.sessionFormHostPhone),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReactiveTextField<String>(
                  formControlName: SessionFormControl.hostPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: l10n.sessionFormHostPhonePlaceholder,
                  ),
                  validationMessages: {
                    'phone': (_) => l10n.sessionFormValidationPhone,
                    'domain': (_) => l10n.sessionFormValidationPhone,
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                ReactiveValueListenableBuilder<bool>(
                  formControlName: SessionFormControl.allowZaloContact,
                  builder: (context, control, _) => InkWell(
                    onTap: () => control.value = control.value != true,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: const Key('allow-zalo-checkbox'),
                          value: control.value ?? false,
                          onChanged: (value) => control.value = value,
                          visualDensity: VisualDensity.compact,
                        ),
                        Flexible(
                          child: Text(
                            l10n.sessionFormAllowZalo,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, super.key});

  final Widget label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DefaultTextStyle.merge(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        child: label,
      ),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
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
    final value = await showAppTimePicker(
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
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled) ...[
            const _DisabledLockBadge(),
            const SizedBox(width: AppSpacing.sm),
          ],
          ReactiveValueListenableBuilder<bool>(
            formControlName: SessionFormControl.isMultiDay,
            builder: (context, control, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.sessionFormMultiDay,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? Theme.of(
                            context,
                          ).extension<AppPalette>()!.mutedForeground
                        : Theme.of(context)
                              .extension<AppPalette>()!
                              .mutedForeground
                              .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    key: const Key('multi-day-switch'),
                    value: control.value ?? false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: enabled
                        ? (value) => control.value = value
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: ReactiveValueListenableBuilder<bool>(
        formControlName: SessionFormControl.isMultiDay,
        builder: (context, multi, _) {
          if (multi.value == true) {
            return _AdaptiveFields(
              wide: wide,
              children: [
                _ValuePicker<DateTime>(
                  key: const Key('session-multi-day-start-picker'),
                  label: l10n.createSessionStart,
                  control:
                      form.control(SessionFormControl.multiDayStart)
                          as FormControl<DateTime>,
                  formatter: _dateTime,
                  icon: AppIcons.calendar,
                  domainErrorText: l10n.sessionFormValidationStart,
                  enabled: enabled,
                  onPick: (current) => _pickDateTime(context, current),
                ),
                _ValuePicker<DateTime>(
                  key: const Key('session-multi-day-end-picker'),
                  label: l10n.sessionFormEnd,
                  control:
                      form.control(SessionFormControl.multiDayEnd)
                          as FormControl<DateTime>,
                  formatter: _dateTime,
                  icon: AppIcons.calendar,
                  domainErrorText: l10n.sessionFormValidationEnd,
                  enabled: enabled,
                  onPick: (current) => _pickDateTime(context, current),
                ),
              ],
            );
          }
          final date = _ValuePicker<DateTime>(
            key: const Key('session-date-picker'),
            label: l10n.sessionFormDate,
            control:
                form.control(SessionFormControl.sessionDate)
                    as FormControl<DateTime>,
            formatter: _date,
            icon: AppIcons.calendar,
            domainErrorText: l10n.sessionFormValidationStart,
            enabled: enabled,
            onPick: (current) => _pickDate(context, current),
          );
          final start = _ValuePicker<Duration>(
            key: const Key('session-start-picker'),
            label: l10n.createSessionStart,
            control:
                form.control(SessionFormControl.startTimeOfDay)
                    as FormControl<Duration>,
            formatter: _time,
            icon: AppIcons.clock,
            domainErrorText: l10n.sessionFormValidationStart,
            enabled: enabled,
            onPick: (current) => _pickTime(context, current),
          );
          final end = _ValuePicker<Duration>(
            key: const Key('session-end-picker'),
            label: l10n.sessionFormEnd,
            control:
                form.control(SessionFormControl.endTimeOfDay)
                    as FormControl<Duration>,
            formatter: _time,
            icon: AppIcons.clock,
            domainErrorText: l10n.sessionFormValidationEnd,
            enabled: enabled,
            onPick: (current) => _pickTime(context, current),
          );
          if (wide) {
            return _AdaptiveFields(
              wide: true,
              children: [date, start, end],
            );
          }
          return Column(
            children: [
              date,
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: start),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: end),
                ],
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
    required this.icon,
    required this.domainErrorText,
    required this.enabled,
    required this.onPick,
    super.key,
  });
  final String label;
  final FormControl<T> control;
  final String Function(T?) formatter;
  final IconData icon;
  final String domainErrorText;
  final bool enabled;
  final Future<T?> Function(T?) onPick;
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return _LabeledField(
      label: AppRequiredLabel(label),
      child: ReactiveValueListenableBuilder<T>(
        formControl: control,
        builder: (context, field, _) => InkWell(
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: enabled
              ? () async {
                  final value = await onPick(field.value);
                  if (value != null) field.value = value;
                }
              : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InputDecorator(
            decoration: InputDecoration(
              enabled: enabled,
              suffixIcon: Icon(
                icon,
                color: enabled
                    ? null
                    : palette.mutedForeground.withValues(alpha: 0.6),
              ),
              errorText: field.hasError('domain') ? domainErrorText : null,
            ),
            child: Text(
              formatter(field.value),
              style: TextStyle(
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : palette.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final palette = Theme.of(context).extension<AppPalette>()!;
    return _FormCard(
      title: l10n.sessionFormCourts,
      action: !enabled ? const _DisabledLockBadge() : null,
      child: ReactiveFormArray<Map<String, Object?>>(
        formArrayName: SessionFormControl.courts,
        builder: (context, array, _) => Column(
          children: [
            for (var index = 0; index < array.controls.length; index++) ...[
              if (index > 0) const Divider(height: AppSpacing.lg * 2),
              AppReactiveForm<void>(
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
                        textInputAction: TextInputAction.done,
                        readOnly: !enabled,
                        style: TextStyle(
                          color: enabled ? null : palette.mutedForeground,
                        ),
                        decoration: InputDecoration(
                          enabled: enabled,
                          label: AppRequiredLabel(l10n.sessionFormCourtNumber),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ReactiveTextField<String>(
                        formControlName: SessionFormControl.courtName,
                        readOnly: !enabled,
                        style: TextStyle(
                          color: enabled ? null : palette.mutedForeground,
                        ),
                        decoration: InputDecoration(
                          enabled: enabled,
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
                disabledForegroundColor: palette.mutedForeground.withValues(
                  alpha: 0.7,
                ),
                disabledBackgroundColor: palette.muted.withValues(alpha: 0.4),
                side: BorderSide(
                  color: enabled
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5)
                      : palette.border.withValues(alpha: 0.4),
                ),
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: Text(l10n.sessionFormRemoveCourtMessage),
        ),
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
    action: IconButton(
      key: const Key('level-info'),
      onPressed: () => unawaited(showLevelDescriptions(context)),
      tooltip: AppLocalizations.of(context).levelDescriptionsTitle,
      icon: const Icon(AppIcons.info, size: 18),
      visualDensity: VisualDensity.compact,
    ),
    child: ReactiveValueListenableBuilder<List<int>>(
      formControlName: SessionFormControl.requiredLevels,
      builder: (context, control, _) => Column(
        children: [
          LevelBadgePicker(
            selectedLevels: control.value ?? const [],
            allLevelsLabel: AppLocalizations.of(context).sessionFormAllLevels,
            allLevelsKey: const Key('all-levels-option'),
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
    required this.onOpenChanged,
  });
  final FormGroup form;
  final bool open;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ReactiveValueListenableBuilder<bool>(
        formControlName: SessionFormControl.feeEnabled,
        builder: (context, enabledControl, _) {
          final enabled = enabledControl.value ?? false;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sessionFormFee,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            enabled
                                ? l10n.sessionFormFeeEnabled
                                : l10n.sessionFormFeeDisabled,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).extension<AppPalette>()!.mutedForeground,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        key: const Key('fee-enabled'),
                        value: enabled,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) {
                          enabledControl.value = value;
                          if (value) onOpenChanged(true);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      key: const Key('fee-collapse'),
                      onPressed: enabled ? () => onOpenChanged(!open) : null,
                      tooltip: open
                          ? MaterialLocalizations.of(
                              context,
                            ).expandedIconTapHint
                          : MaterialLocalizations.of(
                              context,
                            ).collapsedIconTapHint,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        enabled && open
                            ? AppIcons.chevronUp
                            : AppIcons.chevronDown,
                        color: enabled
                            ? Theme.of(
                                context,
                              ).extension<AppPalette>()!.mutedForeground
                            : Theme.of(context)
                                  .extension<AppPalette>()!
                                  .mutedForeground
                                  .withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: enabled && open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  key: const Key('fee-fields'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sessionFormFeeType,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ReactiveValueListenableBuilder<FeeType>(
                        formControlName: SessionFormControl.feeType,
                        builder: (context, type, _) => Row(
                          children: [
                            Expanded(
                              child: _FeeTypeOption(
                                key: const Key('fee-type-fixed'),
                                label: l10n.sessionFormFeeFixed,
                                selected:
                                    (type.value ?? FeeType.fixed) ==
                                    FeeType.fixed,
                                onTap: () => type.value = FeeType.fixed,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _FeeTypeOption(
                                key: const Key('fee-type-split'),
                                label: l10n.sessionFormFeeSplit,
                                selected: type.value == FeeType.splitEvenly,
                                onTap: () => type.value = FeeType.splitEvenly,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ReactiveValueListenableBuilder<FeeType>(
                        formControlName: SessionFormControl.feeType,
                        builder: (context, type, _) =>
                            type.value == FeeType.splitEvenly
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: .2),
                                  ),
                                ),
                                child: Text(
                                  l10n.sessionFormFeeSplitDescription,
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _FeeInput(
                                      key: const Key('male-fee-field'),
                                      label: l10n.createSessionFeeMale,
                                      formControlName:
                                          SessionFormControl.maleFee,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: _FeeInput(
                                      key: const Key('female-fee-field'),
                                      label: l10n.createSessionFeeFemale,
                                      formControlName:
                                          SessionFormControl.femaleFee,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LabeledField(
                        label: Text(l10n.sessionFormFeeNotes),
                        child: ReactiveTextField<String>(
                          formControlName: SessionFormControl.feeNotes,
                          minLines: 2,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeeTypeOption extends StatelessWidget {
  const _FeeTypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Material(
      color: selected ? color.withValues(alpha: .08) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? color : palette.border,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Each option spans half the row width, wide enough that the
          // extra 4pt to `minTapTarget` buys nothing — see AppSizes docs.
          constraints: const BoxConstraints(
            minHeight: AppSizes.compactTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? color : null,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeeInput extends StatelessWidget {
  const _FeeInput({
    required this.label,
    required this.formControlName,
    super.key,
  });

  final String label;
  final String formControlName;

  @override
  Widget build(BuildContext context) => _LabeledField(
    label: Text(label),
    child: Row(
      children: [
        Expanded(
          child: ReactiveTextField<int>(
            formControlName: formControlName,
            valueAccessor: CurrencyValueAccessor(),
            inputFormatters: [ThousandsSeparatorFormatter()],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '0'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'VND',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
          ),
        ),
      ],
    ),
  );
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
    final palette = Theme.of(context).extension<AppPalette>()!;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ReactiveValueListenableBuilder<bool>(
        formControlName: SessionFormControl.bulkEnabled,
        builder: (context, enabledControl, _) {
          final enabled = enabledControl.value ?? false;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sessionFormBulk,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ReactiveValueListenableBuilder<BulkCreationMode>(
                            formControlName: SessionFormControl.bulkMode,
                            builder: (context, modeControl, _) {
                              final mode = modeControl.value;
                              final subtext = enabled
                                  ? (mode == BulkCreationMode.recurringWeekdays
                                        ? l10n.sessionFormRecurring
                                        : l10n.sessionFormSpecificDates)
                                  : l10n.sessionFormBulkDisabled;
                              return Text(
                                subtext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: palette.mutedForeground,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        key: const Key('bulk-enabled'),
                        value: enabled,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) {
                          enabledControl.value = value;
                          if (value) onOpenChanged(true);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      key: const Key('bulk-collapse'),
                      onPressed: enabled ? () => onOpenChanged(!open) : null,
                      tooltip: open
                          ? MaterialLocalizations.of(
                              context,
                            ).expandedIconTapHint
                          : MaterialLocalizations.of(
                              context,
                            ).collapsedIconTapHint,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        enabled && open
                            ? AppIcons.chevronUp
                            : AppIcons.chevronDown,
                        color: enabled
                            ? palette.mutedForeground
                            : palette.mutedForeground.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: enabled && open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  key: const Key('bulk-fields'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ReactiveValueListenableBuilder<BulkCreationMode>(
                          formControlName: SessionFormControl.bulkMode,
                          builder: (context, mode, _) =>
                              SegmentedButton<BulkCreationMode>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: BulkCreationMode.specificDates,
                                    label: Text(
                                      l10n.sessionFormSpecificDates,
                                      maxLines: 1,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: BulkCreationMode.recurringWeekdays,
                                    label: Text(
                                      l10n.sessionFormRecurring,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                                selected: {
                                  mode.value ?? BulkCreationMode.specificDates,
                                },
                                onSelectionChanged: (value) =>
                                    mode.value = value.first,
                              ),
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
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      _BulkSessionCountText(form: form),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BulkSessionCountText extends StatelessWidget {
  const _BulkSessionCountText({required this.form});
  final FormGroup form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final theme = Theme.of(context);

    return ReactiveFormConsumer(
      builder: (context, formGroup, _) {
        final mode =
            formGroup.control(SessionFormControl.bulkMode).value
                as BulkCreationMode? ??
            BulkCreationMode.specificDates;
        final dates =
            formGroup.control(SessionFormControl.bulkDates).value
                as List<DateTime>? ??
            const [];
        final weekdays =
            formGroup.control(SessionFormControl.bulkWeekdays).value
                as List<int>? ??
            const [];
        final weeks =
            formGroup.control(SessionFormControl.bulkWeeks).value as int? ?? 1;

        final safeWeeks = (weeks > 0) ? weeks : 0;
        final count = switch (mode) {
          BulkCreationMode.specificDates => dates.length,
          BulkCreationMode.recurringWeekdays => weekdays.length * safeWeeks,
        };

        return Padding(
          key: const Key('bulk-session-count'),
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                AppIcons.calendar,
                size: 14,
                color: palette.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.sessionFormBulkWillCreate(count),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                    fontWeight: FontWeight.w500,
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

class _SpecificDateFields extends StatelessWidget {
  const _SpecificDateFields({required this.form});
  final FormGroup form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return ReactiveValueListenableBuilder<List<DateTime>>(
      formControlName: SessionFormControl.bulkDates,
      builder: (context, dates, _) {
        final dateList = dates.value ?? const [];
        final hasDates = dateList.isNotEmpty;
        final sortedDates = hasDates ? ([...dateList]..sort()) : <DateTime>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              key: const Key('bulk-pick-dates'),
              onPressed: () async {
                final result = await showAppMultiDatePicker(
                  context: context,
                  initialDates: dateList,
                  firstDate: DateTime.now(),
                  lastDate: SessionFormSubmission.maxBulkDate(DateTime.now()),
                );
                if (result == null) return;
                dates.value = result;
              },
              icon: const Icon(AppIcons.calendar, size: 18),
              label: Text(l10n.sessionFormPickDates),
            ),
            if (hasDates) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final date in sortedDates)
                    InputChip(
                      label: Text('${date.day}/${date.month}/${date.year}'),
                      onDeleted: () =>
                          dates.value = [...dates.value!]..remove(date),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Chưa chọn ngày nào',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RecurringFields extends StatelessWidget {
  const _RecurringFields({required this.form});
  final FormGroup form;

  String _weekdayLabel(BuildContext context, int weekday) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'vi') {
      return switch (weekday) {
        1 => 'Thứ 2',
        2 => 'Thứ 3',
        3 => 'Thứ 4',
        4 => 'Thứ 5',
        5 => 'Thứ 6',
        6 => 'Thứ 7',
        _ => 'Chủ nhật',
      };
    }
    if (locale == 'zh') {
      return switch (weekday) {
        1 => '周一',
        2 => '周二',
        3 => '周三',
        4 => '周四',
        5 => '周五',
        6 => '周六',
        _ => '周日',
      };
    }
    return switch (weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      _ => 'Sun',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chọn các thứ trong tuần:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ReactiveValueListenableBuilder<List<int>>(
          formControlName: SessionFormControl.bulkWeekdays,
          builder: (context, days, _) => Center(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: [
                for (var value = 1; value <= 7; value++)
                  AppFilterChip(
                    key: Key('bulk-weekday-${value % 7}'),
                    label: _weekdayLabel(context, value % 7),
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
        ),
        const SizedBox(height: AppSpacing.md),
        ReactiveTextField<int>(
          formControlName: SessionFormControl.bulkWeeks,
          valueAccessor: IntValueAccessor(),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.sessionFormWeekCount,
          ),
        ),
      ],
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.form,
    required this.open,
    required this.canHost,
    required this.clubs,
    required this.uploading,
    required this.onPickImages,
    required this.onOpenLibrary,
    required this.onOpenChanged,
    super.key,
  });
  final FormGroup form;
  final bool open;
  final bool canHost;
  final List<ClubSummary> clubs;
  final bool uploading;
  final VoidCallback onPickImages;
  final VoidCallback onOpenLibrary;
  final ValueChanged<bool> onOpenChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            key: const Key('advanced-toggle'),
            onTap: () => onOpenChanged(!open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sessionFormAdvanced,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: Icon(
                        open ? AppIcons.chevronUp : AppIcons.chevronDown,
                        color: palette.mutedForeground,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImageGallery(
                    form: form,
                    uploading: uploading,
                    onPick: onPickImages,
                    onOpenLibrary: onOpenLibrary,
                  ),
                  if (canHost) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.sessionFormCourtAppearance,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.sessionFormSelectCourtColor,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReactiveValueListenableBuilder<String>(
                      formControlName: SessionFormControl.courtColor,
                      builder: (context, color, _) => Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final option in [
                            (
                              hex: SessionFormUtils.courtColors[0],
                              label: l10n.sessionFormCourtColorGreen,
                            ),
                            (
                              hex: SessionFormUtils.courtColors[1],
                              label: l10n.sessionFormCourtColorGrey,
                            ),
                            (
                              hex: SessionFormUtils.courtColors[2],
                              label: l10n.sessionFormCourtColorNavy,
                            ),
                            (
                              hex: SessionFormUtils.courtColors[3],
                              label: l10n.sessionFormCourtColorRed,
                            ),
                          ])
                            _CourtColorOption(
                              key: ValueKey('court-color-${option.hex}'),
                              color: _hexColor(option.hex),
                              label: option.label,
                              selected: color.value == option.hex,
                              onSelected: () => color.value = option.hex,
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
                    builder: (context, type, _) => Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _MatchTypeOption(
                          key: const Key('match-type-doubles'),
                          icon: AppIcons.users,
                          label: l10n.sessionFormDoubles,
                          selected:
                              (type.value ?? MatchType.doubles) ==
                              MatchType.doubles,
                          onPressed: () => type.value = MatchType.doubles,
                        ),
                        _MatchTypeOption(
                          key: const Key('match-type-singles'),
                          icon: AppIcons.user,
                          label: l10n.sessionFormSingles,
                          selected: type.value == MatchType.singles,
                          onPressed: () => type.value = MatchType.singles,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fields = [
                        _LabeledAdvancedField(
                          key: const Key('shuttlecock-field'),
                          label: l10n.sessionFormShuttlecock,
                          child: ReactiveTextField<String>(
                            formControlName: SessionFormControl.shuttlecock,
                            decoration: InputDecoration(
                              hintText: l10n.sessionFormShuttlecockPlaceholder,
                            ),
                          ),
                        ),
                        _LabeledAdvancedField(
                          key: const Key('max-players-field'),
                          label: l10n.createSessionMaxPerCourt,
                          child: ReactiveTextField<int>(
                            formControlName: SessionFormControl.maxPlayers,
                            valueAccessor: IntValueAccessor(),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: '0',
                              suffixText: l10n.sessionFormPlayersPerCourtUnit,
                            ),
                            validationMessages: {
                              ValidationMessage.min: (_) =>
                                  l10n.sessionFormValidationPlayers,
                              ValidationMessage.max: (_) =>
                                  l10n.sessionFormValidationPlayers,
                              'domain': (_) =>
                                  l10n.sessionFormValidationPlayers,
                            },
                          ),
                        ),
                      ];
                      if (constraints.maxWidth < 340) {
                        return Column(
                          children: [
                            fields.first,
                            const SizedBox(height: AppSpacing.md),
                            fields.last,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields.first),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: fields.last),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledAdvancedField(
                    label: l10n.sessionFormReferenceVideo,
                    helper: l10n.sessionFormReferenceVideoHelper,
                    child: ReactiveTextField<String>(
                      formControlName: SessionFormControl.referenceVideo,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: l10n.sessionFormReferenceVideoPlaceholder,
                      ),
                      validationMessages: {
                        'domain': (_) => l10n.sessionFormValidationVideo,
                      },
                    ),
                  ),
                  if (canHost) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledAdvancedField(
                      label: l10n.sessionFormDefaultClub,
                      helper: l10n.sessionFormDefaultClubHelper,
                      child: ReactiveDropdownField<String>(
                        formControlName: SessionFormControl.clubId,
                        decoration: InputDecoration(
                          hintText: l10n.sessionFormSelectDefaultClub,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(
                              l10n.sessionFormNoClub,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                          for (final club in clubs)
                            DropdownMenuItem(
                              value: club.id,
                              child: Text(
                                club.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                        ],
                      ),
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

class _CourtColorOption extends StatelessWidget {
  const _CourtColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? .2 : .1),
                  blurRadius: selected ? 8 : 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MatchTypeOption extends StatelessWidget {
  const _MatchTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
    return Semantics(
      selected: selected,
      button: true,
      child: selected
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

class _LabeledAdvancedField extends StatelessWidget {
  const _LabeledAdvancedField({
    required this.label,
    required this.child,
    this.helper,
    super.key,
  });
  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      child,
      if (helper != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          helper!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
          ),
        ),
      ],
    ],
  );
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.form,
    required this.uploading,
    required this.onPick,
    required this.onOpenLibrary,
  });
  final FormGroup form;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onOpenLibrary;
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
                  child: Text(
                    l10n.sessionFormImages,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${list.length}/5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).extension<AppPalette>()!.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (list.isEmpty)
              CustomPaint(
                key: const Key('session-images-empty'),
                painter: _DashedBorderPainter(
                  color: Theme.of(context).dividerColor,
                  radius: AppRadius.lg,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.imagePlus,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.sessionFormNoImages,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.sessionFormDropImagesHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).extension<AppPalette>()!.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ImageActionButtons(
                        uploading: uploading,
                        disabled: false,
                        onPick: onPick,
                        onOpenLibrary: onOpenLibrary,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 124,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  onReorderItem: (oldIndex, newIndex) {
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (item.localPath != null)
                            Image.file(
                              File(item.localPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Colors.black12,
                                child: Icon(AppIcons.imageOff),
                              ),
                            )
                          else
                            Image.network(
                              item.url!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
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
                                    tooltip: l10n.sessionFormBanner,
                                    onPressed: () {
                                      form
                                          .control(
                                            SessionFormControl.bannerPublicId,
                                          )
                                          .value = item
                                          .publicId;
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
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ImageActionButtons(
                uploading: uploading,
                disabled: list.length >= 5,
                onPick: onPick,
                onOpenLibrary: onOpenLibrary,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ImageActionButtons extends StatelessWidget {
  const _ImageActionButtons({
    required this.uploading,
    required this.disabled,
    required this.onPick,
    required this.onOpenLibrary,
  });
  final bool uploading;
  final bool disabled;
  final VoidCallback onPick;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          key: const Key('upload-session-images'),
          onPressed: uploading || disabled ? null : onPick,
          icon: uploading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.upload, size: 18),
          label: Text(l10n.sessionFormUploadNew),
          style: FilledButton.styleFrom(
            disabledBackgroundColor: palette.muted.withValues(alpha: 0.6),
            disabledForegroundColor: palette.mutedForeground,
          ),
        ),
        OutlinedButton(
          key: const Key('open-account-image-library'),
          onPressed: uploading ? null : onOpenLibrary,
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: palette.mutedForeground,
            disabledBackgroundColor: palette.muted.withValues(alpha: 0.3),
            side: BorderSide(color: palette.border.withValues(alpha: 0.4)),
          ),
          child: Text(l10n.sessionFormSelectFromGallery),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 7),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _AccountImageLibrarySheet extends ConsumerStatefulWidget {
  const _AccountImageLibrarySheet({required this.initialSelection});
  final List<UserImageAsset> initialSelection;

  @override
  ConsumerState<_AccountImageLibrarySheet> createState() =>
      _AccountImageLibrarySheetState();
}

class _AccountImageLibrarySheetState
    extends ConsumerState<_AccountImageLibrarySheet> {
  final _images = <UserImageAsset>[];
  late final Map<String, UserImageAsset> _selected;
  var _page = 0;
  var _totalPages = 1;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final image in widget.initialSelection) image.publicId: image,
    };
    unawaited(_loadPage(1));
  }

  Future<void> _loadPage(int page) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(sessionFormServiceProvider)
          .getMyImages(page: page);
      if (!mounted) return;
      setState(() {
        final existing = _images.map((image) => image.publicId).toSet();
        _images.addAll(
          result.items.where((image) => existing.add(image.publicId)),
        );
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } on Object {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context).sessionFormGalleryError,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(UserImageAsset image) {
    if (_selected.remove(image.publicId) != null) {
      setState(() {});
      return;
    }
    if (_selected.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sessionFormImageLimit),
        ),
      );
      return;
    }
    setState(() => _selected[image.publicId] = image);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          AppSheetHeader(
            title: l10n.sessionFormSelectFromGallery,
            subtitle: l10n.sessionFormGallerySelection(_selected.length, 5),
          ),
          Expanded(child: _buildContent(context)),
          if (_page < _totalPages || (_loading && _images.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: OutlinedButton(
                key: const Key('load-more-account-images'),
                onPressed: _loading ? null : () => _loadPage(_page + 1),
                child: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonLoadMore),
              ),
            ),
          AppSheetActionBar(
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
                    key: const Key('confirm-account-images'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_selected.values.toList(growable: false)),
                    child: Text(l10n.commonConfirm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _loadPage(1),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.imageOff, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.sessionFormGalleryEmpty),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const Key('account-image-grid'),
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          final selected = _selected.containsKey(image.publicId);
          return Semantics(
            button: true,
            selected: selected,
            label: l10n.sessionFormGalleryImage(index + 1),
            child: InkWell(
              key: ValueKey('account-image-${image.publicId}'),
              onTap: () => _toggle(image),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(
                      image.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(AppIcons.imageOff),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      child: Icon(
                        selected ? AppIcons.check : AppIcons.circle,
                        size: 16,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiSessionSheet extends ConsumerStatefulWidget {
  const _AiSessionSheet();
  @override
  ConsumerState<_AiSessionSheet> createState() => _AiSessionSheetState();
}

class _AiSessionSheetState extends ConsumerState<_AiSessionSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    // `showModalBottomSheet` pushes this sheet up by the keyboard's height,
    // but a fixed `.9 * screen height` doesn't shrink to match — with the
    // text field autofocused, that leaves the action bar clipped off the
    // bottom the instant the keyboard opens. Cap to what's actually visible.
    final maxHeight = media.size.height - media.viewInsets.bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SizedBox(
        key: const Key('create-session-ai-sheet'),
        height: (media.size.height * .9).clamp(0, maxHeight),
        child: Column(
          children: [
            AppSheetHeader(
              title: l10n.sessionFormAiTitle,
              showCloseButton: false,
              leadingIcon: Icons.auto_awesome,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.sessionFormAiDescription),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
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
            ),
            AppSheetActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: Text(l10n.sessionFormCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
