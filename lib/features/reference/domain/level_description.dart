import 'package:freezed_annotation/freezed_annotation.dart';

part 'level_description.freezed.dart';
part 'level_description.g.dart';

/// The admin-authored blurb for one skill level.
///
/// The label (`Yếu-`, `TBY`, …) is **not** here — it comes from
/// `vmito_domain`'s static table, which never changes. Only the prose is
/// server-owned, so admins can reword it without an app release.
@freezed
abstract class LevelDescription with _$LevelDescription {
  const factory LevelDescription({
    required int level,
    @Default('') String description,
  }) = _LevelDescription;

  factory LevelDescription.fromJson(Map<String, dynamic> json) =>
      _$LevelDescriptionFromJson(json);
}
