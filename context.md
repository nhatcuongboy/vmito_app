# Kế hoạch port Vmito Web → Flutter App (iOS + Android)

## Context

Vmito hiện là web app Next.js 15 (`vmito-fe`) quản lý kèo cầu lông / pickleball, giải đấu, club và thuê sân — **~198.700 dòng** trong `src/`, 842 file TS/TSX, 95 page route, 3 locale (vi/en/cn).

Điều kiện thuận lợi quyết định: **backend là NestJS riêng biệt (`vmito-be`), frontend chỉ là REST + Socket.IO client thuần**. Cả app chỉ có duy nhất một Next route handler (`/api/ai/chat` — proxy che API key Gemini). Nghĩa là Flutter app dùng lại nguyên 100% API hiện có, không phải viết lại backend logic nào.

**Mục tiêu**: app Flutter native cho iOS + Android, ship được từng phase độc lập, bắt đầu bằng lợi thế native rõ rệt nhất — quét QR vào kèo, xem sân trực tiếp, và **gọi sân bằng giọng nói + push notification** (web hiện không làm được khi tab đóng).

**Quyết định đã chốt:**
1. Phạm vi: **mobile-first companion** — admin/OBS overlay/scoreboard màn hình lớn/SEO pages **giữ trên web**.
2. Stack: **Riverpod 2 + freezed + dio + go_router**.
3. Backend **được phép sửa** (thêm FCM device token, chuẩn hoá envelope, expose OpenAPI).
4. Release đầu tiên: **join funnel + xem sân trực tiếp**.

---

## Phạm vi thực tế

**Ngân sách màn hình đã kiểm chứng**: 95 web page − 16 admin − 2 OBS overlay − scoreboard − showcase − `san-cau-long/[slug]` − `[...slug]` − root redirect − 5 page dead/stub = **~66 screen native**. Đây là con số cần plan theo, không phải 95.

Về khối lượng component: `src/components/` là 492 file / 139.707 dòng, nhưng **không phải port hết** — riêng `src/components/ui/` (12.431 dòng, 72 file) là wrapper Chakra và bị xoá sạch, thay bằng Material/Cupertino + ~20 atom.

---

## Tech stack

### Core (P0)

| Package | Thay thế cái gì |
|---|---|
| `flutter_riverpod` + `riverpod_annotation` ^2.6 | 14 Zustand store + 6 React context |
| `dio` ^5.7 | axios ([base.ts](src/lib/api/base.ts), 242 dòng) |
| `freezed_annotation` + `json_annotation` | TS interface / discriminated union |
| `go_router` ^14.6 | Next App Router + [routes.ts](src/constants/routes.ts) |
| `flutter_secure_storage` ^9.2 | localStorage `auth-storage` → Keychain/Keystore |
| `shared_preferences` ^2.3 | localStorage `user-preferences`, filter, tour |
| `socket_io_client` ^3.0 | `socket.io-client` (protocol Socket.IO v4) |
| `flutter_localizations` + `intl` | `next-intl`, **và thay cả dayjs + date-fns** |
| `timezone` ^0.9 | giờ session theo `Asia/Ho_Chi_Minh` |
| `firebase_core` + `firebase_messaging` | **mới** — hiện chưa có push thật |
| `firebase_crashlytics` + `firebase_analytics` | mới |
| `flutter_local_notifications` ^18 | [notifications.ts](src/utils/notifications.ts) (31 dòng, chỉ foreground) |
| `app_links` ^6.3 | universal/app links cho share + notification tap |
| `flutter_web_auth_2` ^4.0 | OAuth redirect kiểu `<a href>` hiện tại |
| `sign_in_with_apple` ^6.1 | **mới, App Store bắt buộc** (xem §Apple) |
| `connectivity_plus`, `package_info_plus`, `url_launcher` | offline banner, force-update gate, tel:/map |

### Theo feature

| Package | Phase | Thay thế |
|---|---|---|
| `mobile_scanner` ^6.0 | P1 | `@zxing/library` / [QRScanner.tsx](src/components/QRScanner.tsx) |
| `qr_flutter` ^4.1 | P1 | `qrcode` |
| `flutter_tts` ^4.2 | P1 | `SpeechSynthesisUtterance` vi-VN |
| `just_audio` + `audio_session` | P1 | `useUniversalVmitoAudio` (249 dòng hack iOS AudioContext → ~20 dòng) |
| `skeletonizer` ^1.4 | P1 | 808 dòng skeleton component |
| `cached_network_image` ^3.4 | P1 | next/image + Cloudinary transform URL |
| `infinite_scroll_pagination` ^5.0 | P1 | `useInfiniteScroll` + `react-intersection-observer` |
| `image_picker` + `flutter_image_compress` | P2 | `browser-image-compression` |
| `flutter_form_builder` + `form_builder_validators` | P2 | `react-hook-form` + `zod` |
| `flutter_widget_from_html_core` ^0.15 | P2 | `RichTextDisplay` (render HTML TipTap sẵn có) |
| `photo_view` ^0.15 | P2 | `AppLightbox` |
| `dio_cache_interceptor` + hive store | P2 | mới — read cache cho hot GET |
| `fl_chart` ^0.69 | P3 | `recharts` (chỉ 2 file) |
| `csv` + `file_picker` + `open_filex` | P3 | `papaparse` / xlsx export |
| `google_maps_flutter` ^2.10 | P4 | `@react-google-maps/api` |
| `flutter_google_places_sdk`, `geolocator`, `permission_handler`, `flutter_svg` | P4 | places autocomplete, geolocation, custom pin |
| `share_plus` + `path_provider` + `gal` | P4 | share card PNG (`modern-screenshot` → `RepaintBoundary.toImage()`) |
| `showcaseview` ^4.0 | P8 | `driver.js` + `components/tour/` (718 dòng) |
| `flutter_animate` ^4.5 | P8 | `framer-motion` (dùng mỏng) |

**Dùng built-in, KHÔNG thêm dependency**: `RefreshIndicator` (PullToRefresh) · `ReorderableListView` + `Draggable`/`DragTarget` (thay toàn bộ `@dnd-kit/*`) · `InteractiveViewer` (pan/zoom bracket) · `RepaintBoundary` (screenshot).

### Dev / codegen

`build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `riverpod_lint` + `custom_lint`, `very_good_analysis`, `swagger_dart_code_generator`, `melos`, `mocktail`, **`alchemist`** (golden test ổn định trên CI — `matchesGoldenFile` thuần sẽ flake với court/bracket vẽ tay), **`patrol`** (E2E), `flutter_launcher_icons`, `flutter_native_splash`, `lefthook`. Khuyến nghị thêm **`shorebird`** code push để hotfix P1 không phải chờ review.

---

## Kiến trúc project

**Feature-first, melos workspace, 3 package dùng chung + 1 app.**

Lý do tách package thay vì một app duy nhất: `vmito_domain` phải là **pure Dart không phụ thuộc Flutter** để test thuật toán chạy `dart test` trong ~2s và analyzer chặn được việc algorithm import UI; `vmito_api` cô lập ~180 DTO generated để build_runner không invalidate incremental build của app; `vmito_ui` là nơi 2 widget khó thật sự (court, bracket) sống cùng golden test riêng.

```
vmito-app/
├── melos.yaml, pubspec.yaml           # pub workspace
├── openapi/openapi.json               # COMMIT — contract artifact export từ vmito-be
├── fixtures/                          # JSON golden — dùng chung cho test Dart VÀ test JS
├── tool/{json_to_arb,l10n_check,gen_api,record_fixtures}.dart
├── packages/
│   ├── vmito_domain/                  # PURE DART. không flutter, không dio.
│   │   ├── lib/src/{scoring,tournament,schedule,match,pricing,text,reference}/
│   │   └── test/                      # ← 1.333 dòng test JS port sang ĐÂY TRƯỚC TIÊN
│   ├── vmito_api/
│   │   ├── lib/src/client/{api_client,auth_interceptor,error_policy,dedup,envelope}.dart
│   │   ├── lib/src/generated/         # build_runner output, gitignore + commit checksum
│   │   └── lib/src/services/          # 34 file, đặt tên 1:1 với src/lib/api/*.service.ts
│   └── vmito_ui/
│       ├── lib/src/{theme,atoms}/
│       ├── lib/src/court/             # BadmintonCourtView (CustomPaint + Stack)
│       ├── lib/src/bracket/           # BracketView (CustomPaint + InteractiveViewer)
│       └── test/goldens/
└── app/lib/
    ├── core/{env,router,storage,socket,notifications,error,format,permissions,analytics}/
    ├── l10n/{app_vi,app_en,app_cn}.arb
    └── features/<feature>/{data,application,presentation}/
