# Automatic ad-request targeting

Original-API banners (including RemoteBanners) and interstitials send these reserved GAM
custom-targeting keys automatically on Android, iOS, Flutter and React Native. No publisher
counter or new integration parameter is required.

| Key | Meaning | First value |
| --- | --- | --- |
| `au_page_seq` | Session sequence of the native `pageImpression` report | `1` |
| `au_slot` | Automatically assigned **banner** placement number within the page impression | `1` |
| `hb_refresh_count` | Additional admitted requests for this ad owner in this page impression | `0` |

Values are decimal strings. For example, on the first page, the second slot's first request
contains `au_page_seq=1`, `au_slot=2`, `hb_refresh_count=0`. Its next request has `hb_refresh_count=1`.
Refreshing that slot does not change the first slot's counter. Another `pageImpression` produces
`au_page_seq=2` and each slot starts at `hb_refresh_count=0` again.

## Page and slot ownership

- The native page coordinator owns the sequence. Re-reporting the same page, returning to it,
  or an automatic foreground report all increment it. Bridge echoes do not increment it again.
- Before the first report, `au_page_seq=0` explicitly means unreported. The SDK does not invent
  a page impression. Keep the normal integration contract: report the page before creating ads.
- Slot numbers follow SDK registration order, before lazy loading. They do **not** follow bid
  completion order. A lazy or publisher-paused first banner retains slot 1 when slot 2 loads first.
- Registration usually follows layout order, but the SDK cannot infer the position of views that
  have not been created. Virtualized lists, reverse creation, and later insertions can differ from
  visual top-to-bottom order. Numbers are stable within the page; existing requests are never
  renumbered after a layout change. Removed slots can leave gaps.
- Two ad instances using the same configuration are two slots. A retained RemoteBanner owner,
  managed Flutter banner, or React Native view shares its context with its replacement native
  ads. A wholly new banner owner is a new slot.
- Interstitials do not reserve banner numbers and omit `au_slot` from their requests, including
  any stale/publisher value under that reserved name. Their own `hb_refresh_count` still advances
  per admitted request and resets on a new page impression. A retained Flutter interstitial
  keeps this request-counter identity across successive prefetches.

## Request boundaries

Counters advance only when a request passes the SDK's gates and begins an auction. Coalesced
prefetches, readiness checks, visibility updates and rejected/blocked load attempts do not advance
it. An admitted retry or manual reload does advance it, even if that request fails or is later
cancelled. `hb_refresh_count` is therefore a request counter, not an impression counter.

Each request carries its own snapshot through Prebid and into Google. A subsequent page report
or refresh cannot relabel an outstanding request. Existing publisher targeting is preserved;
the SDK controls these reserved keys (`au_slot` is absent for interstitials). They are request-local, not global targeting. See
"Publisher key-values and the SDK's, side by side" below.

`hb_refresh_count` shares Prebid's `hb_` prefix, and Prebid iOS removes every `hb_` key from the
GAM request at the start of each auction. The SDK re-applies the request's own snapshot after
Prebid finishes and before GAM loads, so the key reaches GAM on every platform. Prebid Android
removes only the keys it applied itself.

These fields are independent of clickstream `slot_reload`, which remains a binary `0`/`1`.
No analytics schema or refresh scheduling behavior changes. Rendering-API requests are outside
this change. GAM-managed automatic refresh is not an SDK-owned request and does not advance
these counters; keep GAM automatic refresh unset, as required by the SDK-owned refresh setup.

## Publisher key-values and the SDK's, side by side

The SDK preserves publisher key-values outside its reserved names, and a publisher can never remove or override the
SDK's. This holds for every original-API ad type on every platform: banners (including remote and
GAM-only ones), interstitials, remote interstitials, rewarded, native and multiformat.

Every auction's GAM request is assembled from three layers, later ones winning a name clash:

1. **The publisher's per-request key-values** — on the `AdManagerRequest` (iOS) or
   `AdManagerAdRequest.Builder` (Android) passed to the ad.
2. **Global targeting** — `addGlobalTargeting` (iOS `AUTargeting`, Android
   `AudienzzTargetingParams`, and the React Native / Flutter `Targeting` APIs, which forward to them).
3. **The SDK's keys** — `au_sdk`, `au_page_seq`, `au_slot`, `hb_refresh_count` and any reserved
   bridge keys. `removeGlobalTargeting` / `clearGlobalTargeting` cannot remove them, and a publisher
   key of the same name is replaced (or removed for interstitial `au_slot`).

The layers are applied to a **new request for every auction**. The publisher's own request object
or builder is never modified, so one can serve several ads, and a global key-value added or removed
after an ad was created reaches that ad's next refresh.

Prebid then adds its bid keys (`hb_pb`, `hb_bidder`, …). On iOS, Prebid first deletes **every**
`hb_`-prefixed key from the request, the publisher's included; the SDK puts back everything Prebid
removed except the bid keys Prebid set in that auction. On Android, Prebid only removes keys it set
itself. Either way, a publisher key survives Prebid, and a Prebid bid key wins on its own name — a
publisher key cannot fake a bid. Avoid naming your own keys after Prebid's bid keywords.

## Internal extension point

Native `AudienzzAdRequestContext` / `AUAdRequestContext` retains logical slot identity, and a
page-local ledger produces immutable page/slot/refresh snapshots. Bridges transfer an opaque
identity, never calculate the counters themselves. Ledger entries contain no view/controller
references or publisher identifiers and are cleared at the next page impression.

Bridges require the matching native changes. Local verification uses the overrides in
`LOCAL_TESTING.md`; publish natives before updating the released bridge dependency pins.

### Android GMA compatibility

GMA 25.1.0 shares the builder's targeting Bundle with built requests and exposes no complete
request-copy API. The SDK detaches that Bundle on each newly built request, using a small
reflection adapter that matches fields by type/reference instead of obfuscated names. Consumer
R8 rules retain the necessary fields. Other publisher settings are untouched. The native tests
exercise real GMA objects and require old requests to retain their original targeting.
Re-run these tests when upgrading GMA. An unsupported GMA layout logs a warning and continues
loading, but request-object isolation is then unavailable. iOS uses Google's `NSCopying` support.
