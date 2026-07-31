import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/application/create_session_controller.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/presentation/widgets/level_band_picker.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Create a session — the entry point of host management (P3).
///
/// Deliberately smaller than the web form, which carries ~30 fields including
/// venue linkage, image galleries, club association and crawled-post metadata.
/// A host standing at a court needs the six decisions below; everything else
/// has a working default or belongs to a later phase.
class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({
    this.initialSession,
    this.editingSessionId,
    this.isClone = false,
    super.key,
  });

  final Session? initialSession;
  final String? editingSessionId;
  final bool isClone;

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _startTime = _defaultStart();
  int _durationMinutes = 120;
  int _numberOfCourts = 2;
  int _maxPlayersPerCourt = 8;
  List<int> _requiredLevels = const [];
  int? _maleFee;
  int? _femaleFee;
  bool _allowGuestJoin = true;

  bool get _isEditing => widget.editingSessionId != null;

  @override
  void initState() {
    super.initState();
    final session = widget.initialSession;
    if (session == null) return;
    _nameController.text = session.name;
    _locationController.text = session.location ?? '';
    _descriptionController.text = session.description ?? '';
    _startTime = widget.isClone
        ? _defaultStart()
        : session.displayStartTime ?? _defaultStart();
    _durationMinutes = session.sessionDuration > 0
        ? session.sessionDuration
        : 120;
    _numberOfCourts = session.numberOfCourts > 0 ? session.numberOfCourts : 1;
    _maxPlayersPerCourt = session.maxPlayersPerCourt > 0
        ? session.maxPlayersPerCourt
        : 4;
    _requiredLevels = session.requiredLevels;
    _maleFee = session.feeConfig?.maleFee;
    _femaleFee = session.feeConfig?.femaleFee;
    _allowGuestJoin = session.allowGuestJoin;
  }

  /// Next full hour, so the picker never opens on a time already past.
  static DateTime _defaultStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      // Sessions are scheduled, not backdated.
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final request = CreateSessionRequest(
      name: _nameController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      startTime: _startTime,
      sessionDuration: _durationMinutes,
      numberOfCourts: _numberOfCourts,
      maxPlayersPerCourt: _maxPlayersPerCourt,
      requiredLevels: _requiredLevels,
      allowGuestJoin: _allowGuestJoin,
      feeConfig: _maleFee == null && _femaleFee == null
          ? null
          : SessionFeeConfig(maleFee: _maleFee, femaleFee: _femaleFee),
    );
    final controller = ref.read(createSessionControllerProvider.notifier);
    final session = _isEditing
        ? await controller.update(widget.editingSessionId!, request)
        : await controller.submit(request);

    if (!mounted || session == null) return;

    // Replace rather than push: coming back to a submitted form would let the
    // host create a duplicate by tapping again.
    context.pushReplacement(AppRoutes.manageSession(session.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(createSessionControllerProvider);
    final isSubmitting = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? l10n.editSessionTitle
              : widget.isClone
              ? l10n.cloneSessionTitle
              : l10n.createSessionTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.createSessionName),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? l10n.createSessionNameRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.createSessionLocation,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.createSessionDescription,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(l10n.createSessionStart),
              subtitle: Text(Dates.dayWithRange(_startTime, _plannedEnd)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: isSubmitting ? null : _pickStart,
            ),

            _Stepper(
              label: l10n.createSessionDuration,
              value: l10n.createSessionDurationMinutes(_durationMinutes),
              onDecrease: _durationMinutes > 30
                  ? () => setState(() => _durationMinutes -= 30)
                  : null,
              onIncrease: _durationMinutes < 480
                  ? () => setState(() => _durationMinutes += 30)
                  : null,
            ),
            _Stepper(
              label: l10n.createSessionCourts,
              value: '$_numberOfCourts',
              onDecrease: _numberOfCourts > 1
                  ? () => setState(() => _numberOfCourts -= 1)
                  : null,
              onIncrease: _numberOfCourts < 20
                  ? () => setState(() => _numberOfCourts += 1)
                  : null,
            ),
            _Stepper(
              label: l10n.createSessionMaxPerCourt,
              value: '$_maxPlayersPerCourt',
              onDecrease: _maxPlayersPerCourt > 4
                  ? () => setState(() => _maxPlayersPerCourt -= 1)
                  : null,
              onIncrease: _maxPlayersPerCourt < 30
                  ? () => setState(() => _maxPlayersPerCourt += 1)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.createSessionCapacity(
                  _numberOfCourts * _maxPlayersPerCourt,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            const Divider(),
            LevelBandPicker(
              selected: _requiredLevels,
              onChanged: (levels) => setState(() => _requiredLevels = levels),
            ),

            const Divider(),
            _FeeFields(
              initialMaleFee: _maleFee,
              initialFemaleFee: _femaleFee,
              onMaleFeeChanged: (value) => _maleFee = value,
              onFemaleFeeChanged: (value) => _femaleFee = value,
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowGuestJoin,
              title: Text(l10n.createSessionAllowGuest),
              onChanged: isSubmitting
                  ? null
                  : (value) => setState(() => _allowGuestJoin = value),
            ),

            if (state.hasError) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage(state.error!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing
                          ? l10n.editSessionSave
                          : l10n.createSessionSubmit,
                    ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  DateTime get _plannedEnd =>
      _startTime.add(Duration(minutes: _durationMinutes));

  String _errorMessage(Object error) => error is Exception
      ? error.toString().replaceFirst('Exception: ', '')
      : '';
}

/// A labelled −/+ control.
///
/// Steppers rather than text fields: court counts and durations are small
/// bounded numbers, and a keyboard for them costs a keyboard dismissal on
/// every field.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    this.onDecrease,
    this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 72,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _FeeFields extends StatelessWidget {
  const _FeeFields({
    required this.initialMaleFee,
    required this.initialFemaleFee,
    required this.onMaleFeeChanged,
    required this.onFemaleFeeChanged,
  });

  final int? initialMaleFee;
  final int? initialFemaleFee;
  final ValueChanged<int?> onMaleFeeChanged;
  final ValueChanged<int?> onFemaleFeeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            l10n.createSessionFees,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _FeeField(
                label: l10n.createSessionFeeMale,
                initialValue: initialMaleFee,
                onChanged: onMaleFeeChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _FeeField(
                label: l10n.createSessionFeeFemale,
                initialValue: initialFemaleFee,
                onChanged: onFemaleFeeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeeField extends StatelessWidget {
  const _FeeField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final int? initialValue;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue?.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: '₫'),
      // VND has no minor unit, so the value is parsed as an int and an empty
      // field means "not priced" rather than zero.
      onChanged: (value) =>
          onChanged(value.trim().isEmpty ? null : int.tryParse(value.trim())),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        return int.tryParse(text) == null ? '—' : null;
      },
    );
  }
}
