import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/registration/domain/registration_player_draft.dart';
import 'package:vmito_app/features/registration/presentation/registration_player_card.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/skill_level_badge.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// The web app's `JoinSessionModal`, as a bottom sheet.
///
/// [asGuest] mirrors `isAdditionalRegistration`: the sheet opens with a single
/// empty guest row instead of a prefilled "me" row. Everything else — fields,
/// validation, endpoint — is identical.
Future<bool?> showRegisterSessionSheet(
  BuildContext context, {
  required Session session,
  bool asGuest = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _RegisterSessionSheet(
      session: session,
      asGuest: asGuest,
    ),
  );
}

class _RegisterSessionSheet extends ConsumerStatefulWidget {
  const _RegisterSessionSheet({required this.session, required this.asGuest});

  final Session session;
  final bool asGuest;

  @override
  ConsumerState<_RegisterSessionSheet> createState() =>
      _RegisterSessionSheetState();
}

class _RegisterSessionSheetState extends ConsumerState<_RegisterSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  late List<RegistrationPlayerDraft> _drafts;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Read once, in initState: the drafts are local state from here on, so a
    // socket-driven refresh of the session cannot wipe what the user typed.
    final user = ref.read(currentUserProvider);
    _drafts = [
      if (widget.asGuest)
        RegistrationPlayerDraft(isMe: false, level: _defaultLevel)
      else
        RegistrationPlayerDraft(
          isMe: true,
          name: user?.name ?? '',
          phone: user?.phone ?? '',
          level: _defaultLevel,
        ),
    ];
  }

  /// The session's first accepted level, or none when it accepts everyone —
  /// in which case the player must choose explicitly.
  int? get _defaultLevel {
    final required = widget.session.requiredLevels;
    return required.isEmpty ? null : sortByRank(required).first;
  }

  List<int> get _levelOptions {
    final required = widget.session.requiredLevels;
    return required.isEmpty ? validLevels : sortByRank(required);
  }

  /// Only male and female options are available for registration.
  /// Gender drives the fee on a priced session, and the fee table only has
  /// male and female columns.
  List<Gender> get _genderOptions => const [Gender.male, Gender.female];

  void _addGuest() => setState(
    () => _drafts = [
      ..._drafts,
      RegistrationPlayerDraft(isMe: false, level: _defaultLevel),
    ],
  );

  Future<void> _submit() async {
    if (_drafts.isEmpty) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      await ref
          .read(myRegistrationProvider(widget.session.id).notifier)
          .register(_drafts, accessCode: widget.session.accessCode);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.registrationSuccessPending)),
      );
      navigator.pop(true);
    } on ApiException catch (error) {
      // Stay open with the data intact, like the web modal — the common
      // failures here (level not allowed, already registered) are all fixable
      // in place.
      if (mounted) setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
    } on Object {
      if (mounted) setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      // Lifts the sheet above the keyboard so the focused field stays visible.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.asGuest
                        ? l10n.sessionAddGuest
                        : l10n.registrationTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    widget.session.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.extension<AppPalette>()!.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.extension<AppPalette>()!.border),
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  children: [
                    if (widget.session.requiredLevels.isNotEmpty)
                      _RequiredLevelsBanner(
                        levels: sortByRank(widget.session.requiredLevels),
                      ),
                    for (var i = 0; i < _drafts.length; i++)
                      RegistrationPlayerCard(
                        // Keyed by identity, not index: without this, removing
                        // a row would leave the next row showing the removed
                        // row's text, because TextFormField.initialValue only
                        // applies on first build.
                        key: ObjectKey(_drafts[i]),
                        draft: _drafts[i],
                        levelOptions: _levelOptions,
                        genderOptions: _genderOptions,
                        onChanged: (draft) => _drafts[i] = draft,
                        onRemove: i == 0
                            ? null
                            : () => setState(() => _drafts.removeAt(i)),
                      ),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _addGuest,
                      icon: const Icon(AppIcons.userPlus),
                      label: Text(l10n.sessionAddGuest),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: theme.extension<AppPalette>()!.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.registrationSubmit(_drafts.length)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// States which levels the session accepts, so a player understands why the
/// level dropdown is short.
class _RequiredLevelsBanner extends StatelessWidget {
  const _RequiredLevelsBanner({required this.levels});

  final List<int> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              AppIcons.shield,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${l10n.registrationRequiredLevels}:',
                  style: theme.textTheme.bodySmall,
                ),
                for (final level in levels)
                  SkillLevelBadge(level: level, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
