# Banner delivery policy — proposal

Three changes to **when** a banner spends a request. None are implemented; the correctness fixes
that ship alongside this document deliberately do not touch delivery timing.

Each is written so it can be rejected on its own. All three need the show-rate metric definition
settled first — without the numerator and denominator we cannot tell whether any of them helped.

---

## 1. Flutter RemoteBanner: near-viewport loading

### What is wrong today

`RemoteBannerAd` passes `prefetchMargin` to native but never sets `isLazyLoad`, and `BannerAd`
defaults it to `false`. The configured prefetch distance is therefore transmitted and ignored: the
request is issued the moment `load()` is called, before the widget exists. Both natives hardcode
`isLazyLoad = true` for their own RemoteBanner, so Flutter is the odd one out.

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

When `true`, `load()` records the intent and returns without requesting. The request is issued when
the **Dart** visibility poll first reports the ad within `prefetchMargin` of the viewport. Driving
it from Dart rather than from native lazy loading sidesteps the unparented-`ViewTreeObserver`
question entirely, and the poll demonstrably already works after platform-view attach — it is what
drives pause and resume today.

**Proof obligation before this ships**, as widget tests:

1. `load()` called, `AdWidget` mounted afterwards → exactly one request once it comes within margin.
2. `load()` called, widget never mounted → no request.
3. `load()` called, widget mounted far below the fold, scrolled into range → exactly one request.

**Migration.** Ship default-off for one minor release with the behaviour documented. Flip the
default only after a per-publisher comparison using the existing backend `prefetchDistanceDp`, and
only if the measured show rate moves.

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

### Proposal

A single deadline, armed when `awaitingFirstImpression` is set:

- Duration: the configured interval, floored at 30s. One deadline, not a retry ladder.
- On expiry: clear the state, resume the **configured cadence** — never the fast transport-failure
  retry path — and emit `google.impression.timeout` on the trace.

Android already has this shape for the Google load timeout: 120s on `refreshHandler`, resuming the
normal cadence rather than the retry loop, with the stale-generation case routed to pending page
work instead. Reuse that structure rather than inventing a second one.

### What to measure before trusting it

The trace added alongside these fixes emits `google.requested`, `google.loaded`,
`google.impression` and `retired` with a placement and load id. The ratio of impressions to
timeouts is the number that decides whether this policy is safe to enable by default. Collect it
first.
