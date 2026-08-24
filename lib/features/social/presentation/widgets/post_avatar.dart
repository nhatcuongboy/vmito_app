import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 10 curated gradient rings — Instagram-style, matching `PostAvatar.tsx`.
const _kRingGradients = <List<Color>>[
  [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ],
  [Color(0xFF12C2E9), Color(0xFFC471ED), Color(0xFFF64F59)],
  [Color(0xFFF7971E), Color(0xFFFFD200), Color(0xFFF7971E)],
  [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF00C6FF)],
  [Color(0xFFF857A6), Color(0xFFFF5858), Color(0xFFF857A6)],
  [Color(0xFF43E97B), Color(0xFF38F9D7), Color(0xFF43E97B)],
  [Color(0xFFFA709A), Color(0xFFFEE140), Color(0xFFFA709A)],
  [Color(0xFF30CFD0), Color(0xFF330867), Color(0xFF30CFD0)],
  [Color(0xFFFF6A00), Color(0xFFEE0979), Color(0xFFFF6A00)],
  [Color(0xFF7F00FF), Color(0xFFE100FF), Color(0xFF7F00FF)],
];

/// Stable hash so the same name always gets the same ring colour.
int _hashName(String value) {
  var hash = 0;
  for (var i = 0; i < value.length; i++) {
    // Matches the JS: hash = (hash << 5) - hash + charCode, then |= 0
    hash = ((hash << 5) - hash + value.codeUnitAt(i)) & 0x7FFFFFFF;
  }
  return hash;
}

/// Avatar widget shared across the newsfeed, mirroring `PostAvatar.tsx`.
///
/// Shows the user's network image or a green initial-letter fallback.
/// Set [bordered] to `true` to wrap the avatar in a conic-gradient ring.
class PostAvatar extends StatelessWidget {
  const PostAvatar({
    required this.name,
    super.key,
    this.imageUrl,
    this.size = 44,
    this.bordered = false,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// When `true`, wraps the avatar in an Instagram-style gradient ring.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circle = _AvatarCircle(
      name: name,
      imageUrl: imageUrl,
      size: size,
      isDark: isDark,
    );

    if (!bordered) return circle;

    // Ring metrics — matches the web's `Math.max(2, Math.round(size * 0.06))`.
    final ringWidth = (size * 0.06).clamp(2.0, 5.0);
    const gapWidth = 1.5;
    final colors =
        _kRingGradients[_hashName(name.isEmpty ? '?' : name) %
            _kRingGradients.length];
    final outerSize = size + (ringWidth + gapWidth) * 2;

    return SizedBox.square(
      dimension: outerSize,
      child: CustomPaint(
        painter: _RingPainter(colors: colors, ringWidth: ringWidth),
        child: Center(
          child: Container(
            width: size + gapWidth * 2,
            height: size + gapWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // White/dark gap between the ring and the avatar.
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
            ),
            child: Center(child: circle),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.name,
    required this.size,
    required this.isDark,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fontSize = (size * 0.4).clamp(11.0, 28.0);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF4B5563), Color(0xFF374151)]
              : const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
        ),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _InitialFallback(
                initial: initial,
                fontSize: fontSize,
                isDark: isDark,
              ),
            )
          : _InitialFallback(
              initial: initial,
              fontSize: fontSize,
              isDark: isDark,
            ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  const _InitialFallback({
    required this.initial,
    required this.fontSize,
    required this.isDark,
  });

  final String initial;
  final double fontSize;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initial,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF15803D),
      ),
    ),
  );
}

/// Paints a sweep-gradient ring (conic-gradient equivalent).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.colors, required this.ringWidth});

  final List<Color> colors;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.colors != colors || old.ringWidth != ringWidth;
}
