import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

part 'tournament_scoring_rules.freezed.dart';

/// Per-stage scoring rules, ported from vmito-fe `ScoringRulesCard.tsx`.
enum ScoringStage { group, knockout, finalRound }

@freezed
abstract class StageRules with _$StageRules {
  const factory StageRules({
    required String matchFormat,
    required int pointsToWin,
    required bool winByTwo,
    required int? pointCap,

    /// Knockout and final may inherit the previous stage; group never does.
    @Default(false) bool inherit,
  }) = _StageRules;

  const StageRules._();

  bool get isValid =>
      inherit ||
      (pointsToWin >= 1 &&
          pointsToWin <= 99 &&
          (pointCap == null || (pointCap! >= pointsToWin && pointCap! <= 99)));

  bool sameScoring(scoring.RallyScoringDefaults preset) =>
      preset.pointsToWin == pointsToWin &&
      preset.winByTwo == winByTwo &&
      preset.pointCap == pointCap;
}

typedef ScoringRulesByStage = Map<ScoringStage, StageRules>;

abstract final class TournamentScoringRules {
  static const Map<scoring.MatchFormat, String> _matchFormatWire = {
    scoring.MatchFormat.bestOf1: 'BEST_OF_1',
    scoring.MatchFormat.bestOf3: 'BEST_OF_3',
    scoring.MatchFormat.bestOf5: 'BEST_OF_5',
  };

  static String presetMatchFormat(scoring.RallyScoringDefaults preset) =>
      _matchFormatWire[preset.matchFormat]!;

  /// Preset id matching the rules, or null for custom values.
  static String? presetId(
    List<scoring.RallyScoringDefaults> presets,
    StageRules rules,
  ) => presets.where(rules.sameScoring).firstOrNull?.id;

  /// `initialFor`: a stage inherits only when it has neither a scoring nor a
  /// match-format override. The final's match format lives in
  /// `formatConfig.roundFormats.F`, not in a column.
  static ScoringRulesByStage initial(
    TournamentCategory category,
    scoring.RallyScoringDefaults defaults,
  ) {
    final group = StageRules(
      matchFormat: category.matchFormat ?? presetMatchFormat(defaults),
      pointsToWin: category.pointsToWin ?? defaults.pointsToWin,
      winByTwo: category.winByTwo ?? defaults.winByTwo,
      // The backend always serializes the cap column, so null is "no cap"
      // rather than "unset" — web only falls back to the default on undefined.
      pointCap: category.pointCap,
    );
    final knockoutFormat = category.eliminationMatchFormat;
    final knockout = StageRules(
      matchFormat: knockoutFormat ?? group.matchFormat,
      pointsToWin: category.knockoutPointsToWin ?? group.pointsToWin,
      winByTwo: category.knockoutWinByTwo ?? group.winByTwo,
      pointCap: category.knockoutPointCap,
      inherit:
          category.knockoutPointsToWin == null &&
          (knockoutFormat == null || knockoutFormat == group.matchFormat),
    );
    final finalFormat = roundFormats(category.formatConfig)['F'];
    return {
      ScoringStage.group: group,
      ScoringStage.knockout: knockout,
      ScoringStage.finalRound: StageRules(
        matchFormat: finalFormat ?? knockout.matchFormat,
        pointsToWin: category.finalPointsToWin ?? knockout.pointsToWin,
        winByTwo: category.finalWinByTwo ?? knockout.winByTwo,
        pointCap: category.finalPointCap,
        inherit:
            category.finalPointsToWin == null &&
            (finalFormat == null || finalFormat == knockout.matchFormat),
      ),
    };
  }

  /// Changes whenever a saved scoring column or the final's format changes —
  /// web's `categoryRuleKey`, used to re-seed the draft after a save.
  static String signature(TournamentCategory category) => [
    category.matchFormat,
    category.pointsToWin,
    category.winByTwo,
    category.pointCap,
    category.eliminationMatchFormat,
    category.knockoutPointsToWin,
    category.knockoutWinByTwo,
    category.knockoutPointCap,
    category.finalPointsToWin,
    category.finalWinByTwo,
    category.finalPointCap,
    roundFormats(category.formatConfig)['F'],
  ].join('|');

  /// `getEffectiveStageValues`: what a stage actually plays with.
  static StageRules effective(ScoringRulesByStage values, ScoringStage stage) {
    final rules = values[stage]!;
    if (stage == ScoringStage.group || !rules.inherit) return rules;
    final knockout = values[ScoringStage.knockout]!;
    final source = stage == ScoringStage.knockout || knockout.inherit
        ? values[ScoringStage.group]!
        : knockout;
    return source.copyWith(inherit: true);
  }

  static Map<String, String> roundFormats(Map<String, dynamic> formatConfig) {
    final raw = formatConfig['roundFormats'];
    if (raw is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is String &&
            _matchFormatWire.containsValue(value) &&
            key is String)
          key: value,
    };
  }

  /// `handleSave` payload. Inherited scoring columns are sent as null; the
  /// final's match format is kept in `roundFormats.F` only when it differs
  /// from the effective knockout format.
  static Map<String, dynamic> updatePayload(
    TournamentCategory category,
    ScoringRulesByStage values,
  ) {
    final group = values[ScoringStage.group]!;
    final knockout = values[ScoringStage.knockout]!;
    final finalRound = values[ScoringStage.finalRound]!;
    final formatConfig = {...category.formatConfig};
    final rounds = roundFormats(category.formatConfig);
    final knockoutFormat = effective(values, ScoringStage.knockout).matchFormat;
    if (finalRound.inherit || finalRound.matchFormat == knockoutFormat) {
      rounds.remove('F');
    } else {
      rounds['F'] = finalRound.matchFormat;
    }
    if (rounds.isEmpty) {
      formatConfig.remove('roundFormats');
    } else {
      formatConfig['roundFormats'] = rounds;
    }
    return {
      'matchFormat': group.matchFormat,
      'pointsToWin': group.pointsToWin,
      'winByTwo': group.winByTwo,
      'pointCap': group.pointCap,
      'eliminationMatchFormat': knockout.inherit
          ? group.matchFormat
          : knockout.matchFormat,
      'knockoutPointsToWin': knockout.inherit ? null : knockout.pointsToWin,
      'knockoutWinByTwo': knockout.inherit ? null : knockout.winByTwo,
      'knockoutPointCap': knockout.inherit ? null : knockout.pointCap,
      'finalPointsToWin': finalRound.inherit ? null : finalRound.pointsToWin,
      'finalWinByTwo': finalRound.inherit ? null : finalRound.winByTwo,
      'finalPointCap': finalRound.inherit ? null : finalRound.pointCap,
      'formatConfig': formatConfig,
    };
  }
}
