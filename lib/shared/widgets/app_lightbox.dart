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
  WidgetBuilder? footerBuilder,
}) {
  if (images.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      // The photo should feel lifted off the page, not navigated to.
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) => _Lightbox(
        images: images,
        initialIndex: initialIndex,
        footerBuilder: footerBuilder,
      ),
    ),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({
    required this.images,
    required this.initialIndex,
    this.footerBuilder,
  });

  final List<String> images;
  final int initialIndex;

  /// Optional overlay pinned to the bottom (e.g. a post's author, caption and
  /// actions). Hidden together with the other chrome when the photo is tapped.
  final WidgetBuilder? footerBuilder;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _showChrome = true;

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
            itemBuilder: (context, index) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showChrome = !_showChrome),
              child: InteractiveViewer(
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
          ),
          ..._chrome(context, theme),
        ],
      ),
    );
  }

  List<Widget> _chrome(BuildContext context, ThemeData theme) {
    Widget fade(Widget child) => IgnorePointer(
      ignoring: !_showChrome,
      child: AnimatedOpacity(
        opacity: _showChrome ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    );
    final hasMany = widget.images.length > 1;
    final footerBuilder = widget.footerBuilder;

    return [
      Positioned(
        top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
        right: AppSpacing.sm,
        child: fade(
          IconButton(
            key: const Key('lightbox-close-button'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(AppIcons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
      if (hasMany)
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppSpacing.md,
          right: AppSpacing.xl + AppSpacing.lg,
          child: fade(
            Text(
              '${_index + 1}/${widget.images.length}',
              style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
        ),
      if (hasMany) ...[
        Positioned(
          left: AppSpacing.sm,
          top: 0,
          bottom: 0,
          child: Center(
            child: fade(
              IconButton(
                key: const Key('lightbox-previous-button'),
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(AppIcons.chevronLeft),
                color: Colors.white,
                onPressed: _index == 0 ? null : () => _showPage(_index - 1),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  disabledForegroundColor: Colors.white38,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.sm,
          top: 0,
          bottom: 0,
          child: Center(
            child: fade(
              IconButton(
                key: const Key('lightbox-next-button'),
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(AppIcons.chevronRight),
                color: Colors.white,
                onPressed: _index == widget.images.length - 1
                    ? null
                    : () => _showPage(_index + 1),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  disabledForegroundColor: Colors.white38,
                ),
              ),
            ),
          ),
        ),
      ],
      if (footerBuilder != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: fade(Builder(builder: footerBuilder)),
        ),
    ];
  }

  void _showPage(int index) {
    _controller.jumpToPage(index);
  }
}
