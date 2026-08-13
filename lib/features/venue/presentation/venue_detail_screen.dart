import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_content.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({required this.venueId, super.key});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueDetailProvider(venueId));
    return venue.when(
      data: (data) => _VenueDetail(venue: data),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
        ),
      ),
    );
  }
}

class _VenueDetail extends ConsumerStatefulWidget {
  const _VenueDetail({required this.venue});

  final Venue venue;

  @override
  ConsumerState<_VenueDetail> createState() => _VenueDetailState();
}

class _VenueDetailState extends ConsumerState<_VenueDetail> {
  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final priceBooks = ref.watch(venuePriceBooksProvider(venue.id));
    final minimumPrice = priceBooks.whenOrNull(data: minimumVenuePrice);

    return Scaffold(
      body: VenueDetailContent(
        venue: venue,
        priceBooks: priceBooks,
        onBack: _back,
        onShare: () => unawaited(_share(venue)),
        onCall: () => unawaited(_call(venue)),
        onWebsite: () => unawaited(_website(venue)),
        onZalo: () => unawaited(_zalo(venue)),
        onDirections: () => unawaited(_directions(venue)),
        onFindSessions: () => _findSessions(venue),
        onRequestUpdate: () => unawaited(_request('UPDATE', venue)),
      ),
      bottomNavigationBar: VenueDetailBottomBar(
        phone: venue.phone,
        minimumPrice: minimumPrice,
        onCall: () => unawaited(_call(venue)),
        onFindSessions: () => _findSessions(venue),
      ),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.venues);
    }
  }

  void _findSessions(Venue venue) =>
      context.go(AppRoutes.homeForVenue(venue.id, venue.name));

  Future<void> _share(Venue venue) => SharePlus.instance.share(
    ShareParams(
      title: venue.name,
      text: AppLocalizations.of(context).venueShareText(
        venue.name,
        'https://vmito.com/venues/${venue.slug ?? venue.id}',
      ),
    ),
  );

  Future<void> _call(Venue venue) async {
    final phone = venue.phone?.trim();
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _website(Venue venue) async {
    final website = venue.website?.trim();
    if (website == null || website.isEmpty) return;
    final uri = Uri.tryParse(website);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _zalo(Venue venue) async {
    final phone = venue.phone?.trim();
    if (phone == null || phone.isEmpty) return;
    final normalized = phone.startsWith('+84')
        ? '0${phone.substring(3)}'
        : phone;
    await launchUrl(
      Uri.parse('https://zalo.me/${normalized.replaceAll(RegExp(r'\s+'), '')}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _directions(Venue venue) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': venue.lat == null
          ? '${venue.name} ${venue.addressLabel}'
          : '${venue.lat},${venue.lng}',
    }),
    mode: LaunchMode.externalApplication,
  );

  Future<void> _request(String type, Venue venue) async {
    final successMessage = AppLocalizations.of(context).venueRequestSent;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VenueRequestForm(type: type, venue: venue),
    );
    if (result != null && context.mounted) {
      try {
        await ref
            .read(venueServiceProvider)
            .createRequest(type: type, venueId: venue.id, payload: result);
        _message(successMessage);
      } on Object catch (error) {
        _message(error.toString());
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

// This legacy form is intentionally unchanged. The detail-page work only
// repositions its trigger; fields, validation and submission stay intact.
class _VenueRequestForm extends StatefulWidget {
  const _VenueRequestForm({required this.type, required this.venue});
  final String type;
  final Venue venue;
  @override
  State<_VenueRequestForm> createState() => _VenueRequestFormState();
}

class _VenueRequestFormState extends State<_VenueRequestForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.venue.name);
  late final _address = TextEditingController(text: widget.venue.address);
  late final _city = TextEditingController(
    text: widget.venue.newCity ?? widget.venue.city,
  );
  late final _district = TextEditingController(
    text: widget.venue.newDistrict ?? widget.venue.district,
  );
  late final _note = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _district.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Báo chỉnh sửa thông tin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  label: AppRequiredLabel('Tên sân'),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Nhập tên sân' : null,
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  label: AppRequiredLabel('Địa chỉ'),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Nhập địa chỉ' : null,
              ),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'Tỉnh / thành'),
              ),
              TextFormField(
                controller: _district,
                decoration: const InputDecoration(labelText: 'Phường / xã'),
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      Navigator.pop(context, {
                        'name': _name.text.trim(),
                        'address': _address.text.trim(),
                        'street': _address.text.trim(),
                        'newCity': _city.text.trim(),
                        'newDistrict': _district.text.trim(),
                        if (_note.text.trim().isNotEmpty)
                          'note': _note.text.trim(),
                      });
                    }
                  },
                  child: const Text('Gửi yêu cầu'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
