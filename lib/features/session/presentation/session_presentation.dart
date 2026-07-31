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
