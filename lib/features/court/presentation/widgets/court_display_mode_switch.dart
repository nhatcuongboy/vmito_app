import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/court_display_mode_controller.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Number ↔ name toggle for the court board. Ports `CourtDisplayModeSwitch`.
class CourtDisplayModeSwitch extends ConsumerWidget {
  const CourtDisplayModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(courtDisplayModeControllerProvider);
    final controller = ref.read(courtDisplayModeControllerProvider.notifier);

    return SegmentedButton<CourtDisplayMode>(
      segments: [
        ButtonSegment(
          value: CourtDisplayMode.number,
          icon: const Icon(AppIcons.tag, size: 16),
          label: Text(l10n.courtDisplayModeNumber),
        ),
        ButtonSegment(
          value: CourtDisplayMode.name,
          icon: const Icon(AppIcons.badge, size: 16),
          label: Text(l10n.courtDisplayModeName),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => controller.select(selection.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    );
  }
}
