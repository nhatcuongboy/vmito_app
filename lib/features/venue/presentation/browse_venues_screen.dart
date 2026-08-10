import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

class BrowseVenuesScreen extends ConsumerStatefulWidget {
  const BrowseVenuesScreen({
    this.embedded = false,
    this.discoveryHeader,
    super.key,
  });

  /// Omits this feature's Scaffold/AppBar when it is hosted by Home's
  /// discovery switcher.
  final bool embedded;
  final Widget? discoveryHeader;

  @override
  ConsumerState<BrowseVenuesScreen> createState() => _BrowseVenuesScreenState();
}

class _BrowseVenuesScreenState extends ConsumerState<BrowseVenuesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    Future<void>.microtask(
      () => ref.read(venueBrowseControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 380) {
      unawaited(ref.read(venueBrowseControllerProvider.notifier).loadMore());
    }
  }

  Future<void> _nearMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Bạn chưa cấp quyền vị trí.');
      }
      final position = await Geolocator.getCurrentPosition();
      final filter = ref
          .read(venueBrowseControllerProvider)
          .filter
          .copyWith(
            sortBy: 'distance',
            latitude: position.latitude,
            longitude: position.longitude,
          );
      await ref
          .read(venueBrowseControllerProvider.notifier)
          .load(filter: filter);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(venueBrowseControllerProvider);
    final body = RefreshIndicator(
      onRefresh: () => ref.read(venueBrowseControllerProvider.notifier).load(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _body(state),
        ),
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sân'),
        actions: [
          IconButton(
            onPressed: _createRequest,
            icon: const Icon(AppIcons.addLocation),
            tooltip: 'Đề xuất thêm sân',
          ),
          IconButton(
            onPressed: _nearMe,
            icon: const Icon(AppIcons.myLocation),
            tooltip: 'Gần tôi',
          ),
          IconButton(
            onPressed: () => _openFilters(state.filter),
            icon: const Icon(AppIcons.tune),
            tooltip: 'Lọc',
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _createRequest() async {
    final draft = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateVenueSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(venueServiceProvider)
          .createRequest(
            type: 'CREATE',
            payload: draft,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đề xuất thêm sân.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Widget _body(VenueBrowseState state) {
    final discoveryHeader = widget.discoveryHeader;
    final headerCount = discoveryHeader == null ? 0 : 1;
    final footerIndex = state.venues.length + headerCount + 1;

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: state.venues.length + headerCount + 2,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SearchBar(
            controller: _search,
            hintText: 'Tìm sân, địa chỉ',
            leading: const Icon(AppIcons.search),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 400),
                () => ref
                    .read(venueBrowseControllerProvider.notifier)
                    .load(
                      filter: state.filter.copyWith(
                        keyword: value,
                        sortBy: value.isEmpty
                            ? state.filter.sortBy
                            : 'relevance',
                      ),
                    ),
              );
            },
          );
        }
        if (index == 1 && discoveryHeader != null) {
          return discoveryHeader;
        }
        if (index == footerIndex) {
          if (state.isLoading && state.venues.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.error != null && state.venues.isEmpty) {
            return AppErrorView(
              error: state.error!,
              onRetry: () =>
                  ref.read(venueBrowseControllerProvider.notifier).load(),
            );
          }
          if (state.venues.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Không tìm thấy sân phù hợp.')),
            );
          }
          return state.isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: 8);
        }
        return VenueCard(
          venue: state.venues[index - headerCount - 1],
        );
      },
    );
  }

  Future<void> _openFilters(VenueFilter filter) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var selectedSort = filter.sortBy;
      final city = TextEditingController(text: filter.city);
      final district = TextEditingController(text: filter.district);
      var favorite = filter.favoriteOnly;
      return StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lọc và sắp xếp',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(
                    labelText: 'Tỉnh / Thành phố',
                  ),
                ),
                TextField(
                  controller: district,
                  decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedSort,
                  decoration: const InputDecoration(labelText: 'Sắp xếp'),
                  items: const [
                    DropdownMenuItem(
                      value: 'distance',
                      child: Text('Gần nhất'),
                    ),
                    DropdownMenuItem(
                      value: 'relevance',
                      child: Text('Phù hợp nhất'),
                    ),
                    DropdownMenuItem(
                      value: 'createdAt',
                      child: Text('Mới nhất'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Tên A–Z')),
                    DropdownMenuItem(
                      value: 'hourlyRateFixed',
                      child: Text('Giá thấp nhất'),
                    ),
                    DropdownMenuItem(
                      value: 'numberOfCourts',
                      child: Text('Nhiều sân nhất'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => selectedSort = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: favorite,
                  onChanged: (value) => setSheetState(() => favorite = value),
                  title: const Text('Chỉ sân yêu thích'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ref
                          .read(venueBrowseControllerProvider.notifier)
                          .load(
                            filter: filter.copyWith(
                              city: city.text.trim(),
                              district: district.text.trim(),
                              sortBy: selectedSort,
                              favoriteOnly: favorite,
                            ),
                          );
                    },
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class VenueCard extends StatelessWidget {
  const VenueCard({required this.venue, super.key});
  final Venue venue;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(AppRoutes.venueDetail(venue.slug ?? venue.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 144,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (venue.coverPhoto != null)
                  CachedNetworkImage(
                    imageUrl: venue.coverPhoto!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const _VenueCover(),
                  )
                else
                  const _VenueCover(),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FavoriteButton(
                    type: FavoriteType.venue,
                    targetId: venue.id,
                    onSignInRequired: () => context.push(AppRoutes.signIn),
                  ),
                ),
                if (venue.distance != null)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _badge(
                      AppIcons.navigation,
                      '${venue.distance!.toStringAsFixed(1)} km',
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: venue.logo == null
                      ? null
                      : CachedNetworkImageProvider(venue.logo!),
                  child: venue.logo == null
                      ? const Icon(AppIcons.location)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (venue.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                AppIcons.verified,
                                color: Colors.green,
                                size: 19,
                              ),
                            ),
                        ],
                      ),
                      if (venue.addressLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            venue.addressLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 10,
                        children: [
                          if (venue.numberOfCourts != null)
                            Text(
                              '${venue.numberOfCourts} sân',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          if (venue.hourlyRateFixed != null)
                            Text(
                              '${_money(venue.hourlyRateFixed!)}đ/giờ',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  static Widget _badge(IconData icon, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VenueCover extends StatelessWidget {
  const _VenueCover();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Icon(AppIcons.sessions, size: 48),
  );
}

class _CreateVenueSheet extends StatefulWidget {
  const _CreateVenueSheet();
  @override
  State<_CreateVenueSheet> createState() => _CreateVenueSheetState();
}

class _CreateVenueSheetState extends State<_CreateVenueSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _ward = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _street.dispose();
    _city.dispose();
    _ward.dispose();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Đề xuất thêm sân',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sân'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập tên sân' : null,
            ),
            TextFormField(
              controller: _street,
              decoration: const InputDecoration(labelText: 'Số nhà, tên đường'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập địa chỉ' : null,
            ),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Tỉnh / thành phố'),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Nhập tỉnh / thành phố'
                  : null,
            ),
            TextFormField(
              controller: _ward,
              decoration: const InputDecoration(labelText: 'Phường / xã'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nhập phường / xã' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, {
                      'name': _name.text.trim(),
                      'street': _street.text.trim(),
                      'address': _street.text.trim(),
                      'newCity': _city.text.trim(),
                      'newDistrict': _ward.text.trim(),
                    });
                  }
                },
                child: const Text('Gửi đề xuất'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _money(int value) {
  final raw = value.toString();
  return raw.replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => '.');
}
