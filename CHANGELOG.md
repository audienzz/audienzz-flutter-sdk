## 0.1.9

* Honor `pauseAutoRefresh()` / `resumeAutoRefresh()` (and the all-ads variants) on iOS: a manual pause — e.g. when a same-route overlay covers the banner, which the native geometry poll can't detect — is no longer auto-resumed by the visibility poll within half a second (Android already honored these)
* Fix remote-config cold start: when the initial config fetch failed with no usable cache, the native SDK was never initialized (zero ads for the whole session even after connectivity returned) — background polling now completes initialization once config becomes available
* Fix iOS banner ads dropping all bid signals: `bannerParameters` / `videoParameters` (API frameworks, protocols, placement, playback, bitrate, duration) were assigned into an uninitialized object and silently discarded — they now reach the bid request
* Fix iOS rewarded video sending `maxduration = 1s` (a copy-paste set `maxDuration` twice); `minDuration` is now set correctly
* Fix iOS interstitial overwriting the publisher's `impOrtbConfig` with the multisize workaround — the sizes are now merged into the publisher config instead of replacing it; interstitial video requests also carry API/bitrate/duration signals
* Fix a schain-less remote config throwing during decode (`schain` is optional)
* Fix ad lookup colliding two identically-configured ads (registry now keys by object identity)
* Fix a failed native ad load leaving the ad registered forever and silently no-opping retries — the failure now surfaces through `onAdFailedToLoad`
* Fix Android `showAdWithoutView` replying twice on a failed show (raised `IllegalStateException`); failed full-screen shows are now surfaced instead of silently reported as success, with a single-use guard against a second show
* Fix disposed banners continuing to run Prebid auctions: dispose now stops auto-refresh and tears down the banner view/timers on both platforms; iOS full-screen ads no longer leak their view/handler/GAM ad
* Fix `StickyAdWrapper` crashing when used outside a scrollable
* Fix `getUserExt()` and external-ID decoding throwing on the platform map type
* Namespace the remote-config cache by publisher id + URL so switching publisher/endpoint can't serve a stale config
* Surface show/present failures for full-screen formats on both platforms instead of hanging or misreporting them; iOS `rootViewController` resolution no longer force-crashes scene-based / add-to-app hosts

## 0.1.8

* Fix iOS external user IDs (EIDs) never reaching the bid request: the values were stored under the `uniqueIds` key but the native SDK reads `uids`, so `user.ext.eids` went out with no IDs on iOS (Android was unaffected). EIDs now serialize correctly, restoring iOS demand/fill for publishers using external identity
* Fix iOS banner ads not setting a `rootViewController` on the GMA banner before load, which could cause failed loads and unrecorded impressions/clicks
* Fix iOS `isLazyLoad` defaulting to `true` when the argument was absent (now `false`, matching the Dart default) — an accidental lazy load never fetches inside a Flutter platform view on iOS
* Fix invalid schain JSON generated during remote initialization: `asi`/`sid` string values were interpolated unquoted, producing malformed JSON

## 0.1.7

* Add `pauseAllAutoRefresh()` / `resumeAllAutoRefresh()` to pause and resume auto-refresh across all loaded banner ads (e.g. when showing a full-screen overlay the SDK can't see)
* Auto-detect same-route overlay occlusion via hit-test: a smart-refresh banner covered by an `OverlayEntry`/dialog on the same route now pauses its auto-refresh without any publisher code
* Document consent/init order in the README — obtain user consent before initializing the SDK and loading ads

## 0.1.6

* Handle smart-refresh banner visibility entirely inside the SDK (scroll geometry, route changes, and app lifecycle) — no publisher-side visibility handling required
* Bump iOS native dependency to AudienzziOSSDK 0.2.6 (Google Mobile Ads SDK 13)
* Guard against `isLazyLoad: true` without `smartRefresh: true` on Flutter (off-screen ads would never load); lazy load is disabled with a log message for that combination

## 0.1.5

* Mute GMA ads by default: bump native dependencies to AudienzziOSSDK 0.2.5 and com.audienzz:sdk 0.1.5, which set the GMA mute flag when the backend-driven app volume is 0

## 0.1.0

* Add lazy loading support for banner ads (defers demand fetch until ad enters the viewport)
* Add smart refresh support for banner ads (pauses auto-refresh when ad is off-screen, resumes with stale-aware timing when it returns)
* Add prefetch distance support: configurable margin (default 200 dp/pt) that triggers demand fetch before the ad enters the viewport
* Bump iOS native dependency to AudienzziOSSDK 0.2.1
* Fix infinite loading when lazy load is enabled (AdWidget now always rendered in the widget tree)

## 0.0.10

* Fix crash on network error during initialization
* Implement fallback polling for initialization

## 0.0.9

* Implement sticky ads header
* Bump native dependencies: iOS SDK 0.1.7, Android SDK 0.0.13
* Fix static/dynamic hybrid linking issue
* Update README with sticky ads documentation

## 0.0.8

* Added remote configuration feature
* Updated Readme with new documentation

## 0.0.7

* Added default values for API
* Added automatic PPID feature
* Update Audienzz native dependencies to latest version

## 0.0.6
* Add method to set Schain object
* Update Audienzz native dependencies to latest version

## 0.0.5

* Update Audienzz native dependencies to latest version
* Add support for targeting configuration

## 0.0.4

* Hotfix for multisize feature on iOS platform

## 0.0.3 

* Update Audienzz native dependencies to latest version
* Add support for imp level ORTB config
* Add support for multiple ad sizes configuration

## 0.0.2

* Update Audienzz native dependencies to latest version
* Remove deprecated parameters 'appContent', 'keyword' and 'keywords'

## 0.0.1

* Initial release of the sdk wrapper. Supports Banner, Interstitial and Rewarded ad formats.
