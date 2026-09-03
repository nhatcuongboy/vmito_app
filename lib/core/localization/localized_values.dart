import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

extension LocalizedValues on AppLocalizations {
  /// Maps known host-session API failures to app-localized copy.
  ///
  /// The API currently returns this condition as an English message rather
  /// than a machine-readable error code. Keep the contract match here, at the
  /// presentation mapping boundary, so the raw server text never reaches the
  /// user.
  String hostSessionManagementError(Object? error) {
    if (error case ApiException(
      statusCode: 400,
      message: 'Cannot start a session with no players',
    )) {
      return hostManageStartRequiresPlayer;
    }
    return error is ApiException ? apiError(error) : hostManageActionFailed;
  }

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

  String courtPair(int pairNumber) => switch (pairNumber) {
    1 => courtPair1,
    2 => courtPair2,
    _ => switch (localeName) {
      'vi' => 'Cặp $pairNumber',
      'zh' => '第$pairNumber组',
      _ => 'Pair $pairNumber',
    },
  };

  String get courtTooltipGender => switch (localeName) {
    'vi' => 'Giới tính',
    'zh' => '性别',
    _ => 'Gender',
  };

  String get courtTooltipLevel => switch (localeName) {
    'vi' => 'Trình độ',
    'zh' => '水平',
    _ => 'Level',
  };

  String get courtTooltipMatchesPlayed => switch (localeName) {
    'vi' => 'Trận đã chơi',
    'zh' => '已比赛',
    _ => 'Matches played',
  };

  String get courtTooltipWaitTime => switch (localeName) {
    'vi' => 'Thời gian chờ',
    'zh' => '等待时间',
    _ => 'Wait time',
  };

  String formatWaitTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return switch (localeName) {
      'vi' => hours > 0 ? '${hours}g${mins}p' : '${mins}p',
      'zh' => hours > 0 ? '$hours时$mins分' : '$mins分',
      _ => hours > 0 ? '${hours}h${mins}m' : '${mins}m',
    };
  }

  String playerGender(Gender? gender) => switch (gender) {
    Gender.male => genderMale,
    Gender.female => genderFemale,
    Gender.other => genderOther,
    null => 'N/A',
  };
}
