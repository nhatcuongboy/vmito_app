import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ClubFormScreen extends ConsumerWidget {
  const ClubFormScreen({this.clubId, super.key});

  final String? clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clubId == null) return const _ClubForm();
    final club = ref.watch(managedClubProvider(clubId!));
    return club.when(
      data: (value) => _ClubForm(initialClub: value),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(managedClubProvider(clubId!)),
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ClubForm extends ConsumerStatefulWidget {
  const _ClubForm({this.initialClub});

  final ClubSummary? initialClub;

  @override
  ConsumerState<_ClubForm> createState() => _ClubFormState();
}

class _ClubFormState extends ConsumerState<_ClubForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _maxMembersController;
  late String _joinPolicy;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    final club = widget.initialClub;
    _nameController = TextEditingController(text: club?.name);
    _descriptionController = TextEditingController(text: club?.description);
    _locationController = TextEditingController(text: club?.location);
    _maxMembersController = TextEditingController(
      text: club?.maxMembers?.toString(),
    );
    _joinPolicy = club?.joinPolicy ?? 'APPROVAL_REQUIRED';
    _isPublic = club?.isPublic ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(clubManagementControllerProvider).isLoading;
    final editing = widget.initialClub != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? l10n.clubEdit : l10n.clubCreate),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            TextFormField(
              key: const Key('club-name-field'),
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(labelText: l10n.clubName),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? l10n.clubNameRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLength: 5000,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: l10n.clubDescription),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _locationController,
              maxLength: 200,
              decoration: InputDecoration(labelText: l10n.clubLocation),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('club-max-members-field'),
              controller: _maxMembersController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.clubMaxMembers),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = int.tryParse(value);
                return parsed == null || parsed < 1 || parsed > 500
                    ? l10n.clubMaxMembersInvalid
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _joinPolicy,
              decoration: InputDecoration(labelText: l10n.clubJoinPolicy),
              items: [
                DropdownMenuItem(
                  value: 'OPEN',
                  child: Text(l10n.clubJoinOpen),
                ),
                DropdownMenuItem(
                  value: 'APPROVAL_REQUIRED',
                  child: Text(l10n.clubJoinApproval),
                ),
                DropdownMenuItem(
                  value: 'INVITATION_ONLY',
                  child: Text(l10n.clubJoinInvitation),
                ),
              ],
              onChanged: (value) => _joinPolicy = value ?? _joinPolicy,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.clubPublic),
              subtitle: Text(l10n.clubPublicDescription),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('club-save-button'),
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = ClubDraft(
      name: _nameController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      maxMembers: int.tryParse(_maxMembersController.text),
      joinPolicy: _joinPolicy,
      isPublic: _isPublic,
    );
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .saveClub(draft, clubId: widget.initialClub?.id);
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}
