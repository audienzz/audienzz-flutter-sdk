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
  retry path — and emit `google.impression.timeout` on the trace.

This is the one place the design touches accumulated time, and deliberately so: it is a bound on a
failure mode, not a delivery rule. It does not gate refresh on viewable seconds, and section 2's
waiting condition remains a single discrete event.

Android already has this shape for the Google load timeout: 120s on `refreshHandler`, resuming the
normal cadence rather than the retry loop, with the stale-generation case routed to pending page
work instead. Reuse that structure rather than inventing a second one.

### What to measure before trusting it

The trace added alongside these fixes emits `google.requested`, `google.loaded`,
`google.impression` and `retired` with a placement and load id. The ratio of impressions to
timeouts is the number that decides whether this policy is safe to enable by default. Collect it
first.
