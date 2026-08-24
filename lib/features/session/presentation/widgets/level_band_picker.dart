import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Picks which skill levels a session accepts.
///
/// Chips are laid out in **display order** (`Yếu- Yếu Yếu+ TBY TB- …`), which
/// is not numeric id order — 9 and 10 are the beginner half-steps and bracket
/// 1. Ordering these by id would present the scale wrong to the one person who
/// most needs it right: the host setting it.
///
/// Selecting nothing means **all levels welcome**, and that is stated rather
/// than left as an empty row a host might read as a broken control.
class LevelBandPicker extends StatelessWidget {
  const LevelBandPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  void _toggle(int level) {
    final next = [...selected];
    if (!next.remove(level)) next.add(level);
    // Kept in display order so the value handed to the API, and any range
    // rendered from it later, is already correct.
    onChanged(sortByRank(next));
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: levelDefinitions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 2,
        mainAxisExtent: 48,
      ),
      itemBuilder: (context, index) {
        final definition = levelDefinitions[index];
        return _LevelOption(
          definition: definition,
          selected: selected.contains(definition.id),
          onTap: () => _toggle(definition.id),
        );
      },
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final LevelDefinition definition;
  final bool selected;
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

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('level-${definition.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Container(
              height: 34,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: .14) : null,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 13, color: color),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      definition.shortLabel,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
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
