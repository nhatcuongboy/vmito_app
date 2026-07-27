# Design system

## Tokens

Ported 1:1 from `vmito-fe/src/app/globals.css`, where they are HSL CSS custom
properties, converted to sRGB in `core/theme/app_colors.dart`.

Brand green: `hsl(136 74% 35%)` → `#179B3A` light, `hsl(136 74% 45%)` →
`#1EC84B` dark.

**Keep the two in sync.** If a token changes on web, convert it — never eyeball
a replacement.

| Token group | Where |
|---|---|
| Colours | `AppColors` |
| Spacing (4 px Tailwind scale) | `AppSpacing` |
| Radii (`--radius: 0.5rem`) | `AppRadius` |
| Sizes, tap targets, court ratio | `AppSizes` |

## Using the theme

Never hardcode a colour at a call site.

```dart
final theme = Theme.of(context);
final palette = theme.extension<AppPalette>()!;

theme.colorScheme.primary      // brand
theme.colorScheme.error        // destructive
palette.mutedForeground        // secondary text
palette.border                 // dividers, outlines
palette.success / .warning     // status
```

`AppPalette` is a `ThemeExtension` holding the app-specific colours Material's
`ColorScheme` has no slot for. It exists so widgets never branch on
`Theme.of(context).brightness` — the theme resolves light/dark, the widget just
reads.

## Spacing

```dart
const EdgeInsets.all(AppSpacing.md)          // 16 — matches Tailwind p-4
const SizedBox(height: AppSpacing.lg)        // 24
```

The scale matches Tailwind's 4 px base, so a `p-4` on web translates directly
without arithmetic at the call site.

## Widgets

- **`core/widgets/`** — atoms used by two or more features. Roughly 20 of these
  replace the 12,431 lines in `vmito-fe/src/components/ui/`.
- **`features/<name>/presentation/widgets/`** — everything feature-local.

Do not promote a widget to `core/` on the first reuse. Two independent callers
is the bar.

Existing atoms:

| Widget | Use |
|---|---|
| `AppErrorView` | full-screen failure with retry, for a load that produced nothing |
| `AppErrorListener` | app-wide SnackBar for unhandled API errors; mounted in `MaterialApp.builder` |

`AppErrorView` replaces content only when there is no content. A failure on top
of already-loaded data gets a SnackBar — do not blank a screen the user was
reading.

## Accessibility

- **48 dp minimum tap target** (`AppSizes.minTapTarget`). Court views and player
  chips are dense enough to tempt going below this. Don't.
- Every icon-only button needs a `Semantics` label or `tooltip`.
- Respect the system text scale. Test at 200% — session cards and court labels
  are where it breaks first.
- Colour is never the only signal. Player status, payment status, and match
  state all need an icon or text alongside.

## Dark mode

Both themes are complete and `themeMode` follows the system. Every screen must
be checked in both — the design tokens make this cheap, but only if nothing
hardcodes a colour.

## Court rendering

`AppSizes.courtAspectRatio` is `13.4 / 6.1`, from `BadmintonCourt.tsx:66`.

Vertical orientation is a **coordinate transform** of the horizontal layout,
not a second widget tree. Two trees means every change is made twice and they
drift.
