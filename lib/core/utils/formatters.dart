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
    return '${vndPlain(value, locale: locale)}đ';
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

  /// A multi-day event by calendar day: `Th 7, 6 thg 6, 2026` for one day,
  /// `6 thg 6 – 7 thg 6, 2026` for a range. The year is repeated only when the
  /// range crosses one. Pass calendar days, not instants — no zone shift.
  static String dayRange(DateTime start, DateTime end, {String locale = 'vi'}) {
    final intlLocale = _intlLocale(locale);
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay || end.isBefore(start)) {
      return DateFormat.yMMMEd(intlLocale).format(start);
    }
    final to = DateFormat.yMMMd(intlLocale).format(end);
    final from = start.year == end.year
        ? DateFormat.MMMd(intlLocale).format(start)
        : DateFormat.yMMMd(intlLocale).format(start);
    return '$from – $to';
  }

  /// `12/9 – 14/9`, or one date when both fall on the same day. For compact
  /// rows where the year is implied.
  static String shortDateRange(
    DateTime start,
    DateTime end, {
    String locale = 'vi',
  }) {
    final format = DateFormat.Md(_intlLocale(locale));
    final from = format.format(start.toLocal());
    final to = format.format(end.toLocal());
    return from == to ? from : '$from – $to';
  }

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

  /// Returns a human-readable relative time string (e.g. "2 giờ trước"),
  /// matching the web's `formatDistanceToNow` from date-fns.
  static String timeAgo(DateTime time, {String locale = 'vi'}) {
    final diff = DateTime.now().difference(time.toLocal());
    final seconds = diff.inSeconds.abs();
    final minutes = diff.inMinutes.abs();
    final hours = diff.inHours.abs();
    final days = diff.inDays.abs();

    if (locale == 'zh') {
      if (seconds < 60) return '刚刚';
      if (minutes < 60) return '$minutes分钟前';
      if (hours < 24) return '$hours小时前';
      if (days < 7) return '$days天前';
      if (days < 30) return '${days ~/ 7}周前';
      if (days < 365) return '${days ~/ 30}个月前';
      return '${days ~/ 365}年前';
    }

    if (locale == 'en') {
      if (seconds < 60) return 'just now';
      if (minutes < 60) return '${minutes}m ago';
      if (hours < 24) return '${hours}h ago';
      if (days < 7) return '${days}d ago';
      if (days < 30) return '${days ~/ 7}w ago';
      if (days < 365) return '${days ~/ 30}mo ago';
      return '${days ~/ 365}y ago';
    }

    // Vietnamese (default)
    if (seconds < 60) return 'vừa xong';
    if (minutes < 60) return '$minutes phút trước';
    if (hours < 24) return '$hours giờ trước';
    if (days < 7) return '$days ngày trước';
    if (days < 30) return '${days ~/ 7} tuần trước';
    if (days < 365) return '${days ~/ 30} tháng trước';
    return '${days ~/ 365} năm trước';
  }
}
