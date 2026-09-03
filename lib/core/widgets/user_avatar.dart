import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A consistent account avatar with a cached image and a name-based fallback.
///
/// The visual treatment mirrors the web app's shared `UserAvatar`: the
/// fallback uses the first and last initials, its gradient is based on the
/// user's gender where available, and an optional status dot can be shown.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.name,
    this.gender,
    this.status,
    this.imageUrl,
    this.size = 48,
    this.fontSize,
    this.borderWidth,
    this.borderColor,
    this.boxShadow,
    this.showStatusDot,
    this.statusColor,
  });

  final String? name;
  final String? gender;
  final String? status;
  final String? imageUrl;
  final double size;
  final double? fontSize;
  final double? borderWidth;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final bool? showStatusDot;
  final Color? statusColor;

  String _initialsFor(double avatarSize) {
    final parts =
        name
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        const <String>[];
    if (parts.isEmpty) return '?';

    // For very small avatars, a single initial reads better.
    final maxCount = avatarSize < 32 ? 1 : 2;

    final selected = parts.length <= maxCount
        ? parts
        : [parts.first, parts.last];
    final initials = selected
        .map((part) => part.characters.firstOrNull ?? '')
        .where((initial) => initial.isNotEmpty)
        .join()
        .toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  bool get _hasImage => imageUrl?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedBorderWidth = borderWidth ?? _borderWidthFor(size);
    final resolvedBorderColor = borderColor ?? scheme.surface;
    final shouldShowStatus = showStatusDot ?? status != null;

    return Semantics(
      image: true,
      label: name?.trim().isNotEmpty ?? false ? name!.trim() : 'User avatar',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: boxShadow ?? const [],
              ),
              foregroundDecoration: resolvedBorderWidth > 0
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: resolvedBorderColor,
                        width: resolvedBorderWidth,
                      ),
                    )
                  : null,
              child: ClipOval(
                child: _hasImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!.trim(),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _fallback(context),
                        errorWidget: (_, _, _) => _fallback(context),
                      )
                    : _fallback(context),
              ),
            ),
            if (shouldShowStatus && status != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  key: const Key('user-avatar-status-dot'),
                  width: _statusDotSizeFor(size),
                  height: _statusDotSizeFor(size),
                  decoration: BoxDecoration(
                    color: statusColor ?? _statusColor(scheme),
                    shape: BoxShape.circle,
                    border: Border.all(color: resolvedBorderColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _gradientFor(scheme),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initialsFor(size),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize ?? _fontSizeFor(size),
            fontWeight: FontWeight.bold,
            letterSpacing: .5,
            height: 1,
          ),
        ),
      ),
    );
  }

  LinearGradient _gradientFor(ColorScheme scheme) =>
      switch (gender?.toUpperCase()) {
        'MALE' => const LinearGradient(
          colors: [Color(0xFF4299E1), Color(0xFF667EEA)],
        ),
        'FEMALE' => const LinearGradient(
          colors: [Color(0xFFED64A6), Color(0xFFF687B3)],
        ),
        'OTHER' => const LinearGradient(
          colors: [Color(0xFF9F7AEA), Color(0xFFB794F4)],
        ),
        _ => LinearGradient(colors: [scheme.primary, scheme.primaryContainer]),
      };

  Color _statusColor(ColorScheme scheme) => switch (status?.toUpperCase()) {
    'PLAYING' => Colors.green,
    'WAITING' => Colors.orange,
    'READY' => scheme.primary,
    _ => Colors.grey,
  };

  static double _fontSizeFor(double size) => (size * 0.38).clamp(10, 32);

  static double _borderWidthFor(double size) => size <= 36
      ? 1.5
      : size <= 56
      ? 2
      : size <= 80
      ? 3
      : 4;

  static double _statusDotSizeFor(double size) => size >= 56
      ? 16
      : size >= 44
      ? 14
      : 10;
}
