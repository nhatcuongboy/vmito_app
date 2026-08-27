import 'package:intl/intl.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

String? sessionTimeRangeLabel(
  Session session,
  AppLocalizations l10n,
  String locale,
) {
  final start = session.displayStartTime;
  if (start == null) return null;
  return Dates.dayWithRange(
    start,
    session.plannedEndTime,
    locale: locale,
    todayLabel: l10n.dateToday,
    tomorrowLabel: l10n.dateTomorrow,
    yesterdayLabel: l10n.dateYesterday,
  );
}

/// `20:00 - 22:00`, or null when the host has not scheduled the session.
///
/// Split from [sessionTimeRangeLabel] because the detail screen renders the
/// clock range and the day on separate visual weights — the web app does the
/// same, and joining them here would force the widget to re-split a string.
String? sessionDetailTimeLabel(Session session, String locale) {
  final start = session.displayStartTime;
  if (start == null) return null;
  final end = session.plannedEndTime;
  final from = Dates.timeOnly(start, locale: locale);
  return end == null ? from : '$from - ${Dates.timeOnly(end, locale: locale)}';
}

/// `Hôm nay, 02/08/2026` for nearby sessions, or `Th 6, 28/08/2026`.
String? sessionDetailDateLabel(
  Session session,
  AppLocalizations l10n,
  String locale,
) {
  final start = session.displayStartTime;
  if (start == null) return null;
  final day = Dates.relativeDay(
    start,
    locale: locale,
    todayLabel: l10n.dateToday,
    tomorrowLabel: l10n.dateTomorrow,
    yesterdayLabel: l10n.dateYesterday,
  );
  final date = Dates.dateOnly(start, locale: locale);
  final relativeDays = {
    l10n.dateToday,
    l10n.dateTomorrow,
    l10n.dateYesterday,
  };
  if (relativeDays.contains(day)) return '$day, $date';

  final weekday = DateFormat('EEE', locale).format(start.toLocal());
  return '$weekday, $date';
}

String? sessionPriceLabel(Session session, String locale) {
  final fees = session.feeConfig;
  if (fees == null) return null;
  if (fees.isSplitEvenly) {
    final perPlayer = fees.splitPerPlayer;
    return perPlayer == null
        ? null
        : Money.compactVnd(perPlayer, locale: locale);
  }
  return Money.compactRange(
    fees.maleFee,
    fees.femaleFee,
    locale: locale,
  );
}