```

Mỗi feature: `data/` (repository trên service của `vmito_api`), `application/` (Riverpod notifier — chỗ Zustand store hạ cánh), `presentation/`. Chỉ dùng đủ 3 layer khi feature >5 screen. Enforce ranh giới import bằng `custom_lint`: `app` import tất cả → `vmito_api` chỉ import `vmito_domain` → `vmito_domain` không import gì.

### Map 14 Zustand store + 6 context → 12 provider (bỏ 5)

| Nguồn | Đích |
|---|---|
| `useAuthStore` | `authControllerProvider` — sealed `AuthState`: Unauthenticated / Guest / Authenticated. Token → **secure storage**, không bao giờ prefs |
| `useAppStore` (global error modal) | `apiErrorBusProvider` + `AppErrorListener` |
| `useCourtStore` (4 modal flag + 7 loading flag) | **BỎ** — modal thành `showModalBottomSheet` await, loading flag thành `AsyncValue` |
| `usePreferenceStore` + `useViewModeStore` + `useCourtDisplayModeStore` | **gộp 3 → 1** `preferencesProvider` |
| `useCourtCallStore` | `courtCallProvider` + root `Overlay` — critical path P1 |
| `SocketContext` (428) | `sessionSocketProvider` (keepAlive) + typed event stream |
| `SidebarContext`, `TopBarSearchContext` | **BỎ** — desktop-only |

Viết provider theo style `@riverpod` codegen dù pin Riverpod 2 → migrate 3.x sau này thành cơ học.

---

## Thứ tự ưu tiên các phase

Thang effort (quy đổi 1 dev): **S** ≤1 tuần · **M** 2–4 tuần · **L** 5–8 tuần · **XL** 9+ tuần. Tổng ≈ **60 dev-week** → ~7–8 tháng với 2 Flutter dev + backend part-time. Sai số ±30%.

Nguyên tắc xuyên suốt: **mỗi phase phải ship độc lập được**. Nếu một phase trượt, release trước vẫn đang sống trên store.

### P0-A — Nền tảng & hạ tầng · **L**

App rỗng nhưng thật: auth được, gọi API được, giữ socket, localize, route, và ship lên TestFlight/Internal Testing.

Gồm: melos workspace 4 package · `dart-define-from-file` cho 3 flavor dev/stg/prod · `ApiClient` với full interceptor stack · envelope handling · pipeline OpenAPI codegen + commit `openapi.json` · `AuthState` sealed kể cả guest · secure storage · go_router skeleton + port `AppRoutes` · design token + ~20 atom · pipeline ARB + `tool/l10n_check.dart` · 2 socket service với reconnect + room replay · Firebase + FCM registration · Crashlytics · force-update gate · CI (analyze/test/golden/l10n/codegen-drift).

File tham chiếu: [base.ts](src/lib/api/base.ts) · [apiError.ts](src/lib/api/apiError.ts) · [types.ts](src/lib/api/types.ts) (2.095 dòng) · [useAuthStore.ts](src/stores/useAuthStore.ts) · [SocketContext.tsx](src/contexts/SocketContext.tsx) · [useTournamentSocket.ts](src/hooks/useTournamentSocket.ts) · [routes.ts](src/constants/routes.ts) · `scripts/check-i18n.js` · [feature-flags.ts](src/constants/feature-flags.ts) (`PLAYER_VIP_ENABLED`).

**Việc backend**: bật `@nestjs/swagger` + CLI plugin, publish `openapi.json` trong CI · chuẩn hoá `/auth/refresh` và `/auth/register` về envelope `{success,data}` · `POST /notifications/devices` + `DELETE /notifications/devices/:token` · allowlist `vmito://auth/callback` làm `returnUrl` · `POST /auth/apple` · `DELETE /users/me`.

**Exit criteria**: `melos run test` xanh; `vmito_domain` có 0 Flutter dep (lint enforce) · login → token vào Keychain → GET có auth → 401 → single-flight refresh → retry OK, có test bắn **5 request 401 đồng thời** và assert **đúng 1** lần gọi `/auth/refresh` · test `dedupGet`: 3 GET giống nhau đồng thời → 1 network call, key độc lập thứ tự param · socket connect được cả khi authenticated **và** guest token rỗng; ngắt wifi → reconnect → set lại token → replay `join_user_room` + toàn bộ room · `l10n_check` fail CI khi cố tình lệch key · build signed TestFlight + Internal Testing từ CI theo tag · CI fail khi `openapi.json` regenerate ra khác.

### P0-B — Package thuật toán + harness kiểm chứng · **M** · *chạy song song P0-A*

Toàn bộ ~2.900 dòng business logic thuần sang Dart, **chứng minh giống hệt JS, TRƯỚC KHI viết UI đầu tiên**. Đây là việc rẻ nhất và đòn bẩy cao nhất của cả dự án — không được hoãn.

Thứ tự port = thứ tự giá trị:
[rally.ts](src/lib/scoring/rally.ts) (260 — rule cascade GROUP→KNOCKOUT→FINAL fallback ngược lên, match→category→sport profile; `applyDelta` mirror điểm sang player3/4 và tự tạo set kế) → [schedule-generator.ts](src/utils/schedule-generator.ts) (296 — greedy court×slot, `isTeamBusy` interval overlap) → [standings.ts](src/utils/standings.ts) (313 — tiebreak 5 tầng) → [match-result-utils.ts](src/utils/match-result-utils.ts) (276 — normalize 5 dạng score legacy; `winnerIds` là nguồn chuẩn, không phải `position`) → [bracketSlots.ts](src/lib/tournament/bracketSlots.ts) (217) → [podium.ts](src/lib/tournament/podium.ts) (222) → [match-repeat-warning.ts](src/utils/match-repeat-warning.ts) (228 — pair group phụ thuộc `CourtDirection`: HORIZONTAL `[0,1]v[2,3]`, VERTICAL `[0,2]v[1,3]`) → [auto-assign.ts](src/utils/auto-assign.ts) (311) → [round-robin.ts](src/utils/round-robin.ts) (172) → [session-player-ranking.ts](src/utils/session-player-ranking.ts) (109) → [pricing-utils.ts](src/components/venue/pricing/pricing-utils.ts) (293) → [schedule-validation.ts](src/components/venue-rental/schedule-validation.ts) → helper (`venue-helpers` 229, `session-helpers` 151, `time-helpers` 143, `slugify` 104 dấu tiếng Việt, `session-join-helpers` 82, `teamLabel` 138, `sports` 119, `codes` 96) → reference table (`levels` 106, `vietnam-locations` 306, `banks` 139) → [content.ts](src/lib/notifications/content.ts) (215) + [routing.ts](src/lib/notifications/routing.ts) (86).

