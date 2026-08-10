import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

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

class _VenueDetailState extends ConsumerState<_VenueDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.venue.images.isEmpty ? 1 : 2,
    vsync: this,
  );
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(venue: venue)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: _title(venue),
            ),
          ),
          if (venue.images.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeader(
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Giới thiệu'),
                    Tab(text: 'Ảnh'),
                  ],
                ),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: venue.images.isEmpty
                ? _about(venue)
                : TabBarView(
                    controller: _tabs,
                    children: [_about(venue), _photos(venue)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _title(Venue venue) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 27,
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
                Text(
                  venue.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (venue.addressLabel.isNotEmpty)
                  Text(
                    venue.addressLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          if (venue.isVerified)
            const Icon(AppIcons.verified, color: Colors.green),
        ],
      ),
      if (venue.closureStatus != 'OPERATING')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Chip(
            avatar: const Icon(AppIcons.warning),
            label: Text(
              venue.closureStatus == 'PERMANENTLY_CLOSED'
                  ? 'Đã đóng cửa'
                  : 'Tạm ngưng hoạt động',
            ),
          ),
        ),
    ],
  );
  Widget _about(Venue venue) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      0,
      AppSpacing.screenPadding,
      32,
    ),
    children: [
      _section(
        'Giới thiệu',
        Text(
          _plainText(venue.description) == ''
              ? 'Chưa có mô tả.'
              : _plainText(venue.description),
        ),
      ),
      if (venue.courtLayoutImage != null)
        _section(
          'Sơ đồ sân',
          GestureDetector(
            onTap: () => unawaited(
              showAppLightbox(context, images: [venue.courtLayoutImage!]),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: CachedNetworkImage(
                imageUrl: venue.courtLayoutImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      _Pricing(venueId: venue.id),
      if (venue.amenities.isNotEmpty)
        _section(
          'Tiện ích',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: venue.amenities
                .map((item) => Chip(label: Text(item)))
                .toList(),
          ),
        ),
      _section(
        'Thông tin liên hệ',
        Column(
          children: [
            if (venue.openingHours?.isNotEmpty ?? false)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.clock),
                title: const Text('Giờ mở cửa'),
                subtitle: Text(venue.openingHours!),
              ),
            if (venue.phone?.isNotEmpty ?? false)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.phone),
                title: Text(venue.phone!),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: venue.phone)),
              ),
            if (venue.website?.isNotEmpty ?? false)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.language),
                title: Text(venue.website!),
                onTap: () => launchUrl(
                  Uri.parse(venue.website!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.navigation),
              title: const Text('Chỉ đường'),
              onTap: () => _directions(venue),
            ),
          ],
        ),
      ),
      _section(
        'Cập nhật thông tin',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () => _request('UPDATE', venue),
              icon: const Icon(AppIcons.edit),
              label: const Text('Báo chỉnh sửa thông tin'),
            ),
            OutlinedButton.icon(
              onPressed: () => _imageRequest('PRICE_CORRECTION', venue),
              icon: const Icon(AppIcons.priceTag),
              label: const Text('Gửi ảnh bảng giá'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _imageRequest('IMAGE_CORRECTION', venue, multiple: true),
              icon: const Icon(AppIcons.imagePlus),
              label: const Text('Gửi ảnh sân'),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _photos(Venue venue) => GridView.builder(
    padding: const EdgeInsets.all(AppSpacing.screenPadding),
    itemCount: venue.images.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemBuilder: (_, index) => InkWell(
      onTap: () => unawaited(
        showAppLightbox(context, images: venue.images, initialIndex: index),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: CachedNetworkImage(
          imageUrl: venue.images[index],
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
  Widget _section(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
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
        _message('Đã gửi yêu cầu.');
      } on Object catch (error) {
        _message(error.toString());
      }
    }
  }

  Future<void> _imageRequest(
    String type,
    Venue venue, {
    bool multiple = false,
  }) async {
    final picker = ImagePicker();
    final files = multiple
        ? await picker.pickMultiImage(limit: 10)
        : [
            ?await picker.pickImage(source: ImageSource.gallery),
          ];
    if (files.isEmpty) return;
    try {
      final uploads = await Future.wait(
        files.map(
          (file) => ref.read(venueServiceProvider).uploadImage(file.path),
        ),
      );
      await ref
          .read(venueServiceProvider)
          .createRequest(
            type: type,
            venueId: venue.id,
            payload: type == 'PRICE_CORRECTION'
                ? {
                    'priceImageUrl': uploads.first.url,
                    if (uploads.first.publicId != null)
                      'priceImagePublicId': uploads.first.publicId,
                  }
                : {
                    'suggestedImages': [
                      for (final upload in uploads)
                        {
                          'url': upload.url,
                          if (upload.publicId != null)
                            'publicId': upload.publicId,
                        },
                    ],
                  },
          );
      _message('Đã gửi yêu cầu.');
    } on Object catch (error) {
      _message(error.toString());
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _Hero extends StatelessWidget {
  const _Hero({required this.venue});
  final Venue venue;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 260 + MediaQuery.paddingOf(context).top,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (venue.coverPhoto != null)
          GestureDetector(
            onTap: () =>
                unawaited(showAppLightbox(context, images: venue.gallery)),
            child: CachedNetworkImage(
              imageUrl: venue.coverPhoto!,
              fit: BoxFit.cover,
            ),
          )
        else
          ColoredBox(color: Theme.of(context).colorScheme.primaryContainer),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black54],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          child: IconButton.filledTonal(
            onPressed: () => context.pop(),
            icon: const Icon(AppIcons.arrowBack),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 8,
          child: Row(
            children: [
              FavoriteButton(
                type: FavoriteType.venue,
                targetId: venue.id,
                onSignInRequired: () => context.push(AppRoutes.signIn),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: 'https://vmito.com/venues/${venue.slug ?? venue.id}',
                  ),
                ),
                icon: const Icon(AppIcons.share),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Pricing extends ConsumerWidget {
  const _Pricing({required this.venueId});
  final String venueId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(venuePriceBooksProvider(venueId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: books.when(
          data: (data) {
            final book = _activeBook(data);
            if (book == null || book.rules.isEmpty) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bảng giá',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 10),
                  Text('Chưa có bảng giá.'),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bảng giá',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                ...book.rules.map(
                  (rule) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_day(rule)} · ${_time(rule.startMinute)} – ${_time(rule.endMinute)}',
                    ),
                    trailing: Text(
                      '${_money(rule.pricePerHour)}đ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      rule.customerType == 'FIXED'
                          ? 'Khách cố định'
                          : 'Khách vãng lai',
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Không thể tải bảng giá.'),
        ),
      ),
    );
  }
}

VenuePriceBook? _activeBook(List<VenuePriceBook> values) {
  final active =
      values
          .where(
            (book) =>
                book.isActive &&
                !(book.notes?.trimLeft().startsWith('Tự động tạo từ') ?? false),
          )
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
  return active.isEmpty ? null : active.first;
}

String _day(VenuePriceRule rule) => switch (rule.dayType) {
  'EVERYDAY' => 'Mỗi ngày',
  'WEEKEND' => 'Cuối tuần',
  'WEEKDAY' => 'Ngày thường',
  _ => 'Theo lịch',
};
String _time(int minutes) =>
    '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : (minutes % 60).toString().padLeft(2, '0')}';
String _money(int value) => value.toString().replaceAllMapped(
  RegExp(r'(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

class _TabHeader extends SliverPersistentHeaderDelegate {
  const _TabHeader(this.tabs);
  final TabBar tabs;
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: Theme.of(context).scaffoldBackgroundColor, child: tabs);
  @override
  bool shouldRebuild(_TabHeader oldDelegate) => false;
}

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
                decoration: const InputDecoration(labelText: 'Tên sân'),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Nhập tên sân' : null,
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
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

String _plainText(String? html) => (html ?? '')
    .replaceAll(RegExp('<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
