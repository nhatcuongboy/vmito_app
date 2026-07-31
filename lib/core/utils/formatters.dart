import 'package:intl/intl.dart';

String _intlLocale(String languageCode) => switch (languageCode) {
  'en' => 'en_US',
  'zh' => 'zh_CN',
  _ => 'vi_VN',
};

abstract final class Money {
  static String vnd(num amount, {String locale = 'vi'}) =>
      NumberFormat.currency(
        locale: _intlLocale(locale),
        symbol: '₫',
        decimalDigits: 0,
      ).format(amount.round());

  static String vndPlain(num amount, {String locale = 'vi'}) =>
      NumberFormat.decimalPattern(
        _intlLocale(locale),
      ).format(amount.round());

  static String compactVnd(num amount, {String locale = 'vi'}) {
    final value = amount.round();
    if (locale == 'zh') {
      if (value >= 10000 && value % 10000 == 0) return '${value ~/ 10000}万';
      if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000}千';
      return vndPlain(value, locale: locale);
    }

    if (value >= 1000000) {
      final millions = value / 1000000;
      final decimalSeparator = locale == 'vi' ? ',' : '.';
      final text = millions == millions.roundToDouble()
          ? millions.round().toString()
          : millions.toStringAsFixed(1).replaceAll('.', decimalSeparator);
      return '$text${locale == 'vi' ? 'tr' : 'M'}';
    }
    if (value >= 1000 && value % 1000 == 0) {
      return '${value ~/ 1000}${locale == 'vi' ? 'k' : 'K'}';
    }
    return vndPlain(value, locale: locale);
  }

  static String? compactRange(
    int? low,
    int? high, {
    String locale = 'vi',
  }) {
    final values = [low, high].whereType<int>().toList()..sort();
    if (values.isEmpty) return null;
    if (values.first == values.last) {
      return compactVnd(values.first, locale: locale);
    }
    return '${compactVnd(values.first, locale: locale)}-'
        '${compactVnd(values.last, locale: locale)}';
  }
}

abstract final class Numbers {
  static String decimal(num value, {String locale = 'vi', int digits = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: _intlLocale(locale),
        decimalDigits: digits,
      ).format(value);
}

abstract final class Dates {
  static String dayAndTime(DateTime time, {String locale = 'vi'}) => DateFormat(
    'EEE, d MMM • HH:mm',
    _intlLocale(locale),
  ).format(time.toLocal());

  static String timeOnly(DateTime time, {String locale = 'vi'}) =>
      DateFormat('HH:mm', _intlLocale(locale)).format(time.toLocal());

  static String dateOnly(DateTime time, {String locale = 'vi'}) =>
      DateFormat.yMd(_intlLocale(locale)).format(time.toLocal());

  static String dayWithRange(
    DateTime start,
    DateTime? end, {
    String locale = 'vi',
    String todayLabel = 'Hôm nay',
    String tomorrowLabel = 'Ngày mai',
    String yesterdayLabel = 'Hôm qua',
    DateTime? now,
  }) {
    final local = start.toLocal();
    final day = relativeDay(
      local,
      locale: locale,
      todayLabel: todayLabel,
      tomorrowLabel: tomorrowLabel,
      yesterdayLabel: yesterdayLabel,
      now: now,
    );
    final times = end == null
        ? timeOnly(local, locale: locale)
        : '${timeOnly(local, locale: locale)}-'
              '${timeOnly(end, locale: locale)}';
    return '$day, $times';
  }

  static String relativeDay(
    DateTime time, {
    String locale = 'vi',
    String todayLabel = 'Hôm nay',
    String tomorrowLabel = 'Ngày mai',
    String yesterdayLabel = 'Hôm qua',
    DateTime? now,
  }) {
    final local = time.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final days = DateTime(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;

    return switch (days) {
      0 => todayLabel,
      1 => tomorrowLabel,
      -1 => yesterdayLabel,
      _ => DateFormat('EEE, d MMM', _intlLocale(locale)).format(local),
    };
  }

  static String waitMinutes(int minutes, {String locale = 'vi'}) {
    if (locale == 'zh') {
      if (minutes < 60) return '$minutes分钟';
      final hours = minutes ~/ 60;
      final rest = minutes % 60;
      return rest == 0 ? '$hours小时' : '$hours小时 $rest分钟';
    }
    final minuteSuffix = locale == 'vi' ? 'p' : 'm';
    final hourSuffix = locale == 'vi' ? 'g' : 'h';
    if (minutes < 60) return '$minutes$minuteSuffix';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? '$hours$hourSuffix'
        : '$hours$hourSuffix $rest$minuteSuffix';
  }
}
