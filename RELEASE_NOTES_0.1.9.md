# Audienzz Flutter SDK 0.1.9

This release lands the fixes from the Flutter SDK audit together with the matching native fixes (**AudienzziOSSDK 0.2.7**, **com.audienzz:sdk 0.1.7**). It closes several silent revenue and reliability gaps — disposed ads that kept auctioning, config failures that left a whole session ad-less, and iOS bid requests that dropped their signals — plus a couple of crashes.

> **Upgrade note:** 0.1.9 requires the native SDKs to be resolvable at **AudienzziOSSDK 0.2.7** and **com.audienzz:sdk 0.1.7**. No public Dart API changed; existing integrations upgrade with no code changes.

## ✨ New

- **Manual banner pause/resume is now honored on iOS.** `pauseAutoRefresh()` / `resumeAutoRefresh()` (and the all-ads variants) previously no-opped on iOS — the visibility poll would auto-resume within half a second. They now suppress the poll while paused, so a same-route overlay (dialog / `OverlayEntry`) that the native geometry check can't see correctly pauses refresh. Android already honored these.

## 🐛 Fixes

### Revenue & bidding
- **iOS banners were dropping every bid signal.** `bannerParameters` / `videoParameters` (API frameworks, protocols, placement, playback, bitrate, duration) were assigned into an uninitialized object and silently discarded. They now reach the bid request.
- **iOS rewarded video was sending `maxduration = 1s`** (a copy-paste assigned `maxDuration` twice); `minDuration` is now set correctly, so SSPs stop no-bidding the slot.
- **iOS interstitial no longer overwrites your `impOrtbConfig`.** The multisize workaround used to replace the publisher config (dropping deals / floors / first-party data); the sizes are now merged into it. Interstitial video requests also carry API / bitrate / duration signals.
- **Schain-less remote config no longer throws** during decode (`schain` is optional).

### Reliability & lifecycle
- **Remote-config cold start no longer strands a session with zero ads.** When the first config fetch failed with no usable cache, the native SDK was never initialized — even after connectivity returned. Background polling now completes initialization once config becomes available.
- **Disposed banners stop auctioning.** Dispose now stops auto-refresh and tears down the banner view/timers on both platforms; iOS full-screen ads no longer leak their view, handler, and GAM ad on every load.
- **A failed native ad load no longer registers the ad forever.** Previously the entry stuck around and retries silently no-opped; the failure now surfaces through `onAdFailedToLoad`.
- **Ad lookups no longer collide two identically-configured ads** — the registry keys by object identity.

### Error handling & robustness
- **Full-screen show/present failures are surfaced** on both platforms instead of hanging or being misreported as load failures; single-use ads are guarded against a silent second show.
- **Android `showAdWithoutView` no longer crashes** with `IllegalStateException` (it replied twice on a failed show).
- **iOS `rootViewController` resolution no longer force-crashes** scene-based / add-to-app hosts.
- **`AudienzzStickyAdWrapper` no longer crashes** when used outside a scrollable.
- **`getUserExt()` and external-ID decoding no longer throw** on the platform map type.
- Unloaded `show()` / `getPlatformAdSize()` now throw a real `StateError` (instead of a release-stripped assert), and a missing reward is logged rather than thrown inside the channel handler.
- The remote-config cache is namespaced by publisher id + URL, so switching publisher/endpoint can't serve a stale config.

## ⬆️ Dependencies

- **iOS:** `AudienzziOSSDK ~> 0.2.7` (Google Mobile Ads SDK 13, min iOS 15)
- **Android:** `com.audienzz:sdk 0.1.7`

Both native releases carry the corresponding native audit fixes.
