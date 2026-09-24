# Banner delivery policy — proposal

Changes to **when** a banner spends a request.

Sections 2 and 3 remain **proposals**: nothing in them is implemented, and the correctness fixes
that ship alongside this document deliberately do not touch refresh timing. Section 1 has been
partly superseded by shipped work and is marked accordingly.

Each proposal is written so it can be rejected on its own. All of them need the show-rate metric
definition settled first — without the numerator and denominator we cannot tell whether any of them
helped.

---

## 0. What is already implemented

This section exists so the proposals below are not read as describing current behaviour.

| Shipped | Where |
|---|---|
| `lazyLoad` and prefetch margin are publisher-settable per placement, resolving **publisher override → ad config → SDK default** | all four SDKs |
| Native RemoteBanner default is **lazy** (`true`); eager remains an explicit per-placement choice | iOS, Android; React Native inherits it |
| Flutter RemoteBanner default is **eager** (`false`), deliberately — see below | Flutter |
| Flutter reports definitive hidden states (two-dimensional intersection, collapsed slots, `Offstage`, clipping ancestors) and re-synchronizes a remounted retained ad | Flutter `AdWidget` |
| The smart-refresh v2 directional gate actually applies on Flutter, resolved once for Dart, the bridges and the natives | Flutter |
| `discardedWithoutImpression` reports **interstitial** inventory released before it recorded an impression | all four SDKs |

Two things that are **not** implemented and are easy to assume otherwise:

- **Banners have no discard event.** `discardedWithoutImpression` covers interstitials only. A
  banner that loads and is never seen is still silent.
- **There is no deployed four-platform delivery ledger.** The iOS banner delivery trace
  (`AUAdTrace`) routes through `AULogEvent`, which is DEBUG-only; it is a debugging aid, not
  production telemetry. Section 3's measurement plan depends on building one.

Neither the shipped work nor anything proposed here replaces Ad Manager reporting. Responses served
and AdX render rate are measured server-side across demand sources the SDK cannot see. SDK-side
counters say *which* placements and *which* reasons dominate; Ad Manager says how much.

---

## 1. Flutter RemoteBanner: near-viewport loading

> **Partly superseded.** `RemoteBannerAd` now accepts `isLazyLoad` and `prefetchMargin`, so the
> native deferral is reachable from Flutter. What remains proposed is the *Dart-driven* deferral
> below, which is a different mechanism and solves a different problem.

### What is wrong today

`RemoteBannerAd` now accepts `isLazyLoad`, defaulting to `false`, and the natives default their own
RemoteBanner to lazy through the resolution chain — no platform hardcodes it any more.

Flutter stays eager deliberately. Its lazy path needs the platform view to exist and be sized
before a viewport verdict can be produced, so an integration that mounts `AdWidget` only after
`onAdLoaded` — common, since the size is not known before then — would deadlock. That makes
`isLazyLoad: true` unsafe to enable remotely for a client whose integration has not been checked,
which is precisely the gap the Dart-driven proposal closes.

### Why not simply flip the flag

- **It changes what `load()` means.** Today `load()` requests immediately and `onAdLoaded` follows.
  Apps that gate mounting `AdWidget` on `onAdLoaded` would deadlock: the widget never mounts, so
  the ad never comes near the viewport, so it never loads, so the callback never fires. The Flutter
  Android bridge already carries a comment about customers doing exactly this.
- **Native lazy loading is unproven on this path.** On Android the prefetch listener registers on an
  `AdManagerAdView` that has **no parent** — the platform view attaches later. `isWithinPrefetchMargin`
  returns false and the listener goes onto a floating `ViewTreeObserver`. Whether it fires after
  attach has not been demonstrated, and if it does not, we would trade eager loading for slots that
  never load at all.

### Proposal

Add an opt-in `RemoteBannerAd(nearViewportLoading: false)`. Default `false` keeps today's behaviour
exactly; nothing changes for anyone who does not ask for it.

This is **not** the shipped `isLazyLoad` argument. `isLazyLoad` defers the *native* request and
therefore inherits the mount precondition above; `nearViewportLoading` defers the request in Dart,
where the widget's own lifecycle is observable, and so is safe for integrations that mount late.

When `true`, `load()` records the intent and returns without requesting. The request is issued when
the **Dart** visibility poll first reports the ad within `prefetchMargin` of the viewport. Driving
it from Dart rather than from native lazy loading sidesteps the unparented-`ViewTreeObserver`
question entirely, and the poll demonstrably already works after platform-view attach — it is what
drives pause and resume today.

**Proof obligation before this ships**, as widget tests:

1. `load()` called, `AdWidget` mounted afterwards → exactly one request once it comes within margin.
2. `load()` called, widget never mounted → no request.
3. `load()` called, widget mounted far below the fold, scrolled into range → exactly one request.

**Migration — the default never flips.** An earlier draft proposed flipping it after a successful
experiment. That is wrong: `load()` meaning "request now" is the contract every existing
integration was written against, and no experiment result makes it safe to change that contract
underneath them. A good measurement would only tell us the new behaviour is better for publishers
who adopt it, not that silently imposing it is harmless.

