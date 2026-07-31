import 'dart:convert';
import 'dart:io';

const _sourceFiles = <String, String>{
  'vi': 'vi.json',
  'en': 'en.json',
  'zh': 'cn.json',
};

/// Mobile ARB keys that have a direct semantic equivalent in the web bundle.
/// Keys not listed here are mobile-only copy and remain owned by the ARB file.
const _arbToWebPath = <String, String>{
  'appName': 'common.appName',
  'commonCancel': 'common.cancel',
  'commonConfirm': 'common.confirm',
  'commonSave': 'common.save',
  'commonClose': 'common.close',
  'commonLoading': 'common.loading',
  'commonSearch': 'common.search',
  'commonRetry': 'session.retry',
  'languageTitle': 'common.language',
  'languageVietnamese': 'common.vietnamese',
  'languageEnglish': 'common.english',
  'languageChinese': 'common.chinese',
  'authSignIn': 'auth.signin.signInButton',
  'authSignUp': 'auth.signin.signUp',
  'authSignOut': 'common.logout',
  'authEmail': 'auth.signin.email',
  'authPassword': 'auth.signin.password',
  'authForgotPassword': 'auth.signin.forgotPassword',
  'authContinueWithGoogle': 'auth.signin.continueWithGoogle',
  'authContinueWithFacebook': 'auth.signin.continueWithFacebook',
  'authContinueAsGuest': 'auth.signin.joinAsGuest',
  'authEmailRequired': 'auth.signin.emailRequired',
  'authEmailInvalid': 'auth.signin.invalidEmail',
  'authPasswordRequired': 'auth.signin.passwordRequired',
  'navHome': 'navigation.mainHome',
  'navSessions': 'navigation.sessions',
  'navTournaments': 'navigation.tournaments',
  'navNotifications': 'navigation.notifications',
  'navProfile': 'navigation.personal',
  'navFeed': 'navigation.newsfeed',
  'profileTitle': 'navigation.personal',
  'profileLanguage': 'common.displayLanguage',
  'feedTitle': 'navigation.newsfeed',
  'homeTitle': 'navigation.mainHome',
  'comingSoon': 'posts.comingSoon.badge',
  'sessionBrowseTitle': 'navigation.findSessions',
  'sessionEmpty': 'session.noSessionsFound',
  'sessionDetailTitle': 'session.sessionDetails',
  'sessionCourtsTitle': 'SessionDetail.courts',
  'sessionPlayersTitle': 'SessionDetail.playersTab.players',
  'sessionDescriptionTitle': 'session.description',
  'courtStatusPlaying': 'court.status.playing',
  'courtStatusEmpty': 'court.status.available',
  'feeTitle': 'fee.title',
  'feeNotConfigured': 'fee.noFee',
  'feeSplitAfterSession': 'fee.splitDescription',
  'feeMale': 'common.male',
  'feeFemale': 'common.female',
  'dateToday': 'session.today',
  'dateTomorrow': 'session.tomorrow',
  'level1': 'common.levelShorts.1',
  'level2': 'common.levelShorts.2',
  'level3': 'common.levelShorts.3',
  'level4': 'common.levelShorts.4',
  'level5': 'common.levelShorts.5',
  'level6': 'common.levelShorts.6',
  'level7': 'common.levelShorts.7',
  'level8': 'common.levelShorts.8',
  'level9': 'common.levelShorts.9',
  'level10': 'common.levelShorts.10',
};

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  final positional = arguments.where((arg) => !arg.startsWith('--')).toList();
  final sourceDirectory = Directory(
    positional.isEmpty ? '../vmito-fe/src/i18n/messages' : positional.single,
  );
  final assetDirectory = Directory('assets/i18n/web');

  if (!sourceDirectory.existsSync()) {
    stderr.writeln('Web message directory not found: ${sourceDirectory.path}');
    exitCode = 2;
    return;
  }

  if (!checkOnly) assetDirectory.createSync(recursive: true);

  var differs = false;
  for (final entry in _sourceFiles.entries) {
    final source = File('${sourceDirectory.path}/${entry.value}');
    final destination = File('${assetDirectory.path}/${entry.value}');
    final sourceBytes = source.readAsBytesSync();
    final decoded = jsonDecode(utf8.decode(sourceBytes));
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('${source.path} is not a JSON object');
      exitCode = 2;
      return;
    }

    if (checkOnly) {
      if (!destination.existsSync() ||
          !_sameBytes(sourceBytes, destination.readAsBytesSync())) {
        stderr.writeln('${destination.path} is out of sync');
        differs = true;
      }
    } else {
      destination.writeAsBytesSync(sourceBytes, flush: true);
      _syncArb(entry.key, decoded);
    }
  }

  if (differs) exitCode = 1;
}

void _syncArb(String locale, Map<String, dynamic> webMessages) {
  final arbFile = File('lib/l10n/app_$locale.arb');
  final arb = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
  for (final mapping in _arbToWebPath.entries) {
    final value = _readPath(webMessages, mapping.value);
    if (value is! String) {
      throw FormatException(
        'Expected ${mapping.value} to be a string in the $locale bundle',
      );
    }
    arb[mapping.key] = value;
  }
  arbFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
    flush: true,
  );
}

Object? _readPath(Map<String, dynamic> root, String path) {
  Object? current = root;
  for (final segment in path.split('.')) {
    if (current is! Map<String, dynamic>) return null;
    current = current[segment];
  }
  return current;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
