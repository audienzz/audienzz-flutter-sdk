# Automatic ad-request targeting

Original-API banners (including RemoteBanners) and interstitials send these reserved GAM
custom-targeting keys automatically on Android, iOS, Flutter and React Native. No publisher
counter or new integration parameter is required.

| Key | Meaning | First value |
| --- | --- | --- |
| `au_page_seq` | Session sequence of the native `pageImpression` report | `1` |
| `au_slot` | Automatically assigned logical placement number within the page impression | `1` |
| `au_refresh` | Additional admitted requests for this slot in this page impression | `0` |

Values are decimal strings. For example, on the first page, the second slot's first request
contains `au_page_seq=1`, `au_slot=2`, `au_refresh=0`. Its next request has `au_refresh=1`.
Refreshing that slot does not change the first slot's counter. Another `pageImpression` produces
`au_page_seq=2` and each slot starts at `au_refresh=0` again.

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
  ads. A retained Flutter interstitial keeps its context across successive prefetches. A wholly
  new logical owner is a new slot.
- Interstitial placements use the same numbering space; their number identifies their registered
  display opportunity, not a vertical coordinate.

## Request boundaries

Counters advance only when a request passes the SDK's gates and begins an auction. Coalesced
prefetches, readiness checks, visibility updates and rejected/blocked load attempts do not advance
it. An admitted retry or manual reload does advance it, even if that request fails or is later
cancelled. `au_refresh` is therefore a request counter, not an impression counter.

Each request carries its own snapshot through Prebid and into Google. A subsequent page report
or refresh cannot relabel an outstanding request. Existing publisher targeting is preserved;
the SDK overwrites these three reserved keys. They are request-local, not global targeting.

These fields are independent of clickstream `slot_reload`, which remains a binary `0`/`1`.
No analytics schema or refresh scheduling behavior changes. Rendering-API requests are outside
this change. GAM-managed automatic refresh is not an SDK-owned request and does not advance
these counters; keep GAM automatic refresh unset, as required by the SDK-owned refresh setup.

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