So: `nearViewportLoading` stays opt-in permanently on `RemoteBannerAd`. If near-viewport loading
should eventually be the norm, it arrives as a **new type** with its own contract — the old one
keeps working unchanged and is deprecated on a normal deprecation cycle, not switched.

---

## 2. Do not replace a creative that was never seen

### What is wrong today

The refresh interval is measured from load completion and keeps counting while the ad is hidden. A
creative prefetched at T0 and first reached at T0+35s is already overdue when the user arrives, so
it is replaced immediately — having never rendered. That slot spent two requests to produce one
impression.

### Proposal

One new state on the refresh controller: `awaitingFirstImpression`.

- Set when a Google load completes.
- Cleared when the Google impression callback arrives.
- While set, `scheduleNext()` does not schedule. The creative keeps the slot.
- Once cleared, the configured interval starts **from the impression**, not from the load.

**This is not viewable-time accounting, and the distinction matters.** Waiting for the first
impression waits for a single discrete event that the ad server already reports. It needs no timer
tick, no visibility integration, no per-frame accumulation and no new threshold. Accumulating
visible time — "refresh only after N seconds of ≥50% visibility" — is a different, much larger
change that was deliberately excluded from the refresh migration and stays excluded here.

### Risk

If GMA does not record an impression for a banner that loaded off-screen, this becomes "wait until
seen". That is the intended outcome, but it materially lengthens the cadence for users who scroll
little, and it must be measured behind a per-publisher flag before being trusted.

---

## 3. Bounded recovery when the impression never arrives

`awaitingFirstImpression` must not be able to strand a slot. An impression callback can be missed —
a custom ad-server view the SDK cannot observe, a delegate the publisher replaced, a view destroyed
mid-flight.

### The trap to avoid

A plain wall-clock deadline defeats the policy it is supposed to protect. The commonest reason an
impression never arrives is that **the ad has not been seen yet** — exactly the case section 2
exists to preserve. A timeout that fires while the ad is off screen replaces the unseen creative
anyway, and the whole change reduces to a slower version of today.

### Proposal

A deadline that only runs while the ad could actually be impressed:

- Armed when `awaitingFirstImpression` is set **and** the ad is refresh-eligible; paused whenever it
  stops being eligible, resumed when it becomes eligible again. An ad sitting off screen therefore
  never times out — it simply waits, which is the intent.
- Duration: the configured interval, floored at 30s, measured in eligible time only. One deadline,
  not a retry ladder.
- On expiry: clear the state, resume the **configured cadence** — never the fast transport-failure
  retry path — and emit `google.impression.timeout` on the delivery record (which has to be built
  first; see below).

This is the one place the design touches accumulated time, and deliberately so: it is a bound on a
failure mode, not a delivery rule. It does not gate refresh on viewable seconds, and section 2's
waiting condition remains a single discrete event.

Android already has this shape for the Google load timeout: 120s on `refreshHandler`, resuming the
normal cadence rather than the retry loop, with the stale-generation case routed to pending page
work instead. Reuse that structure rather than inventing a second one.

### Ownership and cancellation

The state is per **delivery**, not per slot, and must be bound to the generation that produced it.
A refresh controller already stamps each request; `awaitingFirstImpression` is set under that stamp
and is ignored when a callback arrives carrying an older one. Without this, a late impression from
a retired creative clears the state of its successor.

- **Successful load vs no-fill.** The state is armed only when Google delivers a creative. A no-fill
  or a load error arms nothing: there is no creative to protect, and the normal retry or cadence
  applies unchanged. Arming on "load completed" rather than "creative received" would stall a slot
  that never had anything to show.
- **Page change.** A genuine page impression retires the delivery. The state is cleared with it —
  it must not survive into the recreated ad, which will produce its own first impression.
- **Background.** Going to background does not clear the state and does not count toward the bound
  below; returning to the foreground resumes exactly where it paused. An app in the background
  cannot impress an ad, so treating that time as elapsed would defeat the policy.
- **Destruction.** Destroying the view clears the state and cancels the bound, like every other
  scheduled work item.

### What to measure before trusting it

This needs telemetry that **does not exist yet**. The iOS banner delivery trace is DEBUG-only
logging, not a deployed ledger, and there is no banner equivalent of the interstitial discard
event. Building a sampled, production-capable delivery record — request reason, load result,
impression, retirement reason, geometry and host holds, elapsed time, per-delivery id, and no
targeting, PPID or creative content — is a prerequisite for this section, not a by-product of it.

The number that decides whether this policy is safe to enable by default is the ratio of first
impressions to eligible-time timeouts. Collect it first, per publisher, behind a flag.

An SDK-side ratio is also not a render rate. It cannot be compared with Ad Manager's AdX render
rate directly, and a ratio that improves only because fewer ads were requested does not demonstrate
more revenue. Evaluate impressions and revenue per session alongside it.
