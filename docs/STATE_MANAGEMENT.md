# State management

Riverpod 3, manual providers.

## Why no code generation

`riverpod_generator` is **not installed**. Its transitive `riverpod_analyzer_utils`
pin conflicts with `json_serializable ^6.14` (and `riverpod_lint` conflicts with
`freezed_annotation ^3`). Since models need `json_serializable` and providers do
not need codegen, providers are written by hand.

Do not add `riverpod_annotation` or `riverpod_lint` back without first checking
that the constraint conflict is resolved upstream.

## Zustand → Riverpod

The web app has 12 Zustand stores. They map near 1:1:

| Zustand | Riverpod |
|---|---|
| `create()((set) => ({...}))` | `Notifier<T>` + `NotifierProvider` |
| `set({ x })` | `state = state.copyWith(x: ...)` |
| `useStore((s) => s.x)` | `ref.watch(provider.select((s) => s.x))` |
| `useStore.getState().x` | `ref.read(provider).x` |
| `persist` middleware | explicit `TokenStorage` / `SharedPreferences` write |
| `partialize` | choose what you persist explicitly |
| `onRehydrateStorage` / `isHydrated` | `AuthStatus.unknown` + `bootstrap` await |

Two differences worth internalising:

- **Persistence is never implicit.** Zustand's `persist` writes on every state
  change. Here you write when you mean to. Tokens go to `TokenStorage`;
  preferences go to `SharedPreferences`.
- **Hydration is resolved before the first frame,** not signalled by a flag
  mid-render. `bootstrap.dart` awaits `restoreSession()`.

## Provider kinds

| Use | Kind |
|---|---|
| A dependency with no state (service, client) | `Provider` |
| Mutable state with actions | `NotifierProvider` |
| A one-shot async read | `FutureProvider` |
| Async read keyed by an argument | `FutureProvider.family` |
| A derived value | `Provider` that watches another |
| A stream (sockets) | `StreamProvider` |

## The controller pattern

```dart
class SessionController extends Notifier<AsyncValue<Session>> {
  @override
  AsyncValue<Session> build() => const AsyncValue.loading();

  SessionService get _service => ref.read(sessionServiceProvider);

  Future<void> load(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.byId(id));
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, AsyncValue<Session>>(
  SessionController.new,
);
```

Rules:

- **No async work in `build()`.** It runs during widget build; a suspended
  build can rebuild the router mid-navigation. Expose an explicit `load()`, or
  use `FutureProvider` if the read is genuinely declarative.
- **Controllers throw, they don't display.** Let `ApiException` propagate to
  the screen, or capture it with `AsyncValue.guard`.
- **Read services with `ref.read`, not `ref.watch`.** A service is a constant
  dependency; watching it rebuilds the controller for nothing.

## Selectors

Expose narrow providers next to the controller so widgets rebuild only for the
field they use:

```dart
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authControllerProvider).user,
);
```

In a widget, prefer `ref.watch(p.select((s) => s.field))` over watching the
whole object.

## `ref.watch` vs `ref.read`

- `ref.watch` in `build` — subscribe and rebuild.
- `ref.read` in callbacks — one-shot, no subscription. Using `watch` in a
  callback is a bug; using `read` in `build` means the widget never updates.
- `ref.listen` for side effects (navigation, SnackBar) driven by state changes.

## After a mutation

Patch state or refetch the affected resource — never rebuild the whole screen.
Optimistic update, or write the API response back into state:

```dart
Future<void> rename(String id, String name) async {
  final updated = await _service.rename(id, name);
  state = AsyncValue.data(updated);   // not: load(id)
}
```

Needing a full reload to see fresh data means the state layer is out of sync.
Fix that, not the symptom.

## Testing controllers

```dart
final container = ProviderContainer(
  overrides: [sessionServiceProvider.overrideWithValue(MockSessionService())],
);
addTearDown(container.dispose);
```

`mocktail` is available. Never let a test hit the network.
