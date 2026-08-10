import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/session.dart';

part 'bulk_create_session.freezed.dart';
part 'bulk_create_session.g.dart';

/// The body of `POST /sessions/bulk` — one draft cloned across many dates.
///
/// Hand-written `toJson` for the same reason as [CreateSessionRequest]: it
/// nests that request verbatim as `baseSession`, and a generated serialiser
/// would not reuse its integer handling.
class BulkCreateSessionRequest {
  const BulkCreateSessionRequest({
    required this.mode,
    required this.baseSession,
    this.specificDates = const [],
    this.weekdays = const [],
    this.numberOfWeeks = 1,
    this.recurringStartDate,
  });

  final BulkCreationMode mode;
  final CreateSessionRequest baseSession;

  /// Full start datetimes, not bare dates: the backend keeps the time of day
  /// from each entry rather than re-deriving it from `baseSession`.
  final List<DateTime> specificDates;

  /// `0` is Sunday, matching `RecurringWeekdaysConfigDto`. Not Dart's
  /// `DateTime.weekday`, where Sunday is 7 — converting is the caller's job.
  final List<int> weekdays;

  /// Backend range is 1–52.
  final int numberOfWeeks;
  final DateTime? recurringStartDate;

  Map<String, dynamic> toJson() => {
    'mode': mode.wireValue,
    'baseSession': baseSession.toJson(),
    if (mode == BulkCreationMode.specificDates)
      'specificDates': {
        'dates': [
          for (final date in specificDates) date.toUtc().toIso8601String(),
        ],
      },
    if (mode == BulkCreationMode.recurringWeekdays)
      'recurringWeekdays': {
        'weekdays': weekdays,
        'numberOfWeeks': numberOfWeeks,
        if (recurringStartDate != null)
          'startDate': recurringStartDate!.toUtc().toIso8601String(),
      },
  };
}

/// One date the backend refused, so the UI can say which rather than failing
/// the whole batch silently.
@freezed
abstract class BulkSessionError with _$BulkSessionError {
  const factory BulkSessionError({String? date, String? error}) =
      _BulkSessionError;

  factory BulkSessionError.fromJson(Map<String, dynamic> json) =>
      _$BulkSessionErrorFromJson(json);
}

/// `POST /sessions/bulk` response. Partial success is normal — a date that
/// collides with an existing session is reported here, not thrown.
@freezed
abstract class BulkCreateSessionResult with _$BulkCreateSessionResult {
  const factory BulkCreateSessionResult({
    @Default(false) bool success,
    @Default(0) int sessionsCreated,
    @Default(<Session>[]) List<Session> sessions,
    @Default(<BulkSessionError>[]) List<BulkSessionError> errors,
  }) = _BulkCreateSessionResult;

  factory BulkCreateSessionResult.fromJson(Map<String, dynamic> json) =>
      _$BulkCreateSessionResultFromJson(json);
}
