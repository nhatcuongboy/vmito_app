import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_fee_config.freezed.dart';
part 'session_fee_config.g.dart';

/// Mirrors `FeeType` in `vmito-fe/src/lib/api/types.ts`.
@JsonEnum(alwaysCreate: true)
enum FeeType {
  /// A fixed walk-in price, set per gender.
  @JsonValue('FIXED')
  fixed,

  /// Total cost divided evenly once the session ends.
  @JsonValue('SPLIT_EVENLY')
  splitEvenly,
}

/// How a session charges its players.
///
/// **All amounts are integer VND with no minor units.** Format them through
/// `Money.vnd`, never with string interpolation.
@freezed
abstract class SessionFeeConfig with _$SessionFeeConfig {
  const factory SessionFeeConfig({
    @Default(FeeType.fixed) FeeType feeType,
    int? maleFee,
    int? femaleFee,

    /// Set only for [FeeType.splitEvenly], and only once the host has entered
    /// the totals — usually after the session.
    int? splitTotal,
    int? splitPerPlayer,
    String? notes,
  }) = _SessionFeeConfig;

  factory SessionFeeConfig.fromJson(Map<String, dynamic> json) =>
      _$SessionFeeConfigFromJson(json);

  const SessionFeeConfig._();

  bool get isSplitEvenly => feeType == FeeType.splitEvenly;

  /// True when there is nothing concrete to show a player yet.
  bool get isUnpriced => isSplitEvenly
      ? splitPerPlayer == null && splitTotal == null
      : maleFee == null && femaleFee == null;

  /// True when both genders pay the same fixed price, so the UI can show one
  /// number instead of two.
  bool get hasSingleFixedPrice =>
      !isSplitEvenly && maleFee != null && maleFee == femaleFee;
}
