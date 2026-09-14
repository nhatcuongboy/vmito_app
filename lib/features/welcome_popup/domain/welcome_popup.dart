import 'package:freezed_annotation/freezed_annotation.dart';

part 'welcome_popup.freezed.dart';
part 'welcome_popup.g.dart';

/// Mirrors `IWelcomePopup` in `vmito-fe/src/lib/api/types.ts`. No `locale`
/// field — content is a single global string, not per-locale.
@freezed
abstract class WelcomePopup with _$WelcomePopup {
  const factory WelcomePopup({
    required String id,
    required String title,
    required String description,
    String? imageUrl,
    String? ctaLabel,
    String? ctaUrl,
    @Default(true) bool isActive,
    @Default(0) int displayOrder,
    DateTime? startDate,
    DateTime? endDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WelcomePopup;

  const WelcomePopup._();

  factory WelcomePopup.fromJson(Map<String, dynamic> json) =>
      _$WelcomePopupFromJson(json);

  /// Equivalent of the web store's `versionKey` — dismissal is tracked per
  /// this token, so an admin edit (which bumps `updatedAt`) reshows the
  /// popup even to users who already dismissed the earlier version.
  String get versionToken => '$id:${updatedAt.toIso8601String()}';
}
