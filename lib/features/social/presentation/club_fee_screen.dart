import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/form/club_fee_form.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_required_label.dart';

class ClubFeeScreen extends ConsumerStatefulWidget {
  const ClubFeeScreen({required this.clubId, super.key});

  final String clubId;

  @override
  ConsumerState<ClubFeeScreen> createState() => _ClubFeeScreenState();
}

class _ClubFeeScreenState extends ConsumerState<ClubFeeScreen> {
  late final FormGroup _feeForm;
  late final FormGroup _memberForm;
  late int _month;
  late int _year;
  ClubFeePeriod? _syncedPeriod;

  ClubFeePeriod get _period => (
    clubId: widget.clubId,
    year: _year,
    month: _month,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _feeForm = createClubFeeForm();
    _memberForm = FormGroup({
      'userId': FormControl<String>(validators: [Validators.required]),
    });
  }

  @override
  void dispose() {
    _feeForm.dispose();
    _memberForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fee = ref.watch(clubFeeProvider(_period));
    final members = ref.watch(clubMembersProvider(widget.clubId));
    final monthlyMembers = ref.watch(clubMonthlyMembersProvider(_period));
    final saving = ref.watch(clubManagementControllerProvider).isLoading;
    if (fee case AsyncData(:final value)) _syncFee(value);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clubFeeConfiguration)),
      body: switch ((fee, members, monthlyMembers)) {
        (
          AsyncError(:final error),
          _,
          _,
        ) ||
        (
          _,
          AsyncError(:final error),
          _,
        ) ||
        (
          _,
          _,
          AsyncError(:final error),
        ) => AppErrorView(error: error, onRetry: _refresh),
        (
          AsyncData(),
          AsyncData(value: final clubMembers),
          AsyncData(value: final fixedMembers),
        ) =>
          _content(
            context,
            members: clubMembers,
            monthlyMembers: fixedMembers,
            saving: saving,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _syncFee(ClubFeeConfig? fee) {
    if (_syncedPeriod == _period) return;
    _syncedPeriod = _period;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feeForm.reset(
        value: {
          ClubFeeControl.maleMonthly: fee?.maleFeeMonthly,
          ClubFeeControl.femaleMonthly: fee?.femaleFeeMonthly,
          ClubFeeControl.malePerSession: fee?.maleFeePerSession,
          ClubFeeControl.femalePerSession: fee?.femaleFeePerSession,
        },
      );
      _memberForm.reset();
    });
  }

  Widget _content(
    BuildContext context, {
    required List<ClubMember> members,
    required List<ClubMonthlyMember> monthlyMembers,
    required bool saving,
  }) {
    final l10n = AppLocalizations.of(context);
    final fixedIds = monthlyMembers.map((member) => member.userId).toSet();
    final available = members
        .where(
          (member) =>
              member.status == 'ACTIVE' && !fixedIds.contains(member.userId),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: AppReactiveForm(
                            formGroup: _feeForm,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.clubFeeSelectPeriod,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _periodFields(),
                                const Divider(height: AppSpacing.xl * 2),
                                Text(
                                  l10n.clubFeeMonthly,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _feePair(
                                  wide: wide,
                                  firstName: ClubFeeControl.maleMonthly,
                                  firstLabel: l10n.clubFeeMaleMonthly,
                                  secondName: ClubFeeControl.femaleMonthly,
                                  secondLabel: l10n.clubFeeFemaleMonthly,
                                ),
                                const Divider(height: AppSpacing.xl * 2),
                                Text(
                                  l10n.clubFeePerSession,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _feePair(
                                  wide: wide,
                                  firstName: ClubFeeControl.malePerSession,
                                  firstLabel: l10n.clubFeeMalePerSession,
                                  secondName: ClubFeeControl.femalePerSession,
                                  secondLabel: l10n.clubFeeFemalePerSession,
                                ),
                                ReactiveFormConsumer(
                                  builder: (context, form, _) =>
                                      form.hasError(
                                        'perSessionRequired',
                                      )
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: AppSpacing.sm,
                                          ),
                                          child: Text(
                                            l10n.clubFeePerSessionRequired,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    key: const Key('club-fee-save'),
                                    onPressed: saving ? null : _save,
                                    icon: saving
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(AppIcons.save),
                                    label: Text(l10n.clubFeeSave),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.clubMonthlyMembers,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          l10n.clubMonthlyMembersDescription,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(label: Text('$_month/$_year')),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppReactiveForm(
                                formGroup: _memberForm,
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: _memberDropdown(available),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          _addMemberButton(saving),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _memberDropdown(available),
                                          const SizedBox(height: AppSpacing.md),
                                          _addMemberButton(saving),
                                        ],
                                      ),
                              ),
                              const Divider(height: AppSpacing.xl * 2),
                              if (monthlyMembers.isEmpty)
                                Text(l10n.clubMonthlyMembersEmpty)
                              else
                                for (final member in monthlyMembers)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(member.name),
                                    subtitle: Text(member.email),
                                    trailing: IconButton(
                                      tooltip: l10n.commonRemove,
                                      onPressed: saving
                                          ? null
                                          : () => _removeMember(member.userId),
                                      icon: const Icon(AppIcons.userMinus),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _memberDropdown(List<ClubMember> available) {
    final l10n = AppLocalizations.of(context);
    return ReactiveDropdownField<String>(
      key: const Key('club-fee-member'),
      formControlName: 'userId',
      decoration: InputDecoration(
        label: AppRequiredLabel(l10n.clubSelectMember),
      ),
      items: [
        for (final member in available)
          DropdownMenuItem(
            value: member.userId,
            child: Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
      ],
    );
  }

  Widget _addMemberButton(bool saving) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: saving ? null : _addMember,
      icon: const Icon(AppIcons.userPlus),
      label: Text(l10n.clubAddMonthlyMember),
    );
  }

  Widget _periodFields() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<int>(
          key: const Key('club-fee-month'),
          initialValue: _month,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).clubMonthLabel,
          ),
          items: [
            for (var month = 1; month <= 12; month++)
              DropdownMenuItem(
                value: month,
                child: Text(
                  '$month',
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _month = value;
              _syncedPeriod = null;
            });
          },
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: DropdownButtonFormField<int>(
          key: const Key('club-fee-year'),
          initialValue: _year,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).clubYearLabel,
          ),
          items: [
            for (final year in [_year - 1, _year, _year + 1])
              DropdownMenuItem(value: year, child: Text('$year')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _year = value;
              _syncedPeriod = null;
            });
          },
        ),
      ),
    ],
  );

  Widget _feePair({
    required bool wide,
    required String firstName,
    required String firstLabel,
    required String secondName,
    required String secondLabel,
  }) {
    final children = [
      _feeField(firstName, firstLabel),
      const SizedBox(width: AppSpacing.md, height: AppSpacing.md),
      _feeField(secondName, secondLabel),
    ];
    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (child) =>
                child is SizedBox || !wide ? child : Expanded(child: child),
          )
          .toList(growable: false),
    );
  }

  Widget _feeField(String name, String label) {
    final l10n = AppLocalizations.of(context);
    return ReactiveTextField<int>(
      key: Key('club-fee-$name'),
      formControlName: name,
      valueAccessor: CurrencyValueAccessor(),
      inputFormatters: [ThousandsSeparatorFormatter()],
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        suffixText: l10n.clubCurrencySuffix,
      ),
      validationMessages: {
        'nonNegative': (_) => l10n.clubFeeInvalid,
      },
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    _feeForm.markAllAsTouched();
    if (_feeForm.invalid || _feeForm.pending) return;
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .saveClubFee(
            _period,
            maleFeeMonthly: _feeForm.clubFeeValue(ClubFeeControl.maleMonthly),
            femaleFeeMonthly: _feeForm.clubFeeValue(
              ClubFeeControl.femaleMonthly,
            ),
            maleFeePerSession: _feeForm.clubFeeValue(
              ClubFeeControl.malePerSession,
            ),
            femaleFeePerSession: _feeForm.clubFeeValue(
              ClubFeeControl.femalePerSession,
            ),
          );
      if (mounted) _message(l10n.clubFeeSaved);
    } on Object {
      if (mounted) _message(l10n.clubActionFailed);
    }
  }

  Future<void> _addMember() async {
    final l10n = AppLocalizations.of(context);
    _memberForm.markAllAsTouched();
    if (_memberForm.invalid || _memberForm.pending) return;
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .addMonthlyMember(
            _period,
            _memberForm.control('userId').value as String,
          );
      _memberForm.reset();
      if (mounted) _message(l10n.clubMonthlyMemberAdded);
    } on Object {
      if (mounted) _message(l10n.clubActionFailed);
    }
  }

  Future<void> _removeMember(String userId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(clubManagementControllerProvider.notifier)
          .removeMonthlyMember(_period, userId);
      if (mounted) _message(l10n.clubMonthlyMemberRemoved);
    } on Object {
      if (mounted) _message(l10n.clubActionFailed);
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(clubFeeProvider(_period))
      ..invalidate(clubMembersProvider(widget.clubId))
      ..invalidate(clubMonthlyMembersProvider(_period));
    _syncedPeriod = null;
    await Future.wait([
      ref.read(clubFeeProvider(_period).future),
      ref.read(clubMembersProvider(widget.clubId).future),
      ref.read(clubMonthlyMembersProvider(_period).future),
    ]);
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
