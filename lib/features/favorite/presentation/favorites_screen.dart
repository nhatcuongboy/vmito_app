import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  var _type = 'SESSION';
  late Future<List<FavoriteTarget>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FavoriteTarget>> _load() async =>
      (await ref.read(profileTabsServiceProvider).favorites(_type)).items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.menuOpenTooltip,
          icon: const Icon(AppIcons.menu),
          onPressed: () =>
              ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(l10n.navFavorites),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'SESSION',
                  label: Text(l10n.favoritesSessions),
                ),
                ButtonSegment(
                  value: 'VENUE',
                  label: Text(l10n.favoritesVenues),
                ),
                ButtonSegment(value: 'CLUB', label: Text(l10n.favoritesClubs)),
                ButtonSegment(
                  value: 'TOURNAMENT',
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
                  key: PageStorageKey('favorites-$_type'),
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
    if (_type == 'VENUE') {
      unawaited(context.push(AppRoutes.venueDetail(id)));
    } else if (_type == 'CLUB') {
      unawaited(context.push(AppRoutes.clubDetail(id)));
    } else if (_type == 'SESSION') {
      unawaited(context.push(AppRoutes.sessionDetail(id)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).favoritesTournamentUnavailable,
          ),
        ),
      );
    }
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
