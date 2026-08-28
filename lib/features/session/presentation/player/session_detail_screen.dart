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
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
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

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.pinned,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool pinned;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, color: pinned ? null : Colors.white),
    style: IconButton.styleFrom(
      backgroundColor: pinned ? Colors.transparent : Colors.black54,
      minimumSize: const Size.square(44),
    ),
    onPressed: onPressed,
  );
}

class _Body extends StatefulWidget {
  const _Body({
    required this.session,
    required this.onRefresh,
  });

  final Session session;
  final Future<void> Function() onRefresh;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _scrollController = ScrollController();
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final pinned =
        _scrollController.offset >=
        SessionDetailHero.heroHeight - AppSizes.appBarHeight - AppSpacing.md;
    if (pinned != _isPinned && mounted) setState(() => _isPinned = pinned);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    const heroHeight = SessionDetailHero.heroHeight;
    final pinnedForeground = theme.colorScheme.onSurface;
    const overlayForeground = Colors.white;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      // The hero sits under the status bar, so the spinner must drop below it
      // rather than land on the photo.
      edgeOffset: MediaQuery.paddingOf(context).top + AppSpacing.md,
      child: CustomScrollView(
        key: const Key('session-detail-scroll'),
        controller: _scrollController,
        clipBehavior: Clip.none,
        // At the top, the sheet must paint over the hero so its rounded top
        // corners remain visible. Once pinned, the app bar must stay above
        // the scrolling content again.
        paintOrder: _isPinned
            ? SliverPaintOrder.firstIsTop
            : SliverPaintOrder.lastIsTop,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            key: const Key('session-detail-app-bar'),
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            backgroundColor: _isPinned
                ? theme.colorScheme.surface
                : Colors.transparent,
            foregroundColor: _isPinned ? pinnedForeground : overlayForeground,
            surfaceTintColor: theme.colorScheme.surface,
            shadowColor: Colors.black26,
            elevation: _isPinned ? 2 : 0,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: _HeaderButton(
                key: const Key('session-back-button'),
                icon: AppIcons.chevronLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                pinned: _isPinned,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            title: AnimatedOpacity(
              key: const Key('session-sticky-title'),
              opacity: _isPinned ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                widget.session.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              FavoriteButton(
                key: const Key('session-favorite-button'),
                type: FavoriteType.session,
                targetId: widget.session.id,
                overlay: !_isPinned,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                child: _HeaderButton(
                  key: const Key('session-share-button'),
                  icon: AppIcons.share,
                  tooltip: l10n.sessionShareAction,
                  pinned: _isPinned,
                  onPressed: () => _share(context, widget.session),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: SessionDetailHero(session: widget.session),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              // Matches the web's `mt="-16px"`: the content sheet laps over
              // the photo so the rounded corners read as a card lifting off it.
              offset: const Offset(0, -16),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl + 4),
                ),
                child: Container(
                  color: theme.colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SessionDetailInfo(
                        session: widget.session,
                        onOpenMap: _mapUrl(widget.session) == null
                            ? null
                            : () => _openMap(widget.session),
                        onCallHost:
                            widget.session.isCrawled ||
                                _hostPhone(widget.session) == null
                            ? null
                            : () => _call(widget.session),
                        onZaloHost:
                            widget.session.isCrawled ||
                                !widget.session.allowZaloContact ||
                                _hostPhone(widget.session) == null
                            ? null
                            : () => _openZalo(widget.session),
                        onOpenHost: widget.session.hostAccountId == null
                            ? null
                            : () => context.push(
                                AppRoutes.publicProfile(
                                  widget.session.hostAccountId!,
                                ),
                              ),
                        onOpenOriginalPost:
                            widget.session.isCrawled &&
                                _externalUrl(widget.session) != null
                            ? () => _openOriginalPost(widget.session)
                            : null,
                      ),
                      Divider(height: AppSpacing.lg, color: palette.border),
                      SessionDetailStats(session: widget.session),
                      if (ReferenceVideo.parse(
                            widget.session.referenceVideoUrl,
                          )
                          case final video?) ...[
                        Divider(
                          height: AppSpacing.lg,
                          color: palette.border,
                        ),
                        SessionReferenceVideo(video: video),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Outside the sheet, like the web app: the rail scrolls edge to edge
          // rather than sitting inside the card's padding.
          SliverToBoxAdapter(
            child: SessionRecommendations(sessionId: widget.session.id),
          ),
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

  static Uri? _externalUrl(Session session) =>
      Uri.tryParse(session.externalUrl?.trim() ?? '');

  Future<void> _openOriginalPost(Session session) async {
    final uri = _externalUrl(session);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
