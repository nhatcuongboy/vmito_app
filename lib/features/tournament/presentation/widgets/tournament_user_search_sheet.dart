import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// Account picker used when linking a tournament player to a real user.
/// Pops the selected [TournamentUserOption], or null when dismissed.
class TournamentUserSearchSheet extends ConsumerStatefulWidget {
  const TournamentUserSearchSheet({super.key});
  @override
  ConsumerState<TournamentUserSearchSheet> createState() => _UserSearchState();
}

class _UserSearchState extends ConsumerState<TournamentUserSearchSheet> {
  final form = FormGroup({ResourceControl.query: FormControl<String>()});
  String query = '';
  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final result = query.isEmpty
        ? null
        : ref.watch(tournamentUserSearchProvider(query));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AppReactiveForm<void>(
          formGroup: form,
          child: Column(
            children: [
              ReactiveTextField<String>(
                formControlName: ResourceControl.query,
                decoration: InputDecoration(
                  labelText: l.tournamentManageSearchUsers,
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => query = resourceText(form, ResourceControl.query) ?? '',
                ),
                child: Text(l.commonSearch),
              ),
              Expanded(
                child: result == null
                    ? const SizedBox.shrink()
                    : result.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(
                              tournamentUserSearchProvider(query),
                            ),
                            child: Text(l.commonRetry),
                          ),
                        ),
                        data: (users) => users.isEmpty
                            ? Center(child: Text(l.tournamentResourceEmpty))
                            : ListView(
                                children: [
                                  for (final user in users)
                                    ListTile(
                                      title: Text(user.name),
                                      subtitle: Text(user.email),
                                      onTap: () => Navigator.pop(context, user),
                                    ),
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
