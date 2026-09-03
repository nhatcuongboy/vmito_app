import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_summary.freezed.dart';
part 'favorite_summary.g.dart';

/// What can be favorited. The wire values are the backend's `FavoriteType`
/// enum and appear in the URL path, so they are upper-case by contract.
enum FavoriteType {
  session('SESSION'),
  venue('VENUE'),
  club('CLUB'),
  tournament('TOURNAMENT');

  const FavoriteType(this.wireValue);

  final String wireValue;

  static FavoriteType fromWire(String? value) => FavoriteType.values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => FavoriteType.session,
  );
}

/// `GET /favorites/:type/:targetId/summary`.
@freezed
abstract class FavoriteSummary with _$FavoriteSummary {
  const factory FavoriteSummary({
    @Default(false) bool isFavorite,
    @Default(0) int favoriteCount,

    /// Whether this caller may list *who* favorited the target. Hosts and
    /// admins can; everyone else gets the count only.
    @Default(false) bool canViewUsers,
  }) = _FavoriteSummary;

  factory FavoriteSummary.fromJson(Map<String, dynamic> json) =>
      _$FavoriteSummaryFromJson(json);
}
