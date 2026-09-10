import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/payment/application/host_finance_export_service.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/application/transaction_dashboard_controller.dart';
import 'package:vmito_app/features/payment/domain/form/transaction_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/presentation/widgets/host_finance_chart.dart';
import 'package:vmito_app/features/payment/presentation/widgets/player_payment_detail_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

enum _ExportAction { csv, pdf, print }

class TransactionDashboardScreen extends ConsumerStatefulWidget {
  const TransactionDashboardScreen({super.key});

  @override
  ConsumerState<TransactionDashboardScreen> createState() =>
      _TransactionDashboardScreenState();
}

class _TransactionDashboardScreenState
    extends ConsumerState<TransactionDashboardScreen> {
  final FormGroup _filterForm = createFinanceFilterForm();
  final HostFinanceExportService _exportService =
      const HostFinanceExportService();
  late HostFinanceQuery _query;

  @override
  void initState() {
    super.initState();
    _query = resolveFinanceQuery(
      period: FinancePeriod.thisMonth,
      now: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _filterForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportValue = ref.watch(hostFinanceReportProvider(_query));
    final report = reportValue.value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.transactionDashboardTitle),
          actions: [
            PopupMenuButton<_ExportAction>(
              tooltip: l10n.transactionExport,
              enabled: report != null,
              onSelected: report == null
                  ? null
                  : (action) => _export(context, action, report),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ExportAction.csv,
                  child: ListTile(
                    leading: const Icon(AppIcons.download),
                    title: Text(l10n.transactionShareCsv),
                  ),
                ),
                PopupMenuItem(
                  value: _ExportAction.pdf,
                  child: ListTile(
                    leading: const Icon(AppIcons.share),
                    title: Text(l10n.transactionSharePdf),
                  ),
                ),
                PopupMenuItem(
                  value: _ExportAction.print,
                  child: ListTile(
                    leading: const Icon(AppIcons.receipt),
                    title: Text(l10n.transactionPrintPdf),
                  ),
                ),
              ],
            ),
          ],
          bottom: AppTabBar(
            tabs: [
              Tab(text: l10n.transactionTabOverview),
              Tab(text: l10n.transactionTabBySession),
              Tab(text: l10n.transactionTabByPlayer),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Text(
                    l10n.transactionDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppPalette>()!.mutedForeground,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.sm,
                  ),
                  child: AppReactiveForm<void>(
                    formGroup: _filterForm,
                    child: _FinanceFilterCard(
                      onPreset: _selectPeriod,
                      onCustom: _showCustomRange,
                    ),
                  ),
                ),
                Expanded(
                  child: reportValue.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => AppErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(
                        hostFinanceReportProvider(_query),
                      ),
                    ),
                    data: (data) => TabBarView(
                      children: [
                        _OverviewTab(
                          report: data,
                          onRefresh: _refresh,
                        ),
                        _BySessionTab(
                          rows: data.bySession,
                          onRefresh: _refresh,
                        ),
                        _ByPlayerTab(
                          summaries: data.byPlayer,
                          query: _query,
                          onRefresh: _refresh,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() =>
      ref.refresh(hostFinanceReportProvider(_query).future);

  void _selectPeriod(FinancePeriod period) {
    _filterForm.patchValue({
      FinanceFilterControl.period: period,
      FinanceFilterControl.from: null,
      FinanceFilterControl.to: null,
    });
    setState(() {
      _query = resolveFinanceQuery(period: period, now: DateTime.now());
    });
  }

  Future<void> _showCustomRange() async {
    final l10n = AppLocalizations.of(context);
    final previousPeriod =
        _filterForm.control(FinanceFilterControl.period).value
            as FinancePeriod? ??
        FinancePeriod.thisMonth;
    _filterForm.control(FinanceFilterControl.period).value =
        FinancePeriod.custom;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: AppReactiveForm<void>(
          formGroup: _filterForm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.transactionCustomRange,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerButton(
                      controlName: FinanceFilterControl.from,
                      label: l10n.transactionFromDate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DatePickerButton(
                      controlName: FinanceFilterControl.to,
                      label: l10n.transactionToDate,
                    ),
                  ),
                ],
              ),
              ReactiveFormConsumer(
                builder: (context, form, _) {
                  if (!form.controls.values.any((control) => control.touched) ||
                      form.valid) {
                    return const SizedBox.shrink();
                  }
                  final message = form.hasError('rangeOrder')
                      ? l10n.transactionRangeOrderInvalid
                      : form.hasError('rangeTooLong')
                      ? l10n.transactionRangeTooLong
                      : l10n.transactionRangeRequired;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  _filterForm
                    ..markAllAsTouched()
                    ..markAsTouched()
                    ..updateValueAndValidity();
                  if (_filterForm.invalid) {
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(l10n.transactionApply),
              ),
            ],
          ),
        ),
      ),
    );
    if (applied != true || !mounted) {
      _filterForm.control(FinanceFilterControl.period).value = previousPeriod;
      return;
    }
    final from =
        _filterForm.control(FinanceFilterControl.from).value as DateTime?;
    final to = _filterForm.control(FinanceFilterControl.to).value as DateTime?;
    setState(() {
      _query = resolveFinanceQuery(
        period: FinancePeriod.custom,
        now: DateTime.now(),
        customFrom: from,
        customTo: to,
      );
    });
  }

  Future<void> _export(
    BuildContext context,
    _ExportAction action,
    HostFinanceReport report,
  ) async {
    final l10n = AppLocalizations.of(context);
    final labels = _exportLabels(l10n);
    try {
      switch (action) {
        case _ExportAction.csv:
          final bytes = _exportService.csvBytes(report, labels);
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  bytes,
                  mimeType: 'text/csv',
                  name: '${_exportService.fileStem(report)}.csv',
                ),
              ],
              sharePositionOrigin: _shareOrigin(context),
            ),
          );
        case _ExportAction.pdf:
          final bytes = await _exportService.pdfBytes(report, labels);
          await Printing.sharePdf(
            bytes: bytes,
            filename: '${_exportService.fileStem(report)}.pdf',
          );
        case _ExportAction.print:
          final bytes = await _exportService.pdfBytes(report, labels);
          await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transactionExportFailed)),
      );
    }
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  HostFinanceExportLabels _exportLabels(AppLocalizations l10n) =>
      HostFinanceExportLabels(
        title: l10n.transactionDashboardTitle,
        period: l10n.transactionDateRange,
        income: l10n.transactionIncome,
        collected: l10n.transactionCollected,
        outstanding: l10n.transactionOutstanding,
        expenses: l10n.transactionExpenses,
        netActual: l10n.transactionNetActual,
        netExpected: l10n.transactionNetExpected,
        bySession: l10n.transactionTabBySession,
        byPlayer: l10n.transactionTabByPlayer,
        trend: l10n.transactionChartTitle,
        sessionName: l10n.transactionSessionName,
        startTime: l10n.transactionStartTime,
        playerCount: l10n.transactionPlayerCount,
        playerName: l10n.transactionPlayerName,
        sessionCount: l10n.transactionSessionCount,
        bucket: l10n.transactionDate,
      );
}

