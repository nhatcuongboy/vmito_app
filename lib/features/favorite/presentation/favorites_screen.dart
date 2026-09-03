import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({
    this.initialType = FavoriteType.session,
    super.key,
  });

  final FavoriteType initialType;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late FavoriteType _type;
  late Future<List<FavoriteTarget>> _future;
  final _scrollController = ScrollController();
  late final VoidCallback _removeReselectHandler;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _future = _load();
    _removeReselectHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 3,
          onReselect: () => scrollToTop(_scrollController),
        );
  }

  @override
  void didUpdateWidget(FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialType != widget.initialType &&
        widget.initialType != _type) {
      setState(() {
        _type = widget.initialType;
        _future = _load();
      });
    }
  }

  @override
  void dispose() {
    _removeReselectHandler();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<FavoriteTarget>> _load() async =>
      (await ref.read(profileTabsServiceProvider).favorites(_type.wireValue))
          .items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.menuOpenTooltip,
          icon: const Icon(AppIcons.menu),
          onPressed: () =>
              ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(l10n.navFavorites),
        actions: [
          if (isAuthenticated)
            const NotificationHeaderButton()
          else
            IconButton(
              tooltip: l10n.authSignIn,
              icon: const Icon(AppIcons.login),
              onPressed: () => context.push(AppRoutes.signIn),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<FavoriteType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: FavoriteType.session,
                  label: Text(l10n.favoritesSessions),
                ),
                ButtonSegment(
                  value: FavoriteType.venue,
                  label: Text(l10n.favoritesVenues),
                ),
                ButtonSegment(
                  value: FavoriteType.club,
                  label: Text(l10n.favoritesClubs),
                ),
                ButtonSegment(
                  value: FavoriteType.tournament,
                  label: Text(l10n.favoritesTournaments),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() {
                _type = value.first;
                _future = _load();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FavoriteTarget>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorView(
                    error: snapshot.error!,
                    onRetry: () => setState(() => _future = _load()),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return _EmptyFavorites(l10n.favoritesEmpty);
                }
                return ListView.separated(
                  controller: _scrollController,
                  key: PageStorageKey('favorites-${_type.wireValue}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: item.image == null
                            ? null
                            : CachedNetworkImageProvider(item.image!),
                        child: item.image == null
                            ? const Icon(AppIcons.favorite)
                            : null,
                      ),
                      title: Text(item.name),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(item.subtitle!),
                      trailing: const Icon(AppIcons.chevronRight),
                      onTap: () => _open(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, FavoriteTarget item) {
    final id = item.slug ?? item.id;
    final route = switch (_type) {
      FavoriteType.venue => AppRoutes.venueDetail(id),
      FavoriteType.club => AppRoutes.clubDetail(id),
      FavoriteType.session => AppRoutes.sessionDetail(id),
      FavoriteType.tournament => AppRoutes.tournamentDetail(id),
    };
    unawaited(context.push(route));
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
