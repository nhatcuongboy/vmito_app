import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/presentation/public_profile_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      if (AppConfig.enableAuthBypass && user.id == developmentBypassUserId) {
        return _DevelopmentProfilePreview(user: user);
      }
      return PublicProfileScreen(userId: user.id, isRootProfile: true);
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Icon(
            AppIcons.profile,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

/// Auth bypass deliberately creates no backend user, so its profile must stay
/// local and never request the public-profile endpoints.
class _DevelopmentProfilePreview extends StatelessWidget {
  const _DevelopmentProfilePreview({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => context.pushNamed(AppRoutes.nameSettings),
            icon: const Icon(AppIcons.settings),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                name: user.displayName,
                gender: user.gender,
                imageUrl: user.image,
                size: 96,
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 6),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
