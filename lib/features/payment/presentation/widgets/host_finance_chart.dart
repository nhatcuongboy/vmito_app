import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

class HostFinanceChart extends StatefulWidget {
  const HostFinanceChart({
    required this.series,
    required this.granularity,
    required this.incomeLabel,
    required this.expensesLabel,
    required this.netLabel,
    required this.emptyLabel,
    super.key,
  });

  final List<HostFinanceSeriesPoint> series;
  final HostFinanceGranularity granularity;
  final String incomeLabel;
  final String expensesLabel;
  final String netLabel;
  final String emptyLabel;

  @override
  State<HostFinanceChart> createState() => _HostFinanceChartState();
}

class _HostFinanceChartState extends State<HostFinanceChart> {
  final _scrollController = ScrollController();
  int? _selectedIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.series.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(child: Text(widget.emptyLabel)),
      );
    }
    final locale = Localizations.localeOf(context).languageCode;
    return LayoutBuilder(
      builder: (context, constraints) {
        const pointWidth = 54.0;
        final width = math.max(
          constraints.maxWidth,
          widget.series.length * pointWidth + 48,
        );
        return Semantics(
          label:
              '${widget.incomeLabel}, ${widget.expensesLabel}, ${widget.netLabel}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                children: [
                  _Legend(color: AppColors.info, label: widget.incomeLabel),
                  _Legend(color: Colors.purple, label: widget.expensesLabel),
                  _Legend(color: AppColors.success, label: widget.netLabel),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: GestureDetector(
                  onTapDown: (details) {
                    final index = ((details.localPosition.dx - 48) / pointWidth)
                        .floor()
                        .clamp(0, widget.series.length - 1);
                    setState(() => _selectedIndex = index);
                  },
                  child: CustomPaint(
                    size: Size(width, 220),
                    painter: _FinanceChartPainter(
                      series: widget.series,
                      granularity: widget.granularity,
                      selectedIndex: _selectedIndex,
                      colorScheme: Theme.of(context).colorScheme,
                      palette: Theme.of(context).extension<AppPalette>()!,
                      locale: locale,
                    ),
                  ),
                ),
              ),
              if (_selectedIndex case final index?) ...[
                const SizedBox(height: AppSpacing.sm),
                _PointDetails(
                  point: widget.series[index],
                  locale: locale,
                  incomeLabel: widget.incomeLabel,
                  expensesLabel: widget.expensesLabel,
                  netLabel: widget.netLabel,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _PointDetails extends StatelessWidget {
  const _PointDetails({
    required this.point,
    required this.locale,
    required this.incomeLabel,
    required this.expensesLabel,
    required this.netLabel,
  });

  final HostFinanceSeriesPoint point;
  final String locale;
  final String incomeLabel;
  final String expensesLabel;
  final String netLabel;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(Dates.dateOnly(point.bucket, locale: locale)),
          Text('$incomeLabel: ${Money.vnd(point.income, locale: locale)}'),
          Text('$expensesLabel: ${Money.vnd(point.expenses, locale: locale)}'),
          Text('$netLabel: ${Money.vnd(point.netActual, locale: locale)}'),
        ],
      ),
    ),
  );
}

class _FinanceChartPainter extends CustomPainter {
  const _FinanceChartPainter({
    required this.series,
    required this.granularity,
    required this.selectedIndex,
    required this.colorScheme,
    required this.palette,
    required this.locale,
  });

  final List<HostFinanceSeriesPoint> series;
  final HostFinanceGranularity granularity;
  final int? selectedIndex;
  final ColorScheme colorScheme;
  final AppPalette palette;
  final String locale;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const top = 8.0;
    const bottom = 28.0;
    const pointWidth = 54.0;
    final chartHeight = size.height - top - bottom;
    final values = <int>[
      0,
      for (final point in series) ...[
        point.income,
        point.expenses,
        point.netActual,
      ],
    ];
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final span = math.max(1, maxValue - minValue);
    double y(num value) => top + (maxValue - value) / span * chartHeight;

    final gridPaint = Paint()..color = palette.border;
    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final lineY = top + chartHeight * i / 4;
      canvas.drawLine(
        Offset(left, lineY),
        Offset(size.width, lineY),
        gridPaint,
      );
      final value = maxValue - span * i / 4;
      labelPainter
        ..text = TextSpan(
          text: Money.compactVnd(value, locale: locale),
          style: TextStyle(color: palette.mutedForeground, fontSize: 9),
        )
        ..layout(maxWidth: left - 4)
        ..paint(canvas, Offset(0, lineY - 6));
    }
    final zeroY = y(0);
    final incomePaint = Paint()..color = AppColors.info.withValues(alpha: 0.85);
    final expensePaint = Paint()..color = Colors.purple.withValues(alpha: 0.75);
    final netPaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < series.length; i++) {
      final point = series[i];
      final centerX = left + i * pointWidth + pointWidth / 2;
      if (selectedIndex == i) {
        canvas.drawRect(
          Rect.fromLTWH(left + i * pointWidth, top, pointWidth, chartHeight),
          Paint()..color = palette.muted.withValues(alpha: 0.65),
        );
      }
      canvas
        ..drawRect(
          Rect.fromLTRB(centerX - 13, y(point.income), centerX - 2, zeroY),
          incomePaint,
        )
        ..drawRect(
          Rect.fromLTRB(centerX + 2, y(point.expenses), centerX + 13, zeroY),
          expensePaint,
        );
      final netPoint = Offset(centerX, y(point.netActual));
      if (i == 0) {
        path.moveTo(netPoint.dx, netPoint.dy);
      } else {
        path.lineTo(netPoint.dx, netPoint.dy);
      }
      canvas.drawCircle(
        netPoint,
        3,
        Paint()..color = AppColors.success,
      );
      labelPainter
        ..text = TextSpan(
          text: _bucketLabel(point.bucket),
          style: TextStyle(color: palette.mutedForeground, fontSize: 9),
        )
        ..layout(maxWidth: pointWidth - 4)
        ..paint(
          canvas,
          Offset(centerX - labelPainter.width / 2, size.height - bottom + 8),
        );
    }
    canvas.drawPath(path, netPaint);
  }

  String _bucketLabel(DateTime bucket) => switch (granularity) {
    HostFinanceGranularity.month => DateFormat(
      'MM/yy',
    ).format(bucket.toLocal()),
    _ => DateFormat('dd/MM').format(bucket.toLocal()),
  };

  @override
  bool shouldRepaint(covariant _FinanceChartPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.colorScheme != colorScheme;
}