**Phương pháp** — phần quan trọng nhất: repo hiện có **10 file test / 1.333 dòng** (`standings` 264, `auto-assign` 219, `pricing-utils` 148, `round-robin` 147, `schedule-validation` 110, `match-repeat-warning` 98, `club-venue-schedule` 98, `session-player-ranking` 95, `resultsRealtime` 85, `teamRoster` 69). Port nguyên văn các suite này trước. Nhưng `rally`, `schedule-generator`, `bracketSlots`, `podium`, `match-result-utils` — 5 module giá trị cao nhất — **hoàn toàn chưa có test**, nên phải tự tạo oracle bằng **golden-master characterization test**: viết script Node dùng-một-lần drive code TS hiện tại với input sinh tự động + input thật, dump cặp `{input, output}` vào `fixtures/`, commit, rồi assert Dart tái tạo đúng từng byte. Sau đó **sửa test JS đọc cùng thư mục `fixtures/`** → hai implementation bị ghim vào một corpus, không thể lệch âm thầm.

**Exit criteria**: coverage `vmito_domain` ≥90%, `dart test` <5s · 10 suite JS đều có bản Dart pass · ≥200 fixture case cho rally (best-of 1/3/5 × GROUP/KNOCKOUT/FINAL × đơn/đôi × biên set-complete/match-point) · `PlayerLevel` model là **`int`, không bao giờ là Dart enum** (giá trị không liền mạch: 1–8 rồi 9=BEGINNER_MINUS, 10=BEGINNER_PLUS) kèm test assert 9/10 sort *dưới* 1 · cả 2 suite JS + Dart chạy trong CI từ `fixtures/`.

### P1 — Release 1.0: join funnel + xem sân trực tiếp · **L**

MVP đã chọn. Người chơi quét QR ở sân, join, thấy bảng sân trực tiếp, và được **gọi vào sân bằng giọng nói**.

~14 screen: splash/bootstrap · sign in (email + Google + Facebook + **Apple**) · sign up · forgot/reset password · OAuth callback handler · home (kèo của tôi + CTA join) · browse session **lite** (search + ngày + môn + khoảng cách — bộ filter 18 field để P2) · public session detail · quét QR / nhập code · guest join + register · màn xem session trực tiếp (chỉ tab Courts) · **overlay gọi sân full-screen + TTS vi-VN 3 lần** · notification list cơ bản · settings-lite (ngôn ngữ, bật/tắt thông báo, logout, **xoá tài khoản**).

