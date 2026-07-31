import 'dart:convert';
import 'dart:io';

/// Loads characterization fixtures recorded from the TypeScript implementation.
///
/// The corpus in `fixtures/` is the contract between the two frontends: the
/// Dart suite and the JS suite read the same files, so a rule change has to
/// move both. See `docs/TESTING.md`.
List<Map<String, dynamic>> loadFixture(String relativePath) {
  final file = File('${_fixturesRoot.path}/$relativePath');
  if (!file.existsSync()) {
    throw StateError(
      'Missing fixture ${file.path}.\n'
      'Record it from the TypeScript with:\n'
      '  cd ../vmito-fe && npx tsx scripts/record-rally-fixtures.mts',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}

/// Walks up from the current directory to find `fixtures/`.
///
/// Tests run from the package directory under `dart test` and from the
/// workspace root under `flutter test`, so a fixed relative path breaks one of
/// them.
Directory get _fixturesRoot {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory('${dir.path}/fixtures');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Could not find fixtures/ above ${Directory.current.path}');
}
