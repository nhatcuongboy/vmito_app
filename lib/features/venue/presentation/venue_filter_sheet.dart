import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/venue/domain/form/venue_filter_form.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_filter_sheet.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

enum VenueSortOption {
  distance('distance'),
  relevance('relevance'),
  newest('createdAt'),
  nameAsc('name'),
  priceAsc('hourlyRateFixed'),
  courtsDesc('numberOfCourts');

  const VenueSortOption(this.value);
  final String value;

  static VenueSortOption fromValue(String value) =>
      VenueSortOption.values.firstWhere(
        (option) => option.value == value,
        orElse: () => VenueSortOption.relevance,
      );

  String label(AppLocalizations l10n) => switch (this) {
    VenueSortOption.distance => l10n.venueSortDistance,
    VenueSortOption.relevance => l10n.venueSortRelevance,
    VenueSortOption.newest => l10n.venueSortNewest,
    VenueSortOption.nameAsc => l10n.venueSortName,
    VenueSortOption.priceAsc => l10n.venueSortPrice,
    VenueSortOption.courtsDesc => l10n.venueSortCourts,
  };

  IconData get icon => switch (this) {
    VenueSortOption.distance => AppIcons.location,
    VenueSortOption.relevance => AppIcons.star,
    VenueSortOption.newest => AppIcons.calendarArrowDown,
    VenueSortOption.nameAsc => AppIcons.sortAlpha,
    VenueSortOption.priceAsc => AppIcons.trendingUp,
    VenueSortOption.courtsDesc => AppIcons.grid2x2,
  };
}

class VenueFilterSheet extends ConsumerStatefulWidget {
  const VenueFilterSheet({
    required this.initial,
    this.preferredCity,
    super.key,
  });

  final VenueFilter initial;
  final String? preferredCity;

  @override
  ConsumerState<VenueFilterSheet> createState() => _VenueFilterSheetState();
}

class _VenueFilterSheetState extends ConsumerState<VenueFilterSheet> {
  late final FormGroup _form;
  DeviceCoordinates? _coordinates;
  bool _isLocating = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _form = createVenueFilterForm(widget.initial);
    if (widget.initial.latitude != null && widget.initial.longitude != null) {
      _coordinates = DeviceCoordinates(
        latitude: widget.initial.latitude!,
        longitude: widget.initial.longitude!,
      );
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _selectSort(VenueSortOption option) async {
    if (option != VenueSortOption.distance) {
      _form.control(VenueFilterControl.sortBy).value = option.value;
      return;
    }
    if (_coordinates != null) {
      _form.control(VenueFilterControl.sortBy).value = option.value;
      return;
    }
    setState(() => _isLocating = true);
    try {
      _coordinates = await ref.read(deviceLocationServiceProvider).call();
      if (!mounted) return;
      _form.control(VenueFilterControl.sortBy).value = option.value;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).venueFilterLocationDenied,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _reset() {
    _coordinates = null;
    _form.control(VenueFilterControl.city).value = widget.preferredCity;
    _form.control(VenueFilterControl.district).value = null;
    _form.control(VenueFilterControl.sortBy).value =
        VenueSortOption.relevance.value;
    _form.control(VenueFilterControl.favoriteOnly).value = false;
    _form.markAsUntouched();
  }

  void _apply() {
    if (_isSubmitting || _isLocating) return;
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(
      venueFilterFromForm(
        form: _form,
        initial: widget.initial,
        preferredCity: widget.preferredCity,
        latitude: _coordinates?.latitude,
        longitude: _coordinates?.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveFormConsumer(
        builder: (context, _, child) {
          final pending = venueFilterFromForm(
            form: _form,
            initial: widget.initial,
            preferredCity: widget.preferredCity,
            latitude: _coordinates?.latitude,
            longitude: _coordinates?.longitude,
          );
          final count = pending.activeCount(
            preferredCity: widget.preferredCity,
          );
          return AppFilterSheetScaffold(
            title: l10n.venueFiltersTitle,
            activeCount: count,
            activeCountLabel: l10n.sessionFiltersSelected(count),
            resetLabel: l10n.venueFiltersReset,
            applyLabel: l10n.venueFiltersApply,
            resetButtonKey: const Key('venue-filter-reset'),
            applyButtonKey: const Key('venue-filter-apply'),
            closeButtonKey: const Key('venue-filter-close'),
            actionsEnabled: !_isSubmitting && !_isLocating,
            onReset: _reset,
            onApply: _apply,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterSection(
                  title: l10n.venueFiltersSort,
                  icon: AppIcons.sortOrder,
                  child: ReactiveValueListenableBuilder<String>(
                    formControlName: VenueFilterControl.sortBy,
                    builder: (context, control, _) => AppFilterOptionGroup(
                      values: VenueSortOption.values,
                      selected: {
                        VenueSortOption.fromValue(
                          control.value ?? VenueSortOption.relevance.value,
                        ),
                      },
                      label: (option) => option.label(l10n),
                      icon: (option) =>
                          option == VenueSortOption.distance && _isLocating
                          ? null
                          : option.icon,
                      itemKey: (option) => Key(
                        'venue-filter-sort-${option.value}',
                      ),
                      enabled: !_isLocating,
                      onSelected: (option) => unawaited(_selectSort(option)),
                    ),
                  ),
                ),
                AppFilterSection(
                  title: l10n.venueFiltersArea,
                  icon: AppIcons.mapPin,
                  showDivider: false,
                  child: Column(
                    children: [
                      ReactiveTextField<String>(
                        key: const Key('venue-filter-city'),
                        formControlName: VenueFilterControl.city,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.venueFilterCity,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ReactiveTextField<String>(
                        key: const Key('venue-filter-district'),
                        formControlName: VenueFilterControl.district,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _apply(),
                        decoration: InputDecoration(
                          labelText: l10n.venueFilterDistrict,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ReactiveCheckboxListTile(
                        key: const Key('venue-filter-favorite'),
                        formControlName: VenueFilterControl.favoriteOnly,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.venueFilterFavoriteOnly),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