class _FinanceFilterCard extends StatelessWidget {
  const _FinanceFilterCard({
    required this.onPreset,
    required this.onCustom,
  });

  final ValueChanged<FinancePeriod> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ReactiveValueListenableBuilder<FinancePeriod>(
        formControlName: FinanceFilterControl.period,
        builder: (context, control, _) {
          final selected = control.value ?? FinancePeriod.thisMonth;
          return PopupMenuButton<FinancePeriod>(
            key: const Key('finance-period-menu'),
            tooltip: l10n.transactionDateRange,
            initialValue: selected,
            onSelected: (period) =>
                period == FinancePeriod.custom ? onCustom() : onPreset(period),
            itemBuilder: (context) => [
              for (final period in FinancePeriod.values)
                PopupMenuItem(
                  key: Key('finance-period-${period.name}'),
                  value: period,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: period == selected
                            ? Icon(
                                AppIcons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_periodLabel(l10n, period)),
                    ],
                  ),
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.calendarMonth, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.transactionDateRange,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).extension<AppPalette>()!.mutedForeground,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            _periodLabel(l10n, selected),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Icon(AppIcons.chevronDown),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({required this.controlName, required this.label});

  final String controlName;
  final String label;

  @override
  Widget build(BuildContext context) => ReactiveDatePicker<DateTime>(
    formControlName: controlName,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 1)),
    builder: (context, picker, _) => OutlinedButton.icon(
      onPressed: picker.showPicker,
      icon: const Icon(AppIcons.calendar),
      label: Text(
        picker.value == null
            ? label
            : DateFormat.yMd(
                Localizations.localeOf(context).toString(),
              ).format(picker.value!),
      ),
    ),
  );
}

