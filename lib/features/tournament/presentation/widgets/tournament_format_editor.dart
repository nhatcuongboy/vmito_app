import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/tournament/application/tournament_categories_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_structure_refresh.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_format_config.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_elimination_section.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_labels.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_format_round_robin_section.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_resource_frames.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Replaces the web `FormatWizardModal`: its select and configure steps
/// become one scrolling screen, with the playoffs step as a section.
class TournamentFormatEditor extends ConsumerStatefulWidget {
  const TournamentFormatEditor({
    required this.tournamentId,
    required this.idOrSlug,
    required this.category,
    super.key,
  });

  final String tournamentId;
  final String idOrSlug;
  final TournamentCategory category;

  @override
  ConsumerState<TournamentFormatEditor> createState() =>
      _TournamentFormatEditorState();
}

class _TournamentFormatEditorState
    extends ConsumerState<TournamentFormatEditor> {
  // The frame is built around a form; every field here is plain state.
  final FormGroup _form = FormGroup({});
  late final Map<String, dynamic> _original = TournamentFormatConfig.initial(
    widget.category,
  );
  late TournamentCategoryFormat _format = widget.category.format;
  late Map<String, dynamic> _config = _copy(_original);

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tournamentCategoriesProvider(widget.tournamentId));
    return TournamentEditorFrame(
      title: l10n.tournamentManageFormat,
      form: _form,
      busy: state.busy,
      error: state.error,
      onSave: _submit,
      children: [
        Text(
          l10n.tournamentFormatSelectTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Column(
          children: [
            for (final format in TournamentCategoryFormat.values)
              _FormatOption(
                format: format,
                selected: format == _format,
                onTap: () => _selectFormat(format),
              ),
          ],
        ),
        if (TournamentFormatConfig.hasRoundRobin(_format))
          TournamentFormatRoundRobinSection(
            key: ValueKey('rr-$_format'),
            values: TournamentFormatConfig.roundRobinOf(_format, _config),
            onChanged: (key, value) => _set(
              TournamentFormatConfig.roundRobinOf(_format, _config),
              key,
              value,
            ),
          ),
        if (_format != TournamentCategoryFormat.roundRobin)
          TournamentFormatEliminationSection(
            key: ValueKey('elimination-$_format'),
            format: _format,
            values: _config,
            onChanged: (key, value) => _set(_config, key, value),
          ),
      ],
    );
  }

  /// Picking another format starts from its defaults, as the web wizard does;
  /// returning to the saved format restores the saved config.
  void _selectFormat(TournamentCategoryFormat format) => setState(() {
    if (format == _format) return;
    _format = format;
    _config = format == widget.category.format
        ? _copy(_original)
        : TournamentFormatConfig.defaults(format);
  });

  void _set(Map<String, dynamic> target, String key, Object? value) =>
      setState(() {
        if (value == null) {
          target.remove(key);
        } else {
          target[key] = value;
        }
      });

  Future<void> _submit() async {
    final unchanged =
        _format == widget.category.format &&
        jsonEncode(_config) == jsonEncode(_original);
    final saved =
        unchanged ||
        await ref
            .read(tournamentCategoriesProvider(widget.tournamentId).notifier)
            .update(
              widget.category.id,
              TournamentFormatConfig.updatePayload(
                _format,
                _config,
                widget.category,
              ),
            );
    if (!saved || !mounted) return;
    if (!unchanged) refreshTournamentStructure(ref, widget.idOrSlug);
    Navigator.pop(context);
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final TournamentCategoryFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (name, description) = tournamentFormatCopy(
      AppLocalizations.of(context),
      format,
    );
    final colors = Theme.of(context).colorScheme;
    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.primary, width: 2),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        trailing: selected
            ? Icon(AppIcons.checkCircle, color: colors.primary)
            : null,
      ),
    );
  }
}
