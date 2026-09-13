import 'dart:convert';

/// An unsigned token whose payload carries [sub] — enough for code that only
/// reads the subject, never for anything that verifies a signature.
String fakeJwt(String sub) {
  String encode(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': sub})}.signature';
}
