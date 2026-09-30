# Running this example against the LOCAL native SDKs

On `feature/page-impression-api`, the example uses local native SDKs:
`../audienzz-android-sdk` and `../audienzz-ios-sdk` (relative to this repository).
Publish Android locally as described below; iOS links directly to source. Use current native
`main` branches, which include analytics batching, foreground/interstitial
page continuity, and cold-start attribution fixes. The library package pins remain Android
`0.3.1` / iOS `~> 0.4.1`; those published versions predate these changes. Publish new natives
and update the package pins before releasing this wrapper.

Flutter forwards backend `analyticsBatchSize` to the native sender: missing/invalid values
use 10, and positive integers are capped at 15. Native owns persistence, batching and retries.

## Android — local Maven build

The example's `gradle.properties` selects `audienzzNativeVersion=0.3.1-local`.
Publish current native sources before the first build, and again after native edits:

```bash
cd ../audienzz-android-sdk
./gradlew :Audienzz:publishToMavenLocal \
  -I ../audienzz-flutter-sdk/example/android/publish-local-native.gradle
cd ../audienzz-flutter-sdk/example/android
./gradlew :app:dependencyInsight --dependency com.audienzz:sdk \
  --configuration debugRuntimeClasspath --refresh-dependencies
```

The init script changes only the local publication coordinate and disables signing for that
local build. It does not edit the native release version or publish anything remotely. Resolution
must show `com.audienzz:sdk:0.3.1-local`. Keep the property set while testing so a plain app rebuild
continues using the local artifact. Republish and use `--refresh-dependencies` after native edits;
hot reload does not replace native code. A missing local artifact fails dependency resolution.

Direct Gradle source substitution is not used: native and wrapper builds use different Android
Gradle plugin versions. To verify a future published release, remove `audienzzNativeVersion`
and update the library's released dependency pin first.

## iOS — local development pod

The example Podfile defaults to `../../../audienzz-ios-sdk`:

```bash
cd example/ios
pod install
```

It prints `[Audienzz] using LOCAL iOS SDK`. CocoaPods compiles sources from that checkout.
Rebuild after native edits; rerun `pod install` after adding/removing native source files.
`AUDIENZZ_IOS_SDK_PATH=/another/checkout pod install` selects a different checkout.
An empty override (`AUDIENZZ_IOS_SDK_PATH='' pod install`) selects the released dependency.
Keep the same override on subsequent CocoaPods/Flutter invocations when testing a released SDK.

## Run

```bash
cd ~/Documents/audienzz-flutter-sdk/example
flutter run --debug
```

## Charles SSL Proxying on Android

Use the example's **debug build**. Native Prebid/Google requests and Dart remote-config requests
use different networking stacks, so configure both:

1. Set the phone's Wi-Fi HTTP proxy to the Charles computer's address and port (usually 8888).
   Allow the phone in Charles. Install that Charles instance's root certificate on Android as a
   **CA certificate**, following **Help → SSL Proxying → Install Charles Root Certificate on a
   Mobile Device or Remote Browser**. The example's debug network configuration trusts these
   user-installed CAs; release/profile builds and the SDK library do not get that override.
2. Enable SSL Proxying in Charles for the remote-config, Prebid and Google hosts you need to
   inspect. Keep the original HTTPS SDK endpoints; a reverse-proxy endpoint is not required.
3. For Dart's remote-config traffic too, export the **public root certificate in PEM format**
   using **Help → SSL Proxying → Save Charles Root Certificate** and launch with:

   ```bash
   cd ~/Documents/audienzz-flutter-sdk/example
   flutter run --debug \
     --dart-define=CHARLES_PROXY=192.168.1.10:8888 \
     --dart-define="CHARLES_CA_BASE64=$(base64 < /path/to/charles.pem | tr -d '\n')"
   ```

   Replace the address and certificate path with yours. Without these flags, Dart remote-config
   requests connect directly and will not appear in Charles, even when native ad requests do.
   The example logs `Charles proxy enabled for Dart HTTP` when configured. It trusts the provided
   CA alongside system roots; it still rejects invalid certificate chains and hostnames. An
   unreachable proxy fails visibly instead of falling back to a direct connection.
