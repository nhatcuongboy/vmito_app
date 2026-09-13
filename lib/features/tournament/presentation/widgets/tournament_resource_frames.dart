import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

/// Scrollable list frame shared by the resource collection panels.
class TournamentResourceFrame extends StatelessWidget {
  const TournamentResourceFrame({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.header,
    required this.children,
    super.key,
  });
  final bool loading;
  final Object? error;
  final Future<void> Function() onRetry;
  final List<Widget> header;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRetry,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (final child in header)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        if (loading) const LinearProgressIndicator(),
        if (error != null) _ResourceError(onRetry: onRetry),
        ...children,
      ],
    ),
  );
}

/// Full-screen form frame shared by the resource editors.
class TournamentEditorFrame extends StatelessWidget {
  const TournamentEditorFrame({
    required this.title,
    required this.form,
    required this.busy,
    required this.error,
    required this.onSave,
    required this.children,
    this.canSave = true,
    super.key,
  });
  final String title;
  final FormGroup form;
  final bool busy;
  final bool canSave;
  final Object? error;
  final Future<void> Function() onSave;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AppReactiveForm<void>(
            formGroup: form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AbsorbPointer(
                  absorbing: busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in children)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: child,
                        ),
                    ],
                  ),
                ),
                if (error != null)
                  Text(
                    resourceErrorMessage(context, error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: busy || !canSave
                      ? null
                      : () async {
                          form.markAllAsTouched();
                          if (form.invalid || form.pending) return;
                          await onSave();
                        },
                  child: Text(
                    busy
                        ? AppLocalizations.of(context).commonLoading
                        : AppLocalizations.of(context).commonSave,
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

/// The backend's own message when there is one — it explains rule violations
/// such as changing team size after registrations exist.
String resourceErrorMessage(BuildContext context, Object? error) =>
    error is ApiException && error.message.trim().isNotEmpty
    ? error.message
    : AppLocalizations.of(context).tournamentManageSaveFailed;

class _ResourceError extends StatelessWidget {
  const _ResourceError({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(AppLocalizations.of(context).tournamentManageLoadFailed),
    trailing: TextButton(
      onPressed: onRetry,
      child: Text(AppLocalizations.of(context).commonRetry),
    ),
  );
}
