import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Multi-selects the skill levels accepted by a session or club.
///
/// An empty [selectedLevels] means all levels are welcome. Values emitted by
/// [onChanged] always follow the display rank (`Yếu-`, `Yếu`, `Yếu+`, …), not
/// their stable numeric identifiers.
class LevelBadgePicker extends StatelessWidget {
  const LevelBadgePicker({
    required this.selectedLevels,
    required this.allLevelsLabel,
    required this.onChanged,
    this.allLevelsKey,
    this.levelKeyPrefix = 'level',
    super.key,
  });

  final List<int> selectedLevels;
  final String allLevelsLabel;
  final ValueChanged<List<int>> onChanged;
  final Key? allLevelsKey;
  final String levelKeyPrefix;

  void _toggle(int level) {
    final next = [...selectedLevels];
    if (!next.remove(level)) next.add(level);
    onChanged(sortByRank(next));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AllLevelsBadge(
          label: allLevelsLabel,
          selected: selectedLevels.isEmpty,
          tapKey: allLevelsKey,
          onTap: () => onChanged(const []),
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: levelDefinitions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 2,
            mainAxisExtent: AppSizes.minTapTarget,
          ),
          itemBuilder: (context, index) {
            final definition = levelDefinitions[index];
            return _LevelBadge(
              definition: definition,
              selected: selectedLevels.contains(definition.id),
              keyPrefix: levelKeyPrefix,
              onTap: () => _toggle(definition.id),
            );
          },
        ),
      ],
    );
  }
}

class _AllLevelsBadge extends StatelessWidget {
  const _AllLevelsBadge({
    required this.label,
    required this.selected,
    this.tapKey,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Key? tapKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.success;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tapKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Center(
            child: Container(
              key: const ValueKey('all-levels-badge'),
              height: 36,
              width: double.infinity,
              decoration: BoxDecoration(
                color: selected ? color : null,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(AppIcons.check, size: 18, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.definition,
    required this.selected,
    required this.keyPrefix,
    required this.onTap,
  });

  final LevelDefinition definition;
  final bool selected;
  final String keyPrefix;
  final VoidCallback onTap;

  Color _color(ThemeData theme) {
    if (definition.rank <= 3) return AppColors.success;
    if (definition.rank <= 6) return AppColors.warning;
    return theme.colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme);
    final foreground = definition.rank >= 4 && definition.rank <= 6
        ? Colors.black87
        : definition.rank <= 3
        ? Colors.white
        : theme.colorScheme.onError;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('$keyPrefix-${definition.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Center(
            child: Container(
              key: ValueKey('$keyPrefix-${definition.id}-badge'),
              height: 34,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? color : null,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(AppIcons.check, size: 13, color: foreground),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      definition.shortLabel,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected ? foreground : color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