String _periodLabel(AppLocalizations l10n, FinancePeriod period) =>
    switch (period) {
      FinancePeriod.thisMonth => l10n.transactionThisMonth,
      FinancePeriod.lastMonth => l10n.transactionLastMonth,
      FinancePeriod.quarter => l10n.transactionThisQuarter,
      FinancePeriod.year => l10n.transactionThisYear,
      FinancePeriod.custom => l10n.transactionCustom,
    };

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.report, required this.onRefresh});

  final HostFinanceReport report;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final percent = report.totals.income > 0
        ? (report.totals.collected / report.totals.income * 100).round()
        : 0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        AppIcons.arrowUpward,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: Text(
                          l10n.transactionOverallSummary,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: Text(
                          '${report.totals.playerCount} ${l10n.transactionPlayers} · '
                          '${report.totals.sessionCount} ${l10n.transactionSessions}',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(value: percent / 100),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.transactionPercentCollected(percent)),
                  const SizedBox(height: AppSpacing.md),
                  _KpiGrid(report: report, locale: locale),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.transactionNetExpectedHint(
                      Money.vnd(report.totals.netExpected, locale: locale),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.transactionChartTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HostFinanceChart(
                    series: report.series,
                    granularity: report.range.granularity,
                    incomeLabel: l10n.transactionIncome,
                    expensesLabel: l10n.transactionExpenses,
                    netLabel: l10n.transactionNetActual,
                    emptyLabel: l10n.transactionNoData,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.report, required this.locale});

  final HostFinanceReport report;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _Kpi(
        l10n.transactionIncome,
        report.totals.income,
        report.previous.income,
        AppColors.info,
        AppIcons.banknote,
      ),
      _Kpi(
        l10n.transactionCollected,
        report.totals.collected,
        report.previous.collected,
        AppColors.success,
        AppIcons.checkCircle,
      ),
      _Kpi(
        l10n.transactionOutstanding,
        report.totals.outstanding,
        report.previous.outstanding,
        AppColors.warning,
        AppIcons.clock,
      ),
      _Kpi(
        l10n.transactionExpenses,
        report.totals.expenses,
        report.previous.expenses,
        Colors.purple,
        AppIcons.receipt,
      ),
      _Kpi(
        l10n.transactionNetActual,
        report.totals.netActual,
        report.previous.netActual,
        report.totals.netActual < 0
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
        AppIcons.calculator,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 5 : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(
                width: columns == 2 && identical(item, items.last)
                    ? constraints.maxWidth
                    : width,
                child: _KpiCard(item: item, locale: locale),
              ),
          ],
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.previous, this.color, this.icon);
  final String label;
  final int value;
  final int previous;
  final Color color;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item, required this.locale});
  final _Kpi item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final delta = percentDelta(item.value, item.previous);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: item.color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: item.color.withValues(alpha: 0.06),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, size: 16, color: item.color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              child: Text(
                Money.vnd(item.value, locale: locale),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (delta != null)
              Text(
                '${delta > 0 ? '+' : ''}$delta% ${AppLocalizations.of(context).transactionVsPrevious}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: delta > 0
                      ? AppColors.success
                      : delta < 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BySessionTab extends StatefulWidget {
  const _BySessionTab({required this.rows, required this.onRefresh});
  final List<HostFinanceSessionRow> rows;
  final Future<void> Function() onRefresh;

  @override
  State<_BySessionTab> createState() => _BySessionTabState();
}

class _BySessionTabState extends State<_BySessionTab> {
  late final FormGroup _form = FormGroup({
    'sort': FormControl<SessionFinanceSort>(value: SessionFinanceSort.date),
  });

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveValueListenableBuilder<SessionFinanceSort>(
        formControlName: 'sort',
        builder: (context, control, _) {
          final rows = sortFinanceSessions(
            widget.rows,
            control.value ?? SessionFinanceSort.date,
          );
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: rows.isEmpty ? 2 : rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ReactiveDropdownField<SessionFinanceSort>(
                      formControlName: 'sort',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.transactionSort,
                      ),
                      items: [
                        for (final sort in SessionFinanceSort.values)
                          DropdownMenuItem(
                            value: sort,
                            child: Text(
                              _sessionSortLabel(l10n, sort),
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return _EmptyState(label: l10n.transactionNoData);
                }
                return _SessionCard(row: rows[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

String _sessionSortLabel(AppLocalizations l10n, SessionFinanceSort sort) =>
    switch (sort) {
      SessionFinanceSort.date => l10n.transactionSortDate,
      SessionFinanceSort.netActual => l10n.transactionSortNet,
      SessionFinanceSort.income => l10n.transactionSortIncome,
      SessionFinanceSort.outstanding => l10n.transactionSortOutstanding,
    };

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.row});
  final HostFinanceSessionRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push(AppRoutes.sessionDetail(row.sessionId)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (row.outstanding > 0)
                    Chip(label: Text(l10n.transactionPending)),
                  const Icon(AppIcons.chevronRight),
                ],
              ),
              Text(
                '${row.startTime == null ? '—' : Dates.dayAndTime(row.startTime!, locale: locale)} · '
                '${row.playerCount} ${l10n.transactionPlayers}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    '${l10n.transactionIncome}: ${Money.vnd(row.income, locale: locale)}',
                  ),
                  Text(
                    '${l10n.transactionCollected}: ${Money.vnd(row.collected, locale: locale)}',
                  ),
                  Text(
                    '${l10n.transactionExpenses}: ${Money.vnd(row.expenses, locale: locale)}',
                  ),
                  Text(
                    '${l10n.transactionNetActual}: ${Money.vnd(row.netActual, locale: locale)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: row.netActual < 0
                          ? Theme.of(context).colorScheme.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ByPlayerTab extends ConsumerStatefulWidget {
  const _ByPlayerTab({
    required this.summaries,
    required this.query,
    required this.onRefresh,
  });
  final List<HostTransactionSummary> summaries;
  final HostFinanceQuery query;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_ByPlayerTab> createState() => _ByPlayerTabState();
}

class _ByPlayerTabState extends ConsumerState<_ByPlayerTab> {
  final FormGroup _form = createPlayerFinanceFilterForm();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppReactiveForm<void>(
      formGroup: _form,
      child: ReactiveFormConsumer(
        builder: (context, form, _) {
          final rows = filterFinancePlayers(
            widget.summaries,
            search:
                form.control(PlayerFilterControl.search).value as String? ?? '',
            status:
                form.control(PlayerFilterControl.status).value
                    as PlayerPaymentStatusFilter? ??
                PlayerPaymentStatusFilter.all,
            sort:
                form.control(PlayerFilterControl.sort).value
                    as PlayerFinanceSort? ??
                PlayerFinanceSort.totalAmount,
          );
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: rows.isEmpty ? 2 : rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _PlayerFilters(form: form);
                if (rows.isEmpty) {
                  return _EmptyState(label: l10n.transactionNoTransactions);
                }
                return _PlayerCard(
                  summary: rows[index - 1],
                  query: widget.query,
                  onRemind: () => _remind(rows[index - 1]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _remind(HostTransactionSummary summary) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(transactionDashboardControllerProvider.notifier)
        .remindUser(summary.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.transactionReminderSent : l10n.transactionReminderFailed,
        ),
      ),
    );
  }
}

class _PlayerFilters extends StatelessWidget {
  const _PlayerFilters({required this.form});
  final FormGroup form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          ReactiveTextField<String>(
            formControlName: PlayerFilterControl.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search),
              hintText: l10n.transactionSearchPlayer,
            ),
          ),
          ReactiveDropdownField<PlayerPaymentStatusFilter>(
            formControlName: PlayerFilterControl.status,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.transactionStatusFilter,
            ),
            items: [
              DropdownMenuItem(
                value: PlayerPaymentStatusFilter.all,
                child: Text(
                  l10n.transactionFilterAll,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: PlayerPaymentStatusFilter.pending,
                child: Text(
                  l10n.transactionFilterPending,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: PlayerPaymentStatusFilter.paid,
                child: Text(
                  l10n.transactionFilterPaid,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
            ],
          ),
          ReactiveDropdownField<PlayerFinanceSort>(
            formControlName: PlayerFilterControl.sort,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.transactionSort),
            items: [
              DropdownMenuItem(
                value: PlayerFinanceSort.totalAmount,
                child: Text(
                  l10n.transactionSortTotal,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: PlayerFinanceSort.pendingAmount,
                child: Text(
                  l10n.transactionSortOutstanding,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: PlayerFinanceSort.name,
                child: Text(
                  l10n.transactionSortName,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: PlayerFinanceSort.sessions,
                child: Text(
                  l10n.transactionSortSessions,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
            ],
          ),
        ];
        if (constraints.maxWidth >= 600) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  Expanded(child: fields[i]),
                  if (i < fields.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            children: [
              for (final field in fields) ...[
                field,
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.summary,
    required this.query,
    required this.onRemind,
  });
  final HostTransactionSummary summary;
  final HostFinanceQuery query;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final canLoad = summary.userId.trim().toLowerCase() != 'guest';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) =>
              PlayerPaymentDetailSheet(summary: summary, query: query),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final identity = Row(
                children: [
                  CircleAvatar(
                    backgroundImage: summary.userImage?.isNotEmpty ?? false
                        ? CachedNetworkImageProvider(summary.userImage!)
                        : null,
                    child: summary.userImage?.isNotEmpty ?? false
                        ? null
                        : Text(
                            summary.userName.trim().isEmpty
                                ? '•'
                                : summary.userName.trim()[0].toUpperCase(),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.userName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${summary.totalSessions} ${l10n.transactionSessions}',
                        ),
                        if ((summary.totalRatings ?? 0) > 0)
                          Row(
                            children: [
                              const Icon(
                                AppIcons.star,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              Text(
                                ' ${summary.averageRating?.toStringAsFixed(1)} (${summary.totalRatings})',
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              );
              final amounts = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.vnd(summary.totalAmount, locale: locale),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    summary.pendingAmount > 0
                        ? '${l10n.transactionPending}: ${Money.vnd(summary.pendingAmount, locale: locale)}'
                        : l10n.transactionFullyPaid,
                    style: TextStyle(
                      color: summary.pendingAmount > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                  if (canLoad && summary.pendingAmount > 0)
                    TextButton.icon(
                      onPressed: onRemind,
                      icon: const Icon(AppIcons.notifications, size: 16),
                      label: Text(l10n.transactionRemind),
                    ),
                ],
              );
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: identity),
                        const Icon(AppIcons.chevronRight),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(alignment: Alignment.centerRight, child: amounts),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: AppSpacing.md),
                  amounts,
                  const Icon(AppIcons.chevronRight),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      children: [
        const Icon(AppIcons.receipt, size: 40),
        const SizedBox(height: AppSpacing.sm),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}
