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
The analytics schema is unchanged. Rendering-API requests are outside this change. GAM-managed automatic refresh is not an SDK-owned request and does not advance
these counters; keep GAM automatic refresh unset, as required by the SDK-owned refresh setup.

## Banner refresh limit

Each logical banner slot can start **one initial request plus ten refreshes per page impression**
(`au_refresh=0` through `10`). This applies to Original-API banners and RemoteBanners on all four
platforms, automatically. No new publisher parameter is needed.

- Every admitted attempt uses the allowance, including manual reloads, transport retries, failed
  requests and requests cancelled by a lifecycle transition. Blocked/coalesced attempts do not.
- The last allowed request may finish normally. Afterwards the SDK keeps the current creative
  and cancels further periodic/retry work; it does not keep waking up to check the limit.
- Visibility changes, publisher pause/resume, repeated `load`/`reload`, and native replacements
  sharing the logical slot cannot reset the allowance. Changing delivery settings at the limit
  does not replace an existing banner. A publisher explicitly removing/destroying the displayed
  view can still remove the creative; the cap does not retain views after disposal.
- A real native `pageImpression` resets the allowance, including an automatic foreground report.
  Returning without a new report does not. A reset clears only the quota hold, preserving other
  holds such as publisher pause and host-reported concealment.
- Before the first page report, the same limit applies to page sequence `0`. Interstitials use
  explicit display opportunities and are not subject to this banner refresh cap.

This is a request ceiling, not idle detection: an active reader on the same page also reaches it.
At a 30-second refresh interval that is roughly five minutes plus load time. Keep page reports tied
to real page/foreground transitions; periodically reporting a page would repeatedly reset the cap.
A wholly new logical owner is a new slot, as described above; do not recreate ad owners on every
layout/build. GAM-managed automatic refresh must remain disabled: this cap controls SDK requests,
not refreshes initiated independently by Google.

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
