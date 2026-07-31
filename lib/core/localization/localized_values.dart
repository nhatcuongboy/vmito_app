import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

extension LocalizedValues on AppLocalizations {
  String apiError(ApiException error) {
    if (error.hasServerMessage) return error.message;
    return switch (error.kind) {
      ApiErrorKind.network => errorNetwork,
      ApiErrorKind.timeout => errorTimeout,
      ApiErrorKind.unauthorized => errorUnauthorized,
      ApiErrorKind.forbidden => errorForbidden,
      ApiErrorKind.notFound => errorNotFound,
      ApiErrorKind.validation => errorValidation,
      ApiErrorKind.server => errorServer,
      ApiErrorKind.cancelled => errorCancelled,
      ApiErrorKind.unknown => errorUnknown,
    };
  }

  String courtName(Court court) {
    final name = court.courtName?.trim();
    return name == null || name.isEmpty ? courtNumber(court.courtNumber) : name;
  }

  String playerName(SessionPlayer player) {
    final name = player.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final number = player.playerNumber;
    return number == null ? playerFallback : playerNumber(number);
  }

  String levelName(int level) => switch (level) {
    1 => level1,
    2 => level2,
    3 => level3,
    4 => level4,
    5 => level5,
    6 => level6,
    7 => level7,
    8 => level8,
    9 => level9,
    10 => level10,
    _ => '$level',
  };
}
