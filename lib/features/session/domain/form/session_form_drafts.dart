import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_form_drafts.freezed.dart';

/// Where the session happens, as the form models it.
///
/// Distinct from `SessionLocationPayload`: this is the toggle the user flips,
/// which must survive switching back and forth without losing the other side's
/// input. The payload type is built from it only at submit time.
enum SessionLocationKind { venue, custom }

/// Which strategy the bulk-create card is on. String values match
/// `BulkCreationMode` in `vmito-be/src/sessions/dto/bulk-session.dto.ts`.
enum BulkCreationMode {
  specificDates('specific-dates'),
  recurringWeekdays('recurring-weekdays');

  const BulkCreationMode(this.wireValue);

  final String wireValue;
}

int _draftKeySeed = 0;

/// A process-unique key for a draft row.
///
/// Monotonic rather than random: uniqueness only has to hold within one open
/// form, and a counter makes a failing test's keys readable.
String nextDraftKey() => 'draft-${_draftKeySeed++}';

/// One row of the courts card.
///
/// [key] is a stable identity for the widget list. Court rows are added,
/// removed from the middle and reordered, and keying the list by index makes
/// Flutter reuse the wrong `TextEditingController` after a deletion — the
/// classic symptom being court 3's name appearing on court 2 after deleting
/// court 2.
@freezed
abstract class SessionCourtDraft with _$SessionCourtDraft {
  const factory SessionCourtDraft({
    required String key,
    @Default(0) int courtNumber,
    @Default('') String courtName,

    /// Set on rows loaded from an existing session, so an edit updates the
    /// court instead of replacing it and orphaning its match history.
    String? courtId,
  }) = _SessionCourtDraft;

  const SessionCourtDraft._();

  /// The `CourtConfigDto` shape. `direction` is always `HORIZONTAL`: the web
  /// form carries the field but renders no control for it.
  Map<String, dynamic> toJson() => {
    if (courtId != null) 'id': courtId,
    'courtNumber': courtNumber,
    if (courtName.trim().isNotEmpty) 'courtName': courtName.trim(),
    'direction': 'HORIZONTAL',
  };
}

/// One picture in the advanced card's gallery.
///
/// Uploads happen when the image is picked, not at submit, so a draft passes
/// through three states: local-only while uploading, remote once the upload
/// returns, and local-with-error if it failed.
@freezed
abstract class SessionImageDraft with _$SessionImageDraft {
  const factory SessionImageDraft({
    required String key,

    /// On-device path. Kept after upload so the thumbnail never flickers to a
    /// network fetch of an image already on screen.
    String? localPath,
    String? url,

    /// Cloudinary id. Also the banner's identity — see `bannerPublicId` on the
    /// form state.
    String? publicId,
    @Default(false) bool isUploading,
  }) = _SessionImageDraft;

  const SessionImageDraft._();

  /// Only uploaded images can be sent; a still-uploading draft has no URL.
  bool get isReady => (url?.isNotEmpty ?? false) && !isUploading;
}
