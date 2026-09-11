import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';

/// Cover-image carousel for a session overview tab: swipeable, with a page
/// indicator and a share button, tapping an image opens the lightbox.
class SessionGallery extends StatefulWidget {
  const SessionGallery({
    required this.images,
    required this.onShare,
    super.key,
  });

  final List<String> images;
  final VoidCallback onShare;

  @override
  State<SessionGallery> createState() => _SessionGalleryState();
}

class _SessionGalleryState extends State<SessionGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant SessionGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index < widget.images.length) return;
    _index = widget.images.isEmpty ? 0 : widget.images.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(_index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Mở ảnh kèo',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.images.length == 1)
              _GalleryImage(
                imageUrl: widget.images.single,
                images: widget.images,
                index: 0,
              )
            else
              PageView.builder(
                key: const Key('host-overview-gallery'),
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _GalleryImage(
                  imageUrl: widget.images[index],
                  images: widget.images,
                  index: index,
                ),
              ),
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm + 2,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < widget.images.length; index++)
                        AnimatedContainer(
                          key: ValueKey('host-gallery-dot-$index'),
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: index == _index ? 1 : 0.6,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.pill,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 2,
                                offset: Offset(0, 1),
                                color: Color(0x4D000000),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(AppIcons.share, size: 16, color: Colors.white),
                onPressed: widget.onShare,
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  minimumSize: const Size.square(30),
                  maximumSize: const Size.square(30),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({
    required this.imageUrl,
    required this.images,
    required this.index,
  });

  final String imageUrl;
  final List<String> images;
  final int index;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('host-overview-cover-$index'),
    onTap: () => unawaited(
      showAppLightbox(context, images: images, initialIndex: index),
    ),
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFE5E7EB)),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Icon(AppIcons.imageOff),
      ),
    ),
  );
}