File tham chiếu: [join/page.tsx](src/app/[locale]/join/page.tsx) (601) · [guest/join/status/page.tsx](src/app/[locale]/guest/join/status/page.tsx) (784) · [BadmintonCourt.tsx](src/components/court/BadmintonCourt.tsx) (767) + `CourtPlayer.tsx` (363) + `PlayerTooltip.tsx` (328) · [SocketContext.tsx](src/contexts/SocketContext.tsx#L333-L395) — **đọc kỹ block này, timing TTS chính xác nằm ở đây** · [useCourtCallStore.ts](src/stores/useCourtCallStore.ts) · [usePlayerSession.ts](src/hooks/usePlayerSession.ts) · [FindSessionList.tsx](src/components/session/FindSessionList.tsx) (1.239) + [BaseSessionCard.tsx](src/components/session/BaseSessionCard.tsx) (1.482) — **redesign cho mobile, KHÔNG dịch nguyên**.

**Widget khó duy nhất ở phase này**: `BadmintonCourtView` trong `vmito_ui`. Đã verify trong source: `aspectRatio = 13.4 / 6.1` ([BadmintonCourt.tsx:66](src/components/court/BadmintonCourt.tsx#L66)), 3 mode `manage|view|selection`, 2 direction HORIZONTAL/VERTICAL. Làm bằng `CustomPaint` vẽ line + `Stack`/`Positioned` cho 4 slot + `AnimatedSwitcher` cho overlay pre-selected + `Ticker` 1s cho elapsed time. **Direction là một phép biến đổi toạ độ, không phải 2 widget tree.** Golden test 3 mode × 2 direction × 0–4 player ≈ 24 golden.

Đã verify block gọi sân ([SocketContext.tsx](src/contexts/SocketContext.tsx)): filter `data.userId === userId`, hiện modal, gửi system notification, rồi TTS `"Mời bạn vào sân số ${courtNumber}"` lang `vi-VN` rate 1.0, phát 3 lần cách nhau 1.500ms qua chuỗi `onend`.

**Việc backend**: payload FCM cho court call (`notification` + `data`, `apns-priority: 10`, `interruption-level: time-sensitive`, Android channel `court_call` importance max + custom sound) · `DELETE /users/me` · file app-links (`apple-app-site-association`, `assetlinks.json`) serve từ vmito.com — **đây là việc ở repo web**, cần một deploy cycle nên phải mở ticket từ P0.

**Exit criteria**: QR → join → thấy bảng sân <10s trên Android tầm trung mạng 4G · gọi sân: app **foreground** → overlay + TTS tiếng Việt 3 lần cách 1,5s; app **background/khoá máy** → push time-sensitive có custom sound, tap vào deep-link đúng tab Courts của session · luồng guest (không token) chạy trọn vẹn **không có toast 401 nào** · cả 4 phương thức auth hoạt động, Apple Sign-In có và chạy được · xoá tài khoản đến được trong ≤3 tap từ settings · `patrol` E2E xanh cho cả funnel với fake backend · **cả 2 store approve**, review note kèm demo account **và** join code của một session demo đang chạy.

### P2 — Vòng đời người chơi · **L**

Người chơi không cần mở web nữa. Gồm: browse session đầy đủ (18 filter, saved filter; map để P4) · session detail đủ 5 tab (Overview/Courts/Players/Matches/Fees) thành `TabBar` thật, bỏ `?tab=N` · kèo của tôi (sắp tới/đã join/đã xong) · luồng xin join + trạng thái · xem phí + submit chuyển khoản (upload ảnh proof) · notification center đầy đủ + badge unread · profile cá nhân + edit + upload avatar/cover · favorites · pipeline upload ảnh.

Tham chiếu: [useSessionFilterStore.ts](src/stores/useSessionFilterStore.ts) · [useNotificationStore.ts](src/stores/useNotificationStore.ts) · [NotificationBell.tsx](src/components/ui/NotificationBell.tsx) (1.204 → tách thành 1 badge + 1 screen) · [image.ts](src/lib/utils/image.ts) (gồm `getFullSizeAvatarUrl` rewrite Google `=s96-c`→`=s512-c`, Zalo `//s120-`→`//s240-`) · [cloudinary/utils.ts](src/lib/cloudinary/utils.ts) · [useImageUpload.ts](src/hooks/useImageUpload.ts).

**Exit criteria**: mọi screen role player trên web đều có bản mobile · upload ảnh nén ≤1MB / 1920px trước multipart (parity với `browser-image-compression`) và thành công trên cả 8 upload endpoint · deep link notification resolve đúng cho cả ~35 type (test table-driven trên `NotificationRouter`) · read cache hot-GET + banner "cập nhật X giây trước" · offline: mọi screen đọc của P2 render được data cache kèm banner stale.

### P3 — Host quản lý session · **XL**

Host chạy trọn một buổi từ điện thoại, ngay tại sân. Gồm: tạo session (form + AI-assisted) · edit/clone/cancel · quản lý tab Courts (gán/đổi/xoá người, start/end match, **gọi `GET /courts/{id}/suggested-players`**) · quản lý roster, check-in, waitlist · duyệt yêu cầu join · lịch sử match · cấu hình phí (FIXED theo giới tính / SPLIT_EVENLY) · sổ thu chi: approve/reject/bulk-approve, payment settings (bank account + ảnh QR) · chi phí session · dashboard transaction · cảnh báo trùng cặp hiển thị trên sân.

> **Footgun phải nhớ**: thuật toán "ai vào sân tiếp" là **SERVER-SIDE** (`GET /courts/{id}/suggested-players?topCount&useAi&language&matchType`). App chỉ render, không tính. [auto-assign.ts](src/utils/auto-assign.ts) client-side **chỉ dùng cho chia bảng giải đấu**. Ghi rõ để không ai "port" matchmaking.

Tham chiếu: [host/sessions/[id]/page.tsx](src/app/[locale]/host/sessions/[id]/page.tsx) (477) · [host/transactions/page.tsx](src/app/[locale]/host/transactions/page.tsx) (914) · `src/components/session/` (41.537 dòng / 129 file — phần lớn phase này) · [useCourtsTabActions.ts](src/hooks/useCourtsTabActions.ts) (340) · [useSessionManagement.ts](src/hooks/useSessionManagement.ts) (186) · [useCourtStore.ts](src/stores/useCourtStore.ts) (**đừng port 11 flag**).

**Exit criteria**: host chạy hết một buổi thật trên device (tạo → người join → gán sân → chạy 10 match → thu phí → kết thúc) không cần fallback web · gán sân optimistic có rollback khi socket báo conflict · bulk-approve 20 payment là **một** request · mọi số tiền render `decimalDigits: 0` (VND nguyên, không minor unit) — có test formatter.

### P4 — Xã hội: club, newsfeed, profile, rating, map · **L**

Browse/join club · club detail + members + fees · tạo/sửa club · my clubs · newsfeed + post detail + tạo post + like/comment · profile công khai · rating (cho/xem, thống kê) · **map** (session/venue/club, places autocomplete, custom pin) · **tạo ảnh share session**.

Tham chiếu: [BrowseClubsContent.tsx](src/app/[locale]/clubs/BrowseClubsContent.tsx) (1.011) · `src/components/session/session-share-card/` (2.350 dòng / 9 file / 3 họ template) + [useDownloadSessionImage.ts](src/hooks/useDownloadSessionImage.ts) · `SessionMap.tsx` (514), `VenueMap.tsx` (345), `ClubMap.tsx` (420), [useMapPinIcon.ts](src/hooks/useMapPinIcon.ts).

**Exit criteria**: share card render tương đương web (golden test cả 3 họ template) và share qua native sheet + lưu vào gallery · map dùng key restrict theo bundle-id/SHA, cluster >50 pin, degrade sang list khi bị từ chối location · rich text **render** đúng từ HTML TipTap sẵn có (table + image + code block), không có phần authoring.

### P5 — Xem giải đấu + trọng tài chấm điểm · **L**

Chiến thắng native thứ hai: trọng tài chấm điểm trên điện thoại. **Cố ý ship trước phần quản lý giải** — giá trị/dòng code cao hơn, và nó de-risk widget bracket bằng bản read-only trước.

Gồm: browse giải · tournament shell (home|teams|schedule|standings) với bottom nav mobile · standings + bảng đấu · **bracket read-only** (single + double elim) · match detail + tỉ số live qua namespace `/tournaments` · podium/winners · trang public theo code (`t/[id]/p/[playerCode]`, `/team/[registrationCode]`) · danh sách match của trọng tài · **bảng chấm điểm** · QR bar.

Tham chiếu: [TournamentPageShell.tsx](src/components/tournament/TournamentPageShell.tsx) (1.381) · [useTournamentSocket.ts](src/hooks/useTournamentSocket.ts) (`clientId` + `seq` tăng đơn điệu để triệt echo) · `PublicTournamentBracket.tsx` (459), `PublicDoubleEliminationBracket.tsx` (388), `BracketVisualization.tsx` (964) · `src/components/tournament/referee/` (3.977 — `ScoreEntryBoard` 1.345, `RefereeScoringPage` 1.335) · `category.service.ts` (**49 endpoint**).

**Widget bracket**: `vmito_ui/lib/src/bracket/` dựng layout tree immutable (round × slot) → `CustomPaint` vẽ connector khuỷu + `Positioned` card trong `InteractiveViewer`. **Nhân đôi estimate đầu tiên** — không có gì tương đương `react-tournament-brackets` trong Flutter.

**Exit criteria**: trọng tài chấm xong best-of-3 với socket **ngắt giữa set**, write-ahead log local replay khi reconnect và `clientId`/`seq` làm nó idempotent (server đã hỗ trợ) · bracket read-only golden-match renderer web trên 6 fixture giải · link public mở được in-app qua app links · output `standings` Dart khớp standings của API thật trên 3 giải thực.

### P6 — Host quản lý giải đấu · **XL**

Khối đắt nhất, để cuối. Chứa `src/components/tournament/manage/` — **30.002 dòng**, vùng tốn kém nhất cả repo.

Gồm: tạo giải + format wizard · CRUD category/group · setup pool (kéo team giữa bảng) · seeding (kéo đổi seed) · sinh lịch (generate/calendar/list/thêm tay/next-available-court) · rounds panel · override standings · phân trọng tài · quản lý match · dashboard · sponsor · manager role.

Tham chiếu: [RoundsPanel.tsx](src/components/tournament/manage/panels/RoundsPanel.tsx) (**2.159 — file lớn nhất repo, redesign chứ đừng dịch**), `SetupPoolsModal.tsx` (1.219), `GenerateScheduleDrawerV2.tsx` (1.010), `ManageStandingsModal.tsx` (782), `ScheduleCalendarView.tsx` (445) · `format-wizard/` (3.277) · [ScheduleGenerationContext.tsx](src/contexts/ScheduleGenerationContext.tsx) (429).

**Exit criteria**: host tạo trọn giải 32 team double-elim trên device · kéo-thả cross-list chạy trên cả 2 platform có haptic **và có fallback không cần kéo** (long-press → sheet "chuyển tới…") — yêu cầu cứng, chỉ có drag là không dùng được một tay · `schedule_generator` Dart ra output giống hệt JS trên 10 fixture giải.

### P7 — Venue + thuê sân · **L**

Browse/search venue · venue detail (giá, sân, ảnh) · luồng request thuê + validate lịch + báo giá · rental của tôi · quản lý rental (phía chủ sân) · venue request.

Tham chiếu: [VenueDetailClient.tsx](src/app/[locale]/venues/[id]/VenueDetailClient.tsx) (1.725), `VenueSearchList.tsx` (1.088) · `venue-rental.service.ts` (33 endpoint) · `pricing-utils.ts` và `schedule-validation.ts` đã port ở P0-B.

**Exit criteria**: báo giá tính client-side bằng `pricing_rules` đã port **khớp báo giá server trên 20 fixture booking** — lệch là bug ở một trong hai bên, test này chính là mục đích · validate slot trùng chặn submit trước khi gửi request.

### P8 — Polish, parity, tăng trưởng · **M**

AI assistant (streaming — **mobile gọi trực tiếp endpoint AI của backend**, không qua route handler `/api/ai/chat` vì đó chỉ là proxy che key) · product tour bằng `showcaseview` · rich-text authoring (nếu vẫn muốn) · CSV export · sweep deep link · pass accessibility (semantics, target 44pt, dynamic type, text scale tiếng Việt) · pass performance (frame timing trên bảng sân và bracket) · asset/ASO store · widget/live-activity cho gọi sân (stretch — delight cao cho use case cốt lõi).

---

## Quyết định hạ tầng xuyên suốt

### (a) Dio interceptor stack

Thứ tự: `AuthInterceptor` → `ErrorPolicyInterceptor` → `LoggerInterceptor` (chỉ dev).

**Single-flight refresh — KHÔNG dùng `QueuedInterceptorsWrapper`**, vì nó serialize *mọi* request, giết luôn parallel fetch trên screen session/tournament. Dùng `Interceptor` thường giữ một `Completer<String?>? _refreshing`:
- `onError`: nếu `status == 401` && `!extra['_retry']` && URL không thuộc auth-exclusion list (`/auth/login|register|refresh|forgot-password|reset-password` — port nguyên văn từ [base.ts:97-102](src/lib/api/base.ts#L97-L102)) && `authState is Authenticated` (mirror guard `hasRefreshToken`, cũng chính là thứ giữ guest im lặng):
  - nếu `_refreshing != null` → `await _refreshing!.future` rồi retry với token mới;
  - ngược lại tạo completer, gọi `/auth/refresh` trên **một Dio trần không interceptor** (chống đệ quy), complete, retry qua `dio.fetch(err.requestOptions)`;
  - refresh fail → complete với error, `authController.logout()`. **Không điều hướng bằng tay** — `refreshListenable` của go_router trên auth state tự redirect, và snackbar "Session expired" bị chặn nếu location hiện tại đã bắt đầu bằng `/auth/` (parity [base.ts:149](src/lib/api/base.ts#L149)).
- `extra['_retry']` và `extra['skipGlobalError']` thay 1:1 hai flag axios đang augment vào config.

**dedupGet** — không phải interceptor, là method trên `ApiClient.get()`, mirror [base.ts:204-242](src/lib/api/base.ts#L204-L242). Key = `token|path|sortedQuery`. **Sửa luôn bug của source khi port**: key TS dùng `JSON.stringify(params)` nên phụ thuộc thứ tự chèn — `{a,b}` và `{b,a}` miss cache. Dart phải sort key.

**Error policy** — tách khỏi interceptor. `ErrorPolicyInterceptor` chuyển `DioException` → sealed `ApiFailure` (`.network`, `.timeout`, `.unauthorized`, `.server`, `.validation`, `.unknown`) mang `method`, `status`, message hướng người dùng (port `getUserFacingErrorMessage`, quan trọng: phải giữ raw body kiểu Cloudflare `application/problem+json` **không lọt lên UI**), rồi emit lên `ApiErrorBus` (broadcast `Stream<ApiFailure>` sau provider keepAlive). Một `AppErrorListener` dưới `MaterialApp` subscribe và áp đúng policy web:

| Điều kiện | UI |
|---|---|
| `GET`, không `skipGlobalError`, status ≠ 401 | SnackBar |
| mutation, không phải auth request, không `skipGlobalError` | modal dialog |
| GET + 401 | im lặng (guest trên trang public) |
| **mới**: `connectionError`/`timeout` | banner offline + Retry, **không bao giờ modal** |

Dòng cuối là mới và bắt buộc — user mobile mất mạng liên tục, mỗi request rơi mà bật một modal là không dùng được. Chi tiết kỹ thuật đầy đủ đẩy về Crashlytics (vai trò `logApiError`), không đưa lên UI.

### (b) OpenAPI codegen vs freezed viết tay — **generate DTO, viết tay service**

Với 180 interface / ~4.500 field, viết tay freezed model là 2–3 tuần transcribe thuần cộng rủi ro drift vĩnh viễn với một repo có 391 call site. → **Generate DTO.**

Nhưng **đừng generate client**. Swagger output của NestJS sẽ sai đủ thường xuyên (nullability, envelope, shape query param, `PlayerLevel`) để client generated thành cái máy chạy theo vá lỗi, và bạn cần signature tự tay cho `dedupGet` với `skipGlobalError`.

1. Backend bật `@nestjs/swagger` + CLI plugin, CI publish `openapi.json`.
2. **Commit** `openapi/openapi.json` vào repo Flutter → codegen reproducible, mọi thay đổi contract hiện ra thành diff review được.
3. `swagger_dart_code_generator` sinh DTO `json_serializable` vào `packages/vmito_api/lib/src/generated/`. Gitignore output, commit checksum, CI regenerate và fail khi drift.
4. Viết tay 34 service class **đặt tên 1:1 với `src/lib/api/*.service.ts`** (`session_service.dart`, `category_service.dart`, …) → port thành cơ học và grep được: bất kỳ dev nào cũng diff được service Dart với bản TS song sinh.
5. **Nullability**: coi **mọi** field generated là nullable, normalize ở adapter boundary cho ~12 entity feed vào `vmito_domain`, giữ một danh sách ngoại lệ non-null có tài liệu (`id`, `createdAt`, …).
6. **`PlayerLevel` phải là `int`**, không bao giờ là enum generated — giá trị không liền mạch (1–8, 9, 10) và enum generated sẽ âm thầm đổi thứ tự.
7. Dùng DTO generated **trực tiếp trong UI**. Đừng dựng thêm một domain layer viết tay song song cho cả 180 type — đó đúng là khối transcribe bạn vừa tránh được. Chỉ ~12 freezed model trong `vmito_domain` là viết tay, vì package đó bắt buộc không phụ thuộc wire code.

### (c) Envelope không nhất quán — sniff khoan dung, một chỗ duy nhất

`ApiResponse<T> = {success, data?, error?, message?}` ở mọi nơi **trừ** `/auth/refresh` và `/auth/register` trả payload không bọc. Xử lý ở đúng một function:

```dart
T unwrap<T>(Response r, T Function(Json) fromJson) =>
  (r.data is Map && (r.data as Map).containsKey('success'))
    ? fromJson(r.data['data'])   // wrapped
    : fromJson(r.data);          // raw
```

Sniff theo **sự có mặt của `success`**, không theo allowlist URL. Nhờ vậy backend chuẩn hoá 2 endpoint kia **không cần release app đồng bộ**, client đã ship vẫn chạy suốt giai đoạn chuyển. Vẫn nên nhờ backend chuẩn hoá ở P0 — khi đó đoạn sniff thành code phòng thủ vĩnh viễn, chi phí bằng 0. Đồng thời **coi `success: false` kèm HTTP 200 là lỗi** (code web hiện không nhất quán chỗ này — port hành vi strict).

### (d) OAuth, deep link, và Apple

**OAuth**: `flutter_web_auth_2` (ASWebAuthenticationSession trên iOS, Custom Tabs trên Android). **Tuyệt đối không `webview_flutter`** — Google chủ động chặn embedded webview cho OAuth và Apple sẽ flag.

```dart
FlutterWebAuth2.authenticate(
  url: '$API/auth/google?locale=vi&returnUrl=vmito%3A%2F%2Fauth%2Fcallback',
  callbackUrlScheme: 'vmito',
) // → vmito://auth/callback?token=..&refreshToken=..&userId=..&email=..&name=..&role=..&image=..
```

Backend chỉ cần allowlist `vmito://auth/callback` làm `returnUrl` — luồng hiện tại đã trả token qua query param nên **chạy được với một dòng sửa backend**. Giữ Zalo ẩn (web đang comment out).

**Nên sửa (báo backend, đừng block)**: đẩy access + refresh token qua URL redirect là yếu — URL vào log và history. Đề xuất endpoint `POST /auth/oauth/exchange` đổi one-time code. Thiết kế phía Dart sau một `OAuthResultParser` để đổi sang code-exchange chỉ sửa một file.

**Apple Sign-In là BẮT BUỘC, không phải tuỳ chọn.** App Store Review Guideline 4.8: vì bạn có Google và Facebook login, bạn **phải** có Sign in with Apple (hoặc phương thức tương đương giới hạn thu thập ở name+email và hỗ trợ ẩn email — Apple làm được native, Google/Facebook thì không). Dùng `sign_in_with_apple`, thêm `POST /auth/apple` verify `identityToken` với JWKS của Apple, key user theo `sub`, chấp nhận email private-relay, và xử lý việc **Apple chỉ trả name/email ở lần authorize ĐẦU TIÊN** — không capture và persist ngay lần đầu thì bạn có account không tên mãi mãi.

**Cũng bắt buộc và thường bị bỏ sót**: Guideline 5.1.1(v) — app cho tạo account phải cho **xoá account trong app**. Cần `DELETE /users/me`. Đưa vào **P1**; phát hiện lúc review là mất một vòng reject.

**Deep link**: `app_links` cho universal/app link `https://vmito.com/...` (share link + notification tap) cộng custom scheme `vmito://` cho OAuth. Cần `apple-app-site-association` và `assetlinks.json` trên vmito.com — **việc ở repo web**, mất một deploy cycle, nên mở ticket từ P0.

### (e) Guest mode (không token)

```dart
AuthState = Unauthenticated | Guest(playerId, sessionId, code) | Authenticated(user, access, refresh)
```

Guest identity `guest-<playerId>` / `role: GUEST` / token null, persist ở **prefs** (không phải secure storage — nó không phải secret). `AuthInterceptor` không inject header `Authorization` cho Guest, và nhánh refresh bị skip bởi cùng guard `is Authenticated` — đây chính là lý do guest không được thấy toast 401. Socket connect với `token: ''`. go_router `redirect` dùng allowlist route cho guest, cộng đường upgrade Guest→Authenticated **giữ được session đã join** (guest join rồi mới register — cần verify backend có link 2 record hay phải thêm endpoint).

Góc App Store: cho browse không cần đăng ký là **điểm cộng** (5.1.1(i) cấm bắt buộc registration cho tính năng không cần account). Nhưng reviewer phải *tới được* nội dung — cấp demo account **và** một join code live trong review note, và session demo đó phải có sân đang hoạt động để feature gọi sân demo được.

### (f) Token socket khi reconnect

`socket_io_client` không có `auth` dạng function, nhưng `socket.auth` là **map mutable**:

```dart
socket.onReconnectAttempt((_) => socket.auth = {'token': tokenOrEmpty()});
socket.onConnectError((_) => socket.auth = {'token': tokenOrEmpty()});
```

Thêm: subscribe auth-state change; nếu access token đổi khi đang connected thì set `auth` rồi `disconnect(); connect()` (server không re-read auth trên connection đang sống).

**Room replay không phải tuỳ chọn.** Code web re-join tournament room khi reconnect nhưng session room do component drive — trên web nó vô tình đúng vì React remount. Flutter giữ provider sống qua reconnect, nên phải có `RoomRegistry` (`Set<Room>`) trong mỗi socket service và replay tất cả khi `connect`: `join_user_room` (có ack), `joinSession`, `joinPost`, `joinFavoriteTarget`, `joinTournament`.

**App lifecycle** — vấn đề mobile-only mà bản web không có: iOS kill socket khi background. Khi `AppLifecycleState.resumed`: force reconnect **và** trigger REST re-fetch cho screen đang hiển thị để chữa event bị mất lúc suspend. Cái này thay `useSessionRefresh` polling khi IN_PROGRESS. **Nguyên tắc thiết kế: mọi socket handler là một state patch idempotent, và mọi screen phải rebuild được state từ một REST call.** Handler nào không diễn đạt được thành patch idempotent thì refetch thay vì patch.

Hai namespace → hai service (`SessionSocketService`, `TournamentSocketService`) từ một factory derive base URL bằng cách strip `/api` ở cuối. Expose `Stream<T>` typed cho từng event; filter payload user-room theo `data.userId == currentUser.id` (web đang làm — **giữ, đây là filter bảo mật thật**). Giữ `clientId` (uuid mỗi launch) + `seq` tăng đơn điệu để triệt echo tournament.

### (g) i18n: 3 × ~6.000 key JSON → ARB

Đã đếm chính xác: **vi 5.978 key** (namespace `pages` = **2.811 = 47%**), en 5.958, cn 5.919.

1. **Đừng convert cả 5.978 key.** Convert theo phase, driven bởi screen của phase đó. `pages` phần lớn là content admin + SEO landing bạn không port; `admin` + `adminVenuePricing` (333 key) loại thẳng. Mục tiêu thực tế: **~2.500–3.000 key**. Đây đúng là lúc dẹp cái sọt rác `pages` — re-home key về namespace theo feature khớp `lib/features/`.
2. `tool/json_to_arb.dart`: flatten dot path → camelCase (`session.detail.title` → `sessionDetailTitle`) và **sinh metadata placeholder `@key`** — đó là phần cơ học thật sự, vì next-intl đã dùng ICU MessageFormat nên `{count, plural, ...}` và `select` chuyển gần như 1:1. Escape `{`/`}` lạc và **dấu `'` trong tiếng Việt (apostrophe là escape của ICU — chỗ này sẽ cắn bạn)**.
3. Một ARB mỗi locale, `app_vi.arb` làm template (Vietnamese-first, khớp sản phẩm), `gen-l10n` với `nullable-getters: false`, `synthetic-package: false`.
4. `tool/l10n_check.dart` thay `scripts/check-i18n.js` với 3 check: (i) 3 locale có key set giống hệt; (ii) không có key unused; (iii) **không có literal tiếng Việt hardcode** — regex tìm dấu tiếng Việt trong Dart string literal. Check (iii) là mới và là guard giá trị nhất của cả cuộc port, vì dịch tay 139k dòng JSX chính xác là cách string hardcode lọt vào. Wire cả 3 vào CI + `lefthook` pre-commit.
5. Centralize tiền ở `core/format/money.dart`: `NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0)` — **VND nguyên, không minor unit**. Và dẹp dual dayjs/date-fns: chỉ `intl` + `timezone`, một façade `AppDate`.

### (h) FCM + bảng notification → deep link

**Backend**: `POST /notifications/devices {token, platform, appVersion, locale, deviceId}` (upsert, dedupe theo token), `DELETE /notifications/devices/:token` khi logout và khi guest→user, prune khi FCM trả `UNREGISTERED`. Đặt **mọi** routing key vào block `data` — `type`, `action`, `sessionId`, `slug`, `clubId`, `tournamentId`, `postId`, `rentalRequestId`, `venueId`, `manage`, `courtNumber` — vì đó đúng là key set mà [routing.ts](src/lib/notifications/routing.ts) đọc, nên bản port Dart chạy không cần sửa.

**Payload policy**: court call cần `notification` + `data`, `apns-priority: 10`, `apns-push-type: alert`, `interruption-level: time-sensitive`, Android channel `court_call` `importance: max` + custom sound. Time-sensitive cần entitlement `com.apple.developer.usernotifications.time-sensitive` — **xin từ P0, không phải P1**. Push data-only **không** được deliver tin cậy khi app iOS bị kill, nên block `notification` là bắt buộc làm fallback.

**Phía Dart**: port [content.ts](src/lib/notifications/content.ts) → `NotificationContent.resolve(type, action, data, l10n)`, dùng ở 3 chỗ (row in-app, local notification khi socket event tới lúc foreground, fallback title/body cho push data-only). Port [routing.ts](src/lib/notifications/routing.ts) → `NotificationRouter.resolve(notification, role) → String?` trả path go_router; lưu 2 nhánh phụ thuộc role (`SESSION`/`REGISTRATION` → host vs player detail; `CLUB` → host edit vs public detail) và nhánh `data.manage == true` cho `VENUE_RENTAL`. Cold start: `getInitialMessage()` → stash `pendingDeepLink` → navigate **sau khi** restore auth xong, không trước. Foreground: FCM `onMessage` **không** tự hiển thị trên iOS — show qua `flutter_local_notifications`, và suppress nếu user đang xem đúng screen đích.

**TTS gọi sân**: `flutter_tts` với `setLanguage('vi-VN')`, `awaitSpeakCompletion(true)`, `setSharedInstance(true)`, iOS audio category `playback` + `mixWithOthers` (để nó ducking nhạc trong sân chứ không fail), rồi loop 3× / 1.5s gap. Cái này xoá 249 dòng workaround `useUniversalVmitoAudio`.

---

## Cố ý KHÔNG port

| Không port | Lý do |
|---|---|
| `/admin/**` (**16 page, đã verify**) + `admin.service.ts` + 333 i18n key | Việc bàn giấy, tần suất thấp, nặng table. Web tốt hơn hẳn. |
| OBS overlay (`tournament/[id]/overlay/court/*`, `overlay/match/*`) | OBS consume trong browser. Vô nghĩa trên mobile. |
| Scoreboard màn hình lớn (1.479) + showcase (1.877) | Thiết kế cho máy chiếu tại sân. |
| `san-cau-long/[slug]`, sitemap, robots, `[...slug]` | Bề mặt SEO. App native không có SEO. |
| **Toàn bộ `src/components/ui/`** (12.431 dòng, 72 file) | Wrapper Chakra. Material/Cupertino + ~20 atom thay hết. **Khối xoá lớn nhất.** |
| Code dead (đã verify): `/join/confirm` (367), `/join/status` (804 — gần trùng `/guest/join/status` 784), `/player/sessions` (250), `BaseSessionCard.old.tsx` (329), `pricing-preview/`, `__pricing-preview/` | Dead. Port là phí thuần. |
| **`/tournaments` self-redirect loop** ([routes.ts:363,368](src/constants/routes.ts#L363-L368)) và `/tournaments/[id]` → `/browse/tournaments/[id]` (không có page → 404) | **Bug, không phải feature.** Thiết kế go_router cho đúng, và **sửa route web riêng** — link tournament share cũ đang 404 với user thật. |
| Stub: `/settings` (32, "coming soon"), `/search` (chưa wire), `/player/transactions` detail | Không có gì để port. Xây settings mới ở P1. |
| `useUrlFilters` (178) | URL-as-state là concept web. Riverpod giữ filter state. |
| `usePWA` (129) + config `next-pwa` | App native thay thế. |
| `src/types/` (6 file **rỗng**) | Refactor bị bỏ dở. Model thật là `src/lib/api/types.ts`. |
| `next-auth` (có dep, **0 import**), `bcryptjs`, `jsonwebtoken` | Dep client không dùng. Cũng nên xoá khỏi `package.json` web luôn. |
| Route handler `/api/ai/chat` | Chỉ là proxy che key. Mobile gọi endpoint AI của backend trực tiếp. |
| Dual `dayjs` + `date-fns` | Trùng lặp. Chỉ `intl` + `timezone`. |
| Rich-text **authoring** (TipTap: table, image, code block) | Hoãn tới P8, có thể mãi mãi. Chỉ đọc (`flutter_widget_from_html_core`) cover 95% giá trị; `flutter_quill` không round-trip table TipTap không mất mát. Author trên web. |
| XLSX **import** (`AIImportScheduleDrawer` 741) | Không ai import spreadsheet từ điện thoại. Chỉ export CSV. |
| Desktop chrome: sidebar, breadcrumb, `TopBarSearchContext`, `UserMenu` (818) | Bottom nav + profile tab thay. |
| Offline write queue (trừ referee scoring) | Xem risk #4. Queue mù việc approve payment hay gán người vào sân là nguy hiểm về data integrity. |

---

## Sổ rủi ro

| # | Rủi ro | Mức | Giảm thiểu |
|---|---|---|---|
| 1 | **Render bracket** — `react-tournament-brackets` không có bản Flutter; 7 component / ~4.000 dòng | Cao | Dựng `vmito_ui/bracket` bằng layout tree immutable → `CustomPaint` connector + `Positioned` card trong `InteractiveViewer`. **Nhân đôi budget.** Ship read-only (P5) trước drag-reseed (P6). Golden test 4/8/16/32, bye, double-elim, label placeholder. **Escape hatch có time-box**: nếu bracket read-only P5 trượt >2 tuần, nhúng bracket web trong **một** WebView tab cho **đúng release đó** rồi thay sau. Một chart nhúng trong app native là ổn với Guideline 4.2; chiến lược WebView-mỗi-screen thì không. |
| 2 | **TTS/audio iOS khi background hoặc khoá máy** — bạn **không thể** chạy TTS từ background push trên iOS | Cao | Quyết định sản phẩm: **TTS chỉ foreground**. Gọi sân khi khoá/background dùng **push time-sensitive + custom sound** (≤30s caf/aiff). Xin entitlement time-sensitive từ P0. Ghi rõ giới hạn trong app ("thông báo giọng nói cần mở app") để nó là hành vi có tài liệu, không phải bug report. |
| 3 | **Mất socket event qua app lifecycle** | Cao | Refetch-on-resume bắt buộc; mọi handler là patch idempotent; mọi screen rebuild được từ một REST call. Test: background 5 phút giữa session live rồi assert state converge. |
| 4 | **Kỳ vọng offline** — user ở sân, wifi tệ | Cao | v1: **không có write queue chung.** Read cache cho hot GET (session detail, court list, my sessions) qua `dio_cache_interceptor` + Hive, kèm banner "cập nhật X giây trước" và retry tường minh; banner offline thay error modal; mutation fail nhanh với affordance Retry. **Một ngoại lệ**: referee scoring có write-ahead log local (P5) — chính đáng vì protocol đã mang `clientId` + `seq` nên replay idempotent phía server. |
| 5 | **Bị reject App Store** | Cao | Ship hết ở **P1**: Apple Sign-In (4.8, bị trigger bởi Google/Facebook), xoá account trong app (5.1.1(v)), không bắt buộc đăng ký để browse (5.1.1(i)), purpose string chính xác (camera=QR, photos=ảnh chuyển khoản, location=kèo gần đây, notifications=gọi sân), `PrivacyInfo.xcprivacy` có khai báo required-reason API. Về payment: tiền chuyển khoản bank thật cho **dịch vụ ngoài đời**, nên **không cần IAP** — nhưng đừng bao giờ link out cho thứ đọc ra như digital content, và đừng dùng chữ "purchase" trong UI thanh toán. Guideline **4.2 minimum functionality** là cái bẫy ngầm: release đầu nhỏ vẫn phải *thấy rõ là native* — QR scan, push, gọi sân bằng giọng nói, bảng sân live là đủ gánh. |
| 6 | **Codegen drift / Swagger NestJS chất lượng thấp** | Cao-TB | Commit `openapi.json` review như diff; policy DTO all-nullable; envelope sniff khoan dung; nightly contract test decode top 25 endpoint với staging; CI check codegen drift. |
| 7 | **Scope sụp** — 139.707 dòng component / 492 file | Cao | Luật cứng: **component React nào >~600 dòng thì REDESIGN cho mobile, không dịch nguyên.** Danh sách đen: `RoundsPanel` (2.159), `PublicTournamentStandingsTab` (1.738), `VenueDetailClient` (1.725), `TournamentHomeTab` (1.656), `BaseSessionCard` (1.482), `ScoreEntryBoard` (1.345), `FindSessionList` (1.239), `SetupPoolsModal` (1.219), `NotificationBell` (1.204). |
| 8 | **Hai frontend drift** về business rule | Cao-TB | Backend là contract cho data; **`fixtures/` là contract cho thuật toán**. Cả suite JS và Dart đọc cùng corpus fixture trong CI. Đổi rule nào cũng phải update fixture, buộc 2 ngôn ngữ đi cùng nhau. Đây là biện pháp hiệu quả nhất trong cả tài liệu này. |
| 9 | **Thiếu translation runtime** trên 3 locale | TB | `l10n_check` trong CI (key set giống nhau + unused key + phát hiện literal VN hardcode); không fallback về tên key âm thầm ở release build; assert ở debug. |
| 10 | **Render và overflow tiếng Việt** | TB | Bundle font đủ dấu tiếng Việt (Be Vietnam Pro / Noto Sans); string VN dài ~1,3× English → golden test string VN dài nhất trong mọi layout dày (bảng sân, card bracket, session card) ở text scale 1.0× và 1.3×. |
| 11 | **Chi phí, key và cấu hình map** | TB | Key restrict theo bundle-id/SHA cho từng flavor; cluster >50 pin; degrade sang list-only khi từ chối location; verify privacy manifest của Firebase/Maps SDK (Apple yêu cầu cho SDK trong danh sách). |
| 12 | **Lifecycle push token** qua logout / guest→user / reinstall | TB | Register mỗi lần app start (token rotate), unregister khi logout, re-register sau khi upgrade guest; backend dedupe theo token, prune khi `UNREGISTERED`. Không làm thì user nhận gọi sân của account đã rời. |
| 13 | **`suggested-players` là server-side** | Thấp (nhưng footgun) | Document to rõ để không ai "port" matchmaking. Chỉ chia bảng **giải đấu** là client-side. |

---

## Verification

**Luật số 0: test thuật toán đi TRƯỚC screen đầu tiên.** ~2.900 dòng logic thuần đã có **10 file test / 1.333 dòng** trong repo web. Port sang Dart ở P0-B là bảo hiểm đúng đắn rẻ nhất của dự án.

> ⚠️ Lưu ý: thư mục `e2e/` trong repo web **rỗng** (chỉ có `.auth/` trống), và **không có Playwright** trong `package.json`. Web thực tế **không có E2E suite nào** để tham chiếu — `patrol` sẽ là bộ E2E đầu tiên của sản phẩm. Ngoài ra chỉ 3/10 file test có npm script (`test:ranking`, `test:venue-pricing`, `test:venue-schedule`), 7 file còn lại **không có runner** — nên đưa hết vào CI khi port.

**Bước 1 — port nguyên văn 10 suite sẵn có**: `standings` (264), `auto-assign` (219), `pricing-utils` (148), `round-robin` (147), `schedule-validation` (110), `match-repeat-warning` (98), `club-venue-schedule` (98), `session-player-ranking` (95), `resultsRealtime` (85), `teamRoster` (69). Giữ nguyên tên case, nguyên expectation. Dart fail = bug port, hết chuyện.

**Bước 2 — characterization test cho 5 module giá trị cao chưa có test**: `rally.ts`, `schedule-generator.ts`, `bracketSlots.ts`, `podium.ts`, `match-result-utils.ts`. Phải tự tạo oracle: script Node dùng-một-lần drive TS hiện tại, dump `{input, output}` vào `fixtures/`, commit, assert Dart tái tạo chính xác. Coverage: ≥200 case rally (best-of 1/3/5 × GROUP/KNOCKOUT/FINAL × đơn/đôi × biên set-complete/match-point/delta-mirroring), ≥10 giải thật cho schedule generator, cả 5 dạng score legacy cho `match-result-utils`, cả 2 `CourtDirection` cho `match-repeat-warning`, đủ 4 state cho `podium`.

**Bước 3 — sửa test JS đọc `fixtures/`**, rồi chạy cả 2 suite trong CI. Từ đó 2 implementation bị ghim vào một corpus, không drift âm thầm được.

**Rồi theo layer:**
- **Unit** (`vmito_domain`, pure Dart): >90% line coverage, <5s, chạy mỗi lần save.
- **Provider test**: `ProviderContainer` + `overrideWith` service mocktail. Giá trị cao nhất ở đúng chỗ web không có test nào: single-flight refresh (assert **đúng 1** lần `/auth/refresh` dưới 5 request 401 đồng thời), dedupGet, guest-mode suppress header, socket room replay, orchestration gọi sân.
- **Widget test**: form + validation + trạng thái empty/error/loading.
- **Golden test** (`alchemist`): ROI cao nhất vì 2 widget đắt nhất là vẽ tay. `BadmintonCourtView` — 3 mode × 2 direction × 0–4 player × overlay pre-selected ≈ 24 golden. `BracketView` — 6 hình draw kể cả bye + double-elim. Share card — cả 3 họ template (đây là cách chứng minh parity với output `modern-screenshot`). Cộng biến thể string VN dài và text scale 1.3×.
- **Contract test** (`test/contract/`, nightly với staging): decode response của top 25 endpoint vào DTO, fail khi có decode error hoặc null bất ngờ. Đây là thứ bắt backend drift trước user.
- **Fake backend**: `tool/record_fixtures.dart` ghi response staging thật qua dio interceptor thành JSON; `FakeApiClient` replay. Cho phép dev offline, widget test nhanh, E2E deterministic.
- **E2E** (`patrol`): một flow mỗi release, **không thương lượng cho P1** — quét QR → join guest → bảng sân live → nhận gọi sân (fake FCM + fake socket) → TTS được gọi. Thêm một flow mỗi phase sau (P3: host chạy hết session; P5: trọng tài chấm best-of-3 với disconnect giữa set).
- **CI gate mỗi PR**: `flutter analyze` 0 warning (`very_good_analysis` + `riverpod_lint`) · `dart test` (domain) · `flutter test` (app + golden) · `l10n_check` · openapi-drift · codegen-drift · suite JS fixture. Nightly: contract test + patrol trên device farm.

---

## File tham chiếu quan trọng nhất

- [src/lib/api/base.ts](src/lib/api/base.ts) — semantics interceptor cần port chính xác (single-flight refresh [:104-160](src/lib/api/base.ts#L104-L160), dedupGet [:204-242](src/lib/api/base.ts#L204-L242), policy GET-toast/mutation-modal [:161-198](src/lib/api/base.ts#L161-L198))
- [src/lib/api/types.ts](src/lib/api/types.ts) — 2.095 dòng / 180 interface = domain model thật, và là target của codegen
- [src/contexts/SocketContext.tsx](src/contexts/SocketContext.tsx) — contract socket auth/reconnect, cộng block gọi sân + TTS vi-VN 3× ở [:333-395](src/contexts/SocketContext.tsx#L333-L395) (critical cho P1)
- [src/constants/routes.ts](src/constants/routes.ts) — spec go_router có sẵn (và 2 bug redirect ở [:363](src/constants/routes.ts#L363), [:368](src/constants/routes.ts#L368) cần **sửa** chứ không port)
- [src/lib/scoring/rally.ts](src/lib/scoring/rally.ts) + [src/utils/schedule-generator.ts](src/utils/schedule-generator.ts) — 2 thuật toán giá trị cao nhất, **cả hai đều chưa có test**, nên cả hai cần fixture golden-master
- [src/components/court/BadmintonCourt.tsx](src/components/court/BadmintonCourt.tsx) — widget block P1 (aspect 13.4:6.1 ở [:66](src/components/court/BadmintonCourt.tsx#L66), 4 slot, 3 mode, 2 direction)
- [src/lib/notifications/content.ts](src/lib/notifications/content.ts) + [src/lib/notifications/routing.ts](src/lib/notifications/routing.ts) — bảng map deep link FCM, port được gần như nguyên văn
