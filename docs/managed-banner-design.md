# Managed RemoteBanner integration — design note

18 September 2026. Written before implementation, per the integration blueprint.

This note fixes the publisher-facing shape and the request-ownership flow. It is additive: every
existing API keeps its current behaviour and meaning.

---

## 1. The identity problem

Native identifies a page by an **object token** — an `Activity`, `Fragment` or `UIViewController`,
matched by identity. Two article screens of the same class are correctly distinct.

Both bridges collapse that into a single string:

```dart
AudienzzSdkFlutter.instance.pageImpression(name: 'article');   // Flutter
```
```ts
Audienzz.pageImpression('article');                            // React Native
```

That string is simultaneously the page identity, the analytics screen name and the bridge's routing
key. Two article routes named `article` therefore share ownership: the second one's page impression
matches the first one's banners, so they are recreated instead of released.

**Three concepts, separated:**

| Concept | Meaning | Repeats? |
|---|---|---|
| Page instance id | Which route instance owns this banner | Never |
| Screen name | What analytics calls this screen | Freely |
| Visit epoch | Which visit to that page this is | Monotonic |

The bridges get a page **handle** carrying all three. The wire key becomes the instance id; the name
travels beside it for analytics. Native is unchanged — it already matches by token, and a unique
string is a valid token.

A slot is then `(page instance id, slot key)`. A configuration id is not unique: the same
`adConfigId` legitimately appears twice on one page.

## 2. Publisher-facing usage

### Flutter

```dart
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        // One adapter. Covers push, pop, replace and remove.
        navigatorObservers: [AudienzzNavigatorObserver()],
        home: const HomePage(),
      );
}

class ArticlePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(children: const [
        ArticleBody(),
        // Reserves space, owns the ad's lifetime, loads near the viewport.
        AudienzzBanner(adConfigId: '46', slotKey: 'in-content-1'),
      ]);
}
```

No `Timer`, no `load()`, no `dispose()`, no reload after a page impression or app resume.

### React Native

```tsx
export default function App() {
  return (
    <AudienzzProvider>
      <NavigationContainer onStateChange={audienzzOnNavigationStateChange}>
        <Stack.Navigator>{/* … */}</Stack.Navigator>
      </NavigationContainer>
    </AudienzzProvider>
  );
}

function ArticleScreen() {
  return (
    <AudienzzPage name="article">
      <ArticleBody />
      <AudienzzBanner adConfigId="46" slotKey="in-content-1" />
    </AudienzzPage>
  );
}
```

`AudienzzPage` is what fixes the construction-ordering bug. A banner reads its page from React
context **during render**, not from a module global written by a parent effect. Effects run after
commit, so a child constructed in the same pass previously captured the *previous* page. Context is
available to the child at construction, so no navigation side effect has to move into render.

### Native iOS / Android

The existing `AURemoteConfigBannerView` / `AudienzzRemoteBannerView` already own their own lifetime,
and `pageImpression(screen:name:)` already takes a distinct token. Native gets no new component —
only a `slotKey` for diagnostics and the documented custom-router contract.

## 3. Request ownership flow

```
                      publisher
                          │
          ┌───────────────┴────────────────┐
          │                                │
  navigation adapter                 AudienzzBanner
          │                                │
   page.activate()                  (page, slotKey)
          │                                │
          └──────────► page registry ◄─────┘
                          │
                  one owner per slot
                          │
                   native coordinator          ← sole owner of
                  (AUScreenAdCoordinator /        page sweeps and
                   ScreenAdCoordinator)           foreground recovery
                          │
                   refresh controller          ← sole owner of
                          │                      periodic scheduling
                   canStartAuction()           ← single choke point
                          │
                  Prebid auction → Google load
```

Every request passes `canStartAuction()`. It already refuses when destroyed, page-inactive,
backgrounded or publisher-stopped, and the first-load prefetch exemption covers **only** the three
geometry/attachment reasons. Managed loading adds no second path — it decides *when to mount a
sized placeholder*, which is what lets the existing lazy geometry check run at all.

## 4. What the managed component owns

| Concern | Behaviour |
|---|---|
| Identity | `(page instance, slotKey)`. A rebuild with the same pair reuses the owner; a changed pair replaces it. |
| Placeholder | A correctly sized box is mounted **before** the first geometry check. Never waits for `onAdLoaded` to mount the view that triggers the load. |
| Loading | Defaults to near-viewport in managed mode, because the component owns the placeholder that makes it work. An explicit `lazyLoad` argument still wins. |
| Rebuilds | Ordinary rebuilds request nothing. |
| Recycling | Leaving the owning scope disposes; a recycled slot cancels stale callbacks. |
| Size change | A genuinely different resolved size replaces only that owner. |
| Destruction | Owner, scheduler, observations and callbacks retire together; late responses cannot resurrect. |
| Cover | `reportCover(bool)` is *current state* with automatic cleanup on unmount. Arbitrary overlays are **not** claimed to be auto-detectable. |

## 5. Deliberate non-goals

- Refresh intervals are unchanged.
- "Preserve unimpressed creatives" stays a separate proposal (`banner-delivery-policy.md`).
- No revenue claim. No claim of zero background network traffic — an already-issued request may
  complete after backgrounding; what is guaranteed is that no *new* auction or Google handoff starts
  once the background gate closes.
- GAM server-side banner refresh must be unset for the ad unit. Publisher lifecycle code cannot
  compensate for a second refresh owner.
