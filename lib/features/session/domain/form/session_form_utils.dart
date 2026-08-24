import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';

/// Pure helpers behind the create-session form, ported from
/// `vmito-fe/src/components/session/session-form/sessionFormUtils.ts`.
///
/// Kept free of Flutter and of `AppLocalizations` so the rules stay unit
/// testable against the same cases the web suite covers.
abstract final class SessionFormUtils {
  /// How far ahead the bulk card lets a host clone. Mirrors
  /// `CLONE_SESSION_MAX_MONTHS_AHEAD` in `vmito-fe/src/constants`.
  static const int cloneMaxMonthsAhead = 3;

  /// Court colours offered in the advanced card, in web order. The first is
  /// the default the backend also uses.
  static const List<String> courtColors = [
    '#179a3b',
    '#808080',
    '#364D63',
    '#B24233',
  ];

  /// Combines the single-day date picker with a time-of-day picker.
  static DateTime combineDateTime(DateTime date, Duration timeOfDay) =>
      DateTime(date.year, date.month, date.day).add(timeOfDay);

  /// Like [combineDateTime], but midnight means "the end of this day".
  ///
  /// A host picking 00:00 as the end of an evening session means the session
  /// runs until midnight, not that it ended twenty-four hours before it began.
  static DateTime endDateTime(DateTime date, Duration timeOfDay) {
    final base = DateTime(date.year, date.month, date.day);
    return timeOfDay == Duration.zero
        ? base.add(const Duration(days: 1))
        : base.add(timeOfDay);
  }

  /// True when [end] is exactly the midnight that closes [start]'s day.
  ///
  /// Used to decide whether a loaded session is single-day: such a session
  /// spans two calendar dates but is one evening, and showing it in the
  /// multi-day layout would confuse the host editing it.
  static bool isEndOfSelectedDay(DateTime start, DateTime end) {
    if (end.hour != 0 ||
        end.minute != 0 ||
        end.second != 0 ||
        end.millisecond != 0) {
      return false;
    }
    final nextDay = DateTime(start.year, start.month, start.day + 1);
    return end.year == nextDay.year &&
        end.month == nextDay.month &&
        end.day == nextDay.day;
  }

  /// Whether a loaded session should open in the multi-day layout.
  static bool isMultiDay(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    if (isEndOfSelectedDay(start, end)) return false;
    return start.year != end.year ||
        start.month != end.month ||
        start.day != end.day;
  }

  /// Whole minutes between the two ends of the session. Never negative — an
  /// inverted range is a validation error, not a negative duration.
  static int durationMinutes(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 0;
    final minutes = end.difference(start).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  static Duration timeOfDay(DateTime value) =>
      Duration(hours: value.hour, minutes: value.minute);

  /// First positive integer embedded in a court name, or null.
  static int? extractCourtNumber(String? courtName) {
    if (courtName == null) return null;
    final match = RegExp(r'\d+').firstMatch(courtName);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(0)!);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Splits AI court names that packed several courts into one string.
  ///
  /// A post reading "Sân 3, 5, 7" comes back as a single entry; keeping it
  /// whole would create one court named after three.
  static List<String> normalizeAiCourtNames(List<String> courtNames) {
    final result = <String>[];
    for (final raw in courtNames) {
      final courtName = raw.trim();
      if (courtName.isEmpty) continue;
      final numbers = RegExp(
        r'\d+',
      ).allMatches(courtName).map((match) => match.group(0)!).toList();
      if (numbers.length > 1) {
        result.addAll(numbers);
      } else {
        result.add(courtName);
      }
    }
    return result;
  }

  /// Builds court rows from what the AI extracted.
  ///
  /// A name that already carries a number becomes that court number with an
  /// empty name — "Sân 5" as both number 5 and name "Sân 5" would render as
  /// "Sân 5 — Sân 5". Collisions fall back to the positional number so two
  /// courts never share one, which the uniqueness rule would reject.
  static List<SessionCourtDraft> buildCourtsFromAiData({
    required int numberOfCourts,
    List<String> courtNames = const [],
    required String Function() nextKey,
  }) {
    final used = <int>{};
    final names = normalizeAiCourtNames(courtNames);

    return [
      for (var index = 0; index < numberOfCourts; index++)
        () {
          final rawName = index < names.length ? names[index].trim() : '';
          final parsed = extractCourtNumber(rawName);
          final courtNumber = parsed != null && !used.contains(parsed)
              ? parsed
              : index + 1;
          used.add(courtNumber);
          return SessionCourtDraft(
            key: nextKey(),
            courtNumber: courtNumber,
            courtName: parsed != null ? '' : rawName,
          );
        }(),
    ];
  }

  /// True when the string is a usable http(s) link. Empty passes — the field
  /// is optional, and "empty" is not "malformed".
  static bool isValidVideoUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// True when the string is empty or a valid phone number.
  static bool isValidPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final digitsOnly = trimmed.replaceAll(RegExp(r'[\s.-]'), '');
    return RegExp(r'^(?:\+?84|0)[1-9][0-9]{8,9}$').hasMatch(digitsOnly) ||
        RegExp(r'^\+?[1-9][0-9]{8,14}$').hasMatch(digitsOnly);
  }

  /// `DateTime.weekday` is 1–7 with Sunday last; the backend's
  /// `RecurringWeekdaysConfigDto` is 0–6 with Sunday first.
  static int toBackendWeekday(int dartWeekday) => dartWeekday % 7;
}
