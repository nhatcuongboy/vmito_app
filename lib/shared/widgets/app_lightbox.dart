import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Full-screen image viewer, ported from the web app's `AppLightbox`.
///
/// Pinch-to-zoom comes from [InteractiveViewer] rather than a package: the
/// only behaviour needed here is pan and scale on a single image, which it
/// already does.
Future<void> showAppLightbox(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      // The photo should feel lifted off the page, not navigated to.
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) =>
          _Lightbox(images: images, initialIndex: initialIndex),
    ),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.contain,
                  placeholder: (context, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, _, _) => const Icon(
                    AppIcons.imageOff,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
            left: AppSpacing.sm,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(AppIcons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.md,
              right: AppSpacing.lg,
              child: Text(
                '${_index + 1}/${widget.images.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
