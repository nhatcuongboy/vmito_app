import 'package:vmito_app/core/location/city_names.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Builds "Đã chọn 2 phường, 1 xã" (etc.) from the selected ward/commune
/// names, grouped by administrative type. Falls back to a plain count for
/// names that don't match a known prefix.
String wardSelectionSummary(AppLocalizations l10n, Set<String> wards) {
  if (wards.isEmpty) return '';
  final counts = countWardsByKind(wards);
  final parts = [
    if (counts[WardKind.ward]! > 0)
      l10n.citySelectorWardCountWard(counts[WardKind.ward]!),
    if (counts[WardKind.commune]! > 0)
      l10n.citySelectorWardCountCommune(counts[WardKind.commune]!),
    if (counts[WardKind.specialZone]! > 0)
      l10n.citySelectorWardCountSpecialZone(counts[WardKind.specialZone]!),
    if (counts[WardKind.other]! > 0)
      l10n.sessionFilterSelectedCount(counts[WardKind.other]!),
  ];
  return l10n.citySelectorWardsSelectedSummary(parts.join(', '));
}
