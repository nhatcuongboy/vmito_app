import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';

/// The "Tạo giải" action, styled like the "Bản đồ" toggle on the sessions and
/// venues discovery lists: a pill FAB in the brand-tinted surface rather than
/// a solid primary FAB, that shrinks to icon-only while scrolling.
class HostTournamentsCreateFab extends StatelessWidget {
  const HostTournamentsCreateFab({
    required this.isExtended,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool isExtended;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>();
    final backgroundColor =
        palette?.brandSurface ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF183028)
            : const Color(0xFFE2F3E8));
    return SizedBox(
      height: 44,
      child: FloatingActionButton.extended(
        key: const Key('host-tournaments-create-fab'),
        heroTag: 'host-tournaments-create-fab',
        isExtended: isExtended,
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        foregroundColor: theme.colorScheme.primary,
        elevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 13),
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        icon: const Icon(AppIcons.add, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
