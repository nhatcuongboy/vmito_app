import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/utils/avatar_url.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/chat/domain/chat_mode.dart';
import 'package:vmito_app/features/session/application/player/host_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_host_detail_sections.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// The web app's "Thông tin Host" modal (`AppHostDetail.tsx`), as a sheet.
///
/// Does nothing for a crawled session: those carry a host name scraped from
/// Facebook and no account to show reputation for.
Future<void> showSessionHostDetailSheet(
  BuildContext context, {
  required Session session,
}) {
  final hostId = session.hostAccountId;
  if (hostId == null) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SessionHostDetailSheet(session: session, hostId: hostId),
  );
}

class _SessionHostDetailSheet extends ConsumerWidget {
  const _SessionHostDetailSheet({required this.session, required this.hostId});

  final Session session;
  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(hostDetailStatsProvider(hostId));
    final isDark = theme.brightness == Brightness.dark;
    final phone = session.hostPhone?.trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      minChildSize: .5,
      builder: (context, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          // The web modal's `#F6F7F9` page behind floating white cards.
          color: isDark
              ? theme.scaffoldBackgroundColor
              : const Color(0xFFF6F7F9),
          child: ListView(
            key: const Key('session-host-detail-sheet'),
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              _Hero(
                name: session.displayHostName,
                image: session.host?.image,
                onOpenProfile: () => _openProfile(context),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: SessionHostDetailBody(
                  stats: stats,
                  phone: phone == null || phone.isEmpty ? null : phone,
                  allowZaloContact: session.allowZaloContact,
                  onOpenProfile: () => _openProfile(context),
                  onMessage: _canMessage(ref) ? () => _openChat(context) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    unawaited(
      context.pushNamed(
        AppRoutes.namePublicProfile,
        pathParameters: {'id': hostId},
      ),
    );
  }

  bool _canMessage(WidgetRef ref) {
    if (hostId == ref.read(currentUserProvider)?.id) return false;
    // Same gate as the public-profile "Nhắn tin" CTA — hidden whenever chat
    // is disabled, the host hasn't consented, or either side blocked.
    return ref
        .watch(publicUserProvider(hostId))
        .maybeWhen(
          data: (profile) => profile.chatMode != ChatMode.unavailable,
          orElse: () => false,
        );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).pop();
    unawaited(
      context.push(
        AppRoutes.chatComposeFor(
          targetUserId: hostId,
          targetName: session.displayHostName,
          targetImage: session.host?.image,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.image,
    required this.onOpenProfile,
  });

  final String name;
  final String? image;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = image == null || image!.trim().isEmpty ? null : image!.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, .6, 1],
          colors: [Color(0xFF16A34A), Color(0xFF15803D), Color(0xFF14532D)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: url == null
                ? null
                : () => showAppLightbox(
                    context,
                    images: [fullSizeAvatarUrl(url)],
                  ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: UserAvatar(
                name: name.isEmpty ? 'Host' : name,
                imageUrl: url,
                size: 90,
                borderWidth: 0,
                boxShadow: const [],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenProfile,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
