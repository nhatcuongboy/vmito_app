import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_content.dart';
import 'package:vmito_app/features/venue/presentation/venue_edit_request_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';

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

    return Scaffold(
      body: VenueDetailContent(
        venue: venue,
        priceBooks: priceBooks,
        onBack: _back,
        onShare: () => unawaited(_share(venue)),
        onCall: () => unawaited(_call(venue)),
        onZalo: () => unawaited(_zalo(venue)),
        onDirections: () => unawaited(_directions(venue)),
        onFindSessions: () => _findSessions(venue),
        onRequestUpdate: () => unawaited(_requestUpdate(venue)),
      ),
      bottomNavigationBar: VenueDetailBottomBar(
        phone: venue.phone,
        website: venue.website,
        onCall: () => unawaited(_call(venue)),
        onZalo: () => unawaited(_zalo(venue)),
        onWebsite: () => unawaited(_website(venue)),
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

  void _findSessions(Venue venue) {
    final name = venueDisplayName(venue, AppLocalizations.of(context));
    context.go(AppRoutes.homeForVenue(venue.id, name));
  }

  Future<void> _share(Venue venue) {
    final l10n = AppLocalizations.of(context);
    final name = venueDisplayName(venue, l10n);
    return SharePlus.instance.share(
      ShareParams(
        title: name,
        text: l10n.venueShareText(
          name,
          'https://vmito.com/venues/${venue.slug ?? venue.id}',
        ),
      ),
    );
  }

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
          ? '${venue.name} ${venue.address ?? ''}'
          : '${venue.lat},${venue.lng}',
    }),
    mode: LaunchMode.externalApplication,
  );

  Future<void> _requestUpdate(Venue venue) async {
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      await showLoginPromptDialog(
        context,
        featureName: AppLocalizations.of(context).venueRequestUpdate,
        targetRoute: AppRoutes.venueDetail(venue.id),
      );
      return;
    }
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VenueEditRequestScreen(venue: venue),
      ),
    );
    if (submitted == true && mounted) {
      _message(AppLocalizations.of(context).venueRequestSent);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
