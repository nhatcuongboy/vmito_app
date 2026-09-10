import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

/// What the search screen hands back to Home when it closes.
sealed class HomeSearchOutcome {
  const HomeSearchOutcome();
}

/// Show the browse list filtered by a typed keyword.
final class HomeSearchQuery extends HomeSearchOutcome {
  const HomeSearchQuery(this.query);

  final String query;
}

/// Show the full list behind the search screen's featured section — the same
/// preset it previewed, so "see all" never shows a different set.
final class HomeSearchPreset extends HomeSearchOutcome {
  const HomeSearchPreset(this.tab);

  final HomeDiscoveryTab tab;
}
