Plan Migrate Icon Flutter App Sang Lucide Như vmito-fe
Summary
Migrate toàn bộ icon UI trong Flutter app từ Material Icons.* sang Lucide, dùng package flutter_lucide: ^1.11.0.
Giữ flutter_svg cho brand/custom icons như Google, Facebook, Zalo, logo, QR/payment assets vì web app cũng không dùng Lucide cho toàn bộ nhóm này.
Tạo một lớp icon trung tâm để code Flutter không import flutter_lucide rải rác và dễ đồng bộ với vmito-fe.
Key Changes
Cập nhật pubspec.yaml:Thêm flutter_lucide: ^1.11.0.
Giữ flutter_svg.
Chạy flutter pub get để cập nhật pubspec.lock.

Tạo lib/core/theme/app_icons.dart:Export các IconData semantic như AppIcons.home, sessions, feed, notifications, profile, venue, clubs, search, close, plus, trash, edit, calendar, clock, mapPin, users, user, trophy, sparkles, settings, share, externalLink, chevronRight.
Dùng Lucide làm default; chỉ để fallback Material cho icon không có Lucide tương đương rõ ràng.

Migrate toàn bộ Icons.* trong lib/**/*.dart:Navigation/shell/drawer trước: AppShell, SlideOutMenu.
Sau đó các feature: auth, home, session, venue, social, tournament, payment, court, hosting, profile, notifications.
Với selected/unselected nav icon: dùng cùng Lucide glyph, phân biệt bằng color, weight/tint/container state thay vì filled vs outlined Material.

Chuẩn hóa usage:File app chỉ dùng Icon(AppIcons.xxx) hoặc helper widget nếu cần kích thước/màu lặp lại.
Không import trực tiếp package:flutter_lucide/flutter_lucide.dart ngoài app_icons.dart, trừ khi có lý do đặc biệt.
Không migrate brand/social/logo/payment-provider icons sang Lucide nếu làm mất nhận diện thương hiệu.

Icon Mapping Defaults
home/home_outlined → house
sports_tennis/session/court → dumbbell hoặc badge fallback nếu Lucide thiếu icon badminton/tennis phù hợp; ưu tiên icon đang dùng tương tự web nếu có trong vmito-fe.
article/feed → newspaper
notifications → bell
person → user
groups/people → users
location/place → map_pin
emoji_events/workspace_premium → trophy hoặc award
schedule/access_time/timer → clock
search/search_off → search / search_x
close → x
add → plus
delete → trash_2
edit → pencil
share/ios_share → share_2
visibility/visibility_off → eye / eye_off
warning/error → triangle_alert / circle_alert
check/check_circle → check / circle_check
settings/tune/filter → settings, sliders_horizontal, list_filter
Test Plan
Run flutter pub get.
Run dart analyze and fix all compile/lint issues from renamed imports or missing icon constants.
Run existing Flutter tests with flutter test.
Smoke-test key screens visually: bottom nav, drawer, auth forms, browse sessions, session detail, venue list/detail, club screens, host court/session management, payment screens.
Verify no remaining unintended Icons.* usage with rg "Icons\\." lib; allowed exceptions must be documented in app_icons.dart.
Assumptions
Package choice is flutter_lucide, current latest stable on pub.dev is 1.11.0.
Migration target is toàn bộ app, not only core screens.
Lucide is the visual source of truth for generic UI icons because vmito-fe uses lucide-react heavily.
Brand/custom icons remain SVG or existing asset implementations.
Sources checked: flutter_lucide on pub.dev, Lucide, local vmito-fe/package.json, local Flutter pubspec.yaml.