4. Fully rebuild/restart after changing certificates, proxy flags or the Android manifest.
   Hot reload does not apply this setup. Relaunch without the flags to disable the Dart override.

The Dart override is gated by `kDebugMode` and lives only in the example. Your Charles certificate,
private key and proxy address are not committed. For a publisher's own debug app, apply these settings
in that app; the SDK does not change the publisher's certificate trust.

The proxy regression tests run with `flutter test test/example_charles_proxy_test.dart` from the
repo root. They use host OpenSSL to create a temporary certificate and verify real HTTP/HTTPS
proxy connections, including rejection of a wrong hostname.

References: [Charles certificate setup](https://www.charlesproxy.com/documentation/using-charles/ssl-certificates/),
[Android debug CA configuration](https://developer.android.com/privacy-and-security/security-config#Debug),
[Dart proxy selection](https://api.dart.dev/dart-io/HttpClient/findProxy.html).

## Collecting a log

Diagnostics are **on** in this example. Every decision the SDK makes about a slot is one
`AUDZ …` line, and every action you take in the app is an `AUDZ app …` line, so a captured log
reads back as a sequence without you having to narrate it.

On iOS, use the **Flutter terminal / IDE console** and filter for `AUDZ`. Native
SDK diagnostics are forwarded through Dart while diagnostics are enabled, so
`page recovered`, `slot blank`, `auction start/end`, and `slot reveal` appear
alongside the Dart `page adsUpdated` and viewport lines. This forwarding only logs
decisions; it does not send analytics events or trigger page impressions. Rebuild
the iOS app after updating the plugin's Swift code; hot reload is not sufficient.

```bash
adb logcat -c && adb logcat -s AUDZ ReactNative ReactNativeJS flutter > audz.log     # Android
xcrun simctl spawn booted log stream --style compact \
  --predicate 'eventMessage CONTAINS "AUDZ"' > audz.log                              # iOS simulator
```

The line vocabulary is in
`../Audienzz Full Branch Audit 2026-09-20/Capturing Diagnostics.md`.

## Screens to test

Everything the reviews asked about is reachable in at most two taps from the home list.

| Flow | Where |
| --- | --- |
| RemoteBanner in a scrolling page; scroll off and back | **Managed test flows → Article** (two in-content slots; the second is a real scroll away) |
| Background / foreground with a banner on screen | any article — background the app past the refresh interval, then return |
| Page A → ad-free B → A | **Managed test flows → Ad-free destination**, then back |
| Two routes with the same screen name | **Managed test flows → Article 1** and **Article 2** — both are called `article` and must own their banners separately |
| Delayed content | **Managed test flows → Article after 3s** — leave the route before it lands; it must not reclaim the foreground |
| Retained tabs | **Managed test flows → Retained tabs** (both built, only the selected one owns an ad) |
| Host-reported cover | **Article → Report cover** — a painted veil no geometry check can see |
| Durable publisher pause | **Article → Pause refresh** — a scroll or page change must not undo it |
| Interstitial prefetch → show | **Remote config screen → Prefetch**, then **Show at this opportunity** |
| Interstitial prefetchAndShow | same screen → **Show when it arrives** |
| Repeated taps / ineligible opportunity | same screen — every button stays enabled on purpose |
| Disposal during loading | tap **Prefetch** then immediately leave the screen |
| Test screen from an inline button | **Open test screen** below a home banner — normal text, app bar and back button; one PI before its banner request |
| Interstitial return (Android and iOS) | Show an interstitial over a loaded banner, wait past the refresh interval, dismiss — no refresh under the ad, no new analytics PI, then blank/reload on the active page |

For the interstitial flow, also repeat with a publisher-paused banner, a failed presentation,
and a background/foreground round trip while the ad is open. A manual pause must survive dismissal;
a failed show must not report a page return; native foreground recovery must not be followed by a
duplicate replacement. Off-screen banners remain deferred until eligible. These checks require a
device/live test ad to validate actual Google presentation and painting.

### Interstitial status bar and close button

Both original and remote Flutter interstitials use Google's native fullscreen presentation.
Android now calls Google's `setImmersiveMode(true)` before each `show()`. This requests immersive
system UI in Google's ad activity; it does not mutate the Flutter activity or need a restore timer.
Google documents immersive sticky/navigation-bar behavior, not a guarantee that every creative's
close button respects every device's status bar or camera cutout.

On iOS, leave `UIViewControllerBasedStatusBarAppearance` enabled. The example explicitly sets it
to `true`; Google owns status-bar visibility during the ad. A custom native container must allow
its presented controller to control the status bar, as described in Google's
[iOS migration guidance](https://developers.google.com/ad-manager/mobile-ads-sdk/ios/migration#stricter_enforcement_of_status_bar_controls).
Do not set a global hidden status bar or add a fixed top inset to the Google ad's views.

Test **prefetch → show → dismiss** at least twice, and **prefetchAndShow**, in portrait and
landscape. Verify the close button is tappable, rotation/cutouts do not cover it, and the app's
original system bars return after dismissal, failure, and background/foreground. Include Android
15+ and an iPhone with a notch. A passing bridge test only verifies that the presentation option
is applied; real Google creatives and device system UI still need visual checks. If overlap
persists, capture the device/OS, screenshot and Google response ID for a renderer/creative report.

Flutter's `SafeArea` and padding on `MainActivity` do not control Google's separate ad screen.
There is no supported cross-platform Google setting to force an interstitial into a rectangle
below a permanently visible status bar. The Android API is documented
[here](https://developers.google.com/ad-manager/mobile-ads-sdk/android/reference/com/google/android/gms/ads/interstitial/InterstitialAd#setImmersiveMode(boolean)).

Verified September 28, 2026: a Google test interstitial presented from the Flutter example on
the iOS 26.2 iPhone 17 Pro simulator changed status-bar visibility from visible, to hidden during
the ad, to visible after dismissal. That probe used the same `present(from: nil)` entry point as
the plugin. Android bridge tests verify immersive mode precedes presentation for each new ad,
single-use enforcement remains intact, and a missing activity does not consume ready inventory.
No Android device was connected for a visual check of the affected creative.

### Android interstitial return regression

Native `0.3.0` can latch `APP_BACKGROUND` after a translucent Google `AdActivity` closes: SDK
initialization missed the host's first start, and returning only resumes it. Android `0.3.1`,
selected by default, also records resumed/paused activities as started and fixes this case.
Dismissal recovery cannot override an incorrect native background verdict. Rebuild and reinstall
the app against local native main for the updated return behavior.

Verify this exact sequence on a clean launch:

1. Let a home banner load, then show and dismiss an interstitial.
2. Confirm no new analytics PI and one fresh load for the visible banner.
3. Open the Test Screen from below a banner; its banner must load.
4. Go back; the home banner must blank and then load its replacement.
5. Background for over 30 seconds, then return; no auctions while backgrounded, one recovery without a new analytics PI.

The Flutter bridge unit suite is `./gradlew :audienzz_sdk_flutter:testDebugUnitTest` from
`example/android`. Native regression tests cover both the foreground monitor and actual banner
handler handoffs. The required native fix is included in the published Android `0.3.1` pin.

Historical verification before the continuity change, on 2026-09-24 (vivo 2004, Android 12; local native `0.3.1-flutter-review`):
interstitial open for 42 seconds with no banner auctions; dismissal produced one PI and blanked
both home slots. Each slot loaded its deferred replacement when scrolled into view. The inline
Test Screen banner loaded and rendered; returning home blanked and rendered a new banner.
Another 43 seconds in the actual background produced no auctions; returning produced one PI and
one successful replacement for the visible slot.
Native unit tests: 251 passed. Flutter Android bridge tests: 23 passed. Removing the foreground
fix fails five regressions, and removing the bridge's return report/cover fails six regression tests.

Native bridge regressions run in the example's `RunnerTests` target, against the matching local native checkout:


```bash
cd example/ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -parallel-testing-enabled NO -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO test
```

### What a good run looks like

Leaving an article for the ad-free screen:

```
AUDZ app navigate to=settings
AUDZ page impression id=settings name=settings
AUDZ slot release config=118 reason=otherPage page=settings
```

...and coming back:

```
AUDZ app navigate to=article-1
AUDZ page impression id=article-1 name=article
AUDZ slot recreate config=118 page=article
AUDZ auction start slot=… reason=pageImpression gen=2
AUDZ auction end slot=… result=filled
```

If a slot stays empty, look first at `slot hold reason=…`, then at whether `slot create`'s `page`
matches the `page impression` before it, then at `refresh block … held=`.

## A note on `Podfile.lock`

`example/ios/Podfile.lock` is generated locally and ignored by Git.
Keep it in sync with `Pods/Manifest.lock` by running `pod install` after changing sources.
Restoring only one lockfile causes Xcode's "sandbox is not in sync" build failure.

## Before releasing

1. Publish the native changes and update both library dependency pins.
2. Remove the example's `audienzzNativeVersion` property and restore the Podfile's released default.
3. Run `pod install`, rebuild both platforms against the published dependencies, and rerun the
   bridge suites. No local native source override should remain active in release verification.

## Published native fixes and analytics checks

Published Android `0.3.1` and iOS `0.4.1` include immediate analytics delivery
with persistent retries, page-impression attribution, adaptive banner fixes, and banner-only
slot numbering. iOS includes the HTTP-204 analytics fix and late adaptive-size notifications;
Android includes Prebid-outage fallback and foreground recovery after translucent interstitials.
This testing branch uses local native main for the newer changes. Rebuild and reinstall;
hot reload does not replace the native SDKs.

For analytics checks, configure the device network proxy, enable SSL proxying for
`api.adnz.co:443`, and filter Charles for `/api/ws-clickstream-collector/submit/batch`.
The local native SDKs persist events and batch by auction after 2 seconds without new events.
The backend batch cap defaults to 10 and cannot exceed 15, with one request in flight.
With diagnostics enabled, they log
`AUDZ analytics queued/sending/sent/failed/retryScheduled/dropped` without event payloads.
`sent` confirms HTTP success, not dashboard ingestion.

Native analytics uses the device network proxy, not Flutter's Dart-only proxy override.

For device verification, repeat `Prefetch → Show → dismiss` three times, repeat Prefetch while
already ready, and block the Prebid endpoint. Check adaptive banners both on first load and
refresh, with custom width and inline/anchored backend configurations. Check the app's back
button below the status bar separately from Google's interstitial close button: those belong
to different windows, and an inset fix in the app does not establish Google's close-button safety.

## ATT in the iOS example

The example requests ATT only when the app is active and status is `notDetermined`, before
initializing ads. RN does this in `example/ios/AppDeletage.swift`; Flutter does it in
`example/lib/main.dart`. Denied/restricted status still allows initialization and leaves IDFA
unavailable. Existing decisions are not prompted again. The SDK itself never prompts a
publisher's users; the host app owns its ATT/CMP flow and usage-description text.

Test a fresh install with Allow and Deny separately, plus relaunch and background/foreground.
A zero IDFA after Deny is expected; do not use it as proof that ad loading failed.

## Same-page interstitial return (unreleased)

Use current native `main` in both sibling checkouts and this wrapper branch. Published Android
0.3.1 / iOS 0.4.1 do not contain this policy yet; update pins after publication before releasing
these bridge changes.

- Show/dismiss three successive prefetched interstitials: one banner replacement per return,
  optional blanking until Google responds, no extra analytics `pageImpression`.
- Compare `page_impression_id`, `au_page_seq`, `au_slot`: unchanged; banner refresh count advances.
- Navigate during the ad, dismiss while backgrounded, and background/foreground before dismissal:
  no old-page revival or duplicate reload; no requests while covered/backgrounded.
- Keep a banner manually paused or off-screen: dismissal must not bypass either hold.
- Prefetch on A, show on B: interstitial events keep A; banner recovery belongs to B.

The existing bridge page callback is a view lifecycle notification, not evidence that an analytics
page event was sent. Inspect the collector payload separately.
