/// Ports `getFullSizeAvatarUrl` from `vmito-fe/src/lib/utils/image.ts`.
///
/// OAuth avatars are stored as small thumbnails (Google `=s96-c` → 96px,
/// Zalo `s120-` → 120px); a full-screen preview needs a larger variant.
String fullSizeAvatarUrl(String url) {
  if (url.contains('googleusercontent.com')) {
    return url
        .replaceAll(RegExp(r'=s\d+(-c)?(?=$|\?)'), '=s512-c')
        .replaceAll(RegExp(r'/s\d+(-c)?/'), '/s512-c/');
  }
  if (url.contains('zadn.vn')) {
    return url.replaceAll(RegExp(r'//s\d+-'), '//s240-');
  }
  return url;
}
