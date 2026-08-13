import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/registration/application/registration_realtime_provider.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/reference_video.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_bottom_bar.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_hero.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_info.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_stats.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_recommendations.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_reference_video.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// Public session detail, ported from the web app's `/sessions/[id]`.
///
/// One continuous scroll rather than tabs: the web page is a single column,
/// and a player deciding whether to join reads top to bottom. The live court
/// board keeps its own screen — see [AppRoutes.liveSession].
///
/// Reachable signed-out, like browse.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));
    // Keeps the bar honest while the screen is open: the host approving on
    // another device flips "Xem vé" to "Vào sân" without a manual refresh.
    ref.watch(registrationRealtimeProvider(sessionId));

    return Scaffold(
      // No AppBar: the hero's floating back button replaces it, so the photo
      // runs under the status bar exactly as it does on web.
      body: session.when(
        loading: () => const AppLoadingView(),
        error: (error, _) => SafeArea(
          child: Stack(
            children: [
              AppErrorView(
                error: error,
                onRetry: () => ref.invalidate(sessionDetailProvider(sessionId)),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: IconButton.filledTonal(
                  icon: const Icon(AppIcons.arrowBack),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      unawaited(Navigator.of(context).maybePop());
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        data: (session) => _Body(
          session: session,
          onRefresh: () => ref.refresh(sessionDetailProvider(sessionId).future),
        ),
      ),
      bottomNavigationBar: session.whenOrNull(
        data: (session) => SessionDetailBottomBar(
          session: session,
          onManage: () => context.push(AppRoutes.manageSession(session.id)),
          onOpenLive: () => context.push(AppRoutes.liveSession(session.id)),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.session,
    required this.onRefresh,
  });

  final Session session;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return RefreshIndicator(
      onRefresh: onRefresh,
      // The hero sits under the status bar, so the spinner must drop below it
      // rather than land on the photo.
      edgeOffset: MediaQuery.paddingOf(context).top + AppSpacing.md,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SessionDetailHero(
            session: session,
            onShare: () => _share(context, session),
          ),
          Transform.translate(
            // Matches the web's `mt="-16px"`: the content sheet laps over the
            // photo so the rounded corners read as a card lifting off it.
            offset: const Offset(0, -16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl + 4),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionDetailInfo(
                    session: session,
                    onOpenMap: _mapUrl(session) == null
                        ? null
                        : () => _openMap(session),
                    onCallHost: session.isCrawled || _hostPhone(session) == null
                        ? null
                        : () => _call(session),
                    onZaloHost:
                        session.isCrawled ||
                            !session.allowZaloContact ||
                            _hostPhone(session) == null
                        ? null
                        : () => _openZalo(session),
                  ),
                  Divider(height: AppSpacing.lg * 2, color: palette.border),
                  SessionDetailStats(session: session),
                  if (ReferenceVideo.parse(session.referenceVideoUrl)
                      case final video?) ...[
                    Divider(height: AppSpacing.lg * 2, color: palette.border),
                    SessionReferenceVideo(video: video),
                  ],
                ],
              ),
            ),
          ),
          // Outside the sheet, like the web app: the rail scrolls edge to edge
          // rather than sitting inside the card's padding.
          SessionRecommendations(sessionId: session.id),
          // Keep the final recommendation/link clear of the sticky action bar.
          const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
        ],
      ),
    );
  }

  static String? _hostPhone(Session session) {
    final phone = session.hostPhone?.trim();
    return phone == null || phone.isEmpty ? null : phone;
  }

  static Uri? _mapUrl(Session session) {
    final query = [
      session.venue?.name?.trim(),
      session.venue?.displayAddress ?? session.location?.trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    if (query.isEmpty) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  Future<void> _openMap(Session session) async {
    final uri = _mapUrl(session);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(Session session) async {
    final phone = _hostPhone(session);
    if (phone == null) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _openZalo(Session session) async {
    final phone = _hostPhone(session);
    if (phone == null) return;
    // Zalo resolves a profile by national number: strip the +84 form back to
    // a leading 0, which is how the web app normalizes it too.
    final normalized = phone.startsWith('+84')
        ? '0${phone.substring(3)}'
        : phone;
    await launchUrl(
      Uri.parse('https://zalo.me/${normalized.replaceAll(RegExp(r'\s+'), '')}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _share(BuildContext context, Session session) async {
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject();
    await SharePlus.instance.share(
      ShareParams(
        title: session.name,
        text:
            '${session.name}\n'
            'https://vmito.com/sessions/${session.slug ?? session.id}',
        subject: l10n.sessionShareAction,
        // iPad anchors the share sheet to the tapped rect; without it the
        // sheet throws rather than opening.
        sharePositionOrigin: box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }
}